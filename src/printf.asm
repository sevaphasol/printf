; ----------------------------------------------------------------------------------------
; Implementation of libC printf analog. Runs on Linux.
; Supported specifiers: %%, %c, %s, %d, %x, %o, %b.
; ----------------------------------------------------------------------------------------

section .data

; Buffer for ASCII codes of number's digits.
NUM_BUFFER        db  64 dup(0)
NUM_BUFFER_SIZE   equ $ - NUM_BUFFER

; Buffer for chars to print.
PRINT_BUFFER      db  64 dup (0)
PRINT_BUFFER_SIZE equ $ - PRINT_BUFFER

; Amount of digits after dot (for %f).
PRECISION         equ 6

section .rodata

; Need for movsd in xmm register in %f handling.
ONE               dq 1.
TEN               dq 10.0

; Array for converting numbers to ASCII.
CONVERT_ARRAY     db  "0123456789abcdef"

; Jump table for handling specifiers.
JUMP_TABLE:
            dq handle_invalid ; a
            dq handle_binary  ; b
            dq handle_char    ; c
            dq handle_decimal ; d
            dq handle_invalid ; e
            dq handle_float   ; f
            dq handle_invalid ; g
            dq handle_invalid ; h
            dq handle_invalid ; i
            dq handle_invalid ; j
            dq handle_invalid ; k
            dq handle_invalid ; l
            dq handle_invalid ; m
            dq handle_invalid ; n
            dq handle_octal   ; o
            dq handle_invalid ; p
            dq handle_invalid ; q
            dq handle_invalid ; r
            dq handle_string  ; s
            dq handle_invalid ; t
            dq handle_invalid ; u
            dq handle_invalid ; v
            dq handle_invalid ; w
            dq handle_hex     ; x
            dq handle_invalid ; y
            dq handle_invalid ; z

section .text
global my_printf

; ----------------------------------------------------------------------------------------
; Puts a symbol into the PRINTING_BUFFER. If needed, flush it.
;
; Entry: %1 = char_to_print
;
; Exit:  None
;
; Destr: r11 (syscall destroys it, if buffer flushes)
; ----------------------------------------------------------------------------------------
%macro put_symbol 1
; If current amount of chars in buffer is lower than size of buffer don't flush it
    cmp r10, PRINT_BUFFER_SIZE
    jb .no_flush

; buffer_flush will make r10 = 0, which will update buffer.
    call buffer_flush

.no_flush:
; Put into the buffer cl == char_to_print.
    mov byte [PRINT_BUFFER + r10], %1

; Moving to the next position in the PRINTING_BUFFER.
    inc r10

%endmacro

; ----------------------------------------------------------------------------------------
; Wrapper for libC's printf analog (System V AMD64 ABI)
;
; Entry: rdi   = format
;        rsi   = 1st argument
;        rdx   = 2nd argument
;        rcx   = 3d  argument
;        r8    = 4th argument
;        r9    = 5th argument
;        stack = rsp —> |6th arg|—|7th arg|— ...
;
; Exit:  eax = amount of format elements
;
; Destr: rdi, rsi, rdx, rcx, r10, r11
; ----------------------------------------------------------------------------------------
my_printf:
; In stack we have: rsp —> |return address|— ...
; We want make it:  rsp —> |1th arg|—|2nd arg|— ... —|last arg|—|return address|
    pop r10

; Pushing 1st to 5th arguments. 6th+ arguments are already in stack.
; If there is less than 5 arguments, it won't be crucial if we push extra registers.
    push r9
    push r8
    push rcx
    push rdx
    push rsi

; Pushing 1st to 7th float arguments. 7th+ float arguments are already in stack.
; Allocate memory on stack — 8 registers, each 8 bytes.
    sub rsp, 8 * 8

    movsd [rsp + 0 * 8], xmm0
    movsd [rsp + 1 * 8], xmm1
    movsd [rsp + 2 * 8], xmm2
    movsd [rsp + 3 * 8], xmm3
    movsd [rsp + 4 * 8], xmm4
    movsd [rsp + 5 * 8], xmm5
    movsd [rsp + 6 * 8], xmm6
    movsd [rsp + 7 * 8], xmm7

    call stack_printf

; We must balance the stack.
; We pushed 13 registers — each 8 bytes.
    add rsp, 13 * 8

; We don't have return address in stack, so we can do push r10, than ret. Or just
    jmp r10

; ----------------------------------------------------------------------------------------
; Analog of libC's function printf
;
; Entry: rdi = format
;        on stack: additional parameters
;
; Exit:  eax = amount of format elements
;
; Destr: rdi, rsi, rdx, rcx, rbx, r11, r8
; ----------------------------------------------------------------------------------------
stack_printf:
; We will use rbp for addressing to additional args, we must save (rbp is a callee-saved).
    push rbp
; In stack we have: rsp —> |rbp|—|return address|—|... 8 float args ...|-|1st arg|.
; So to appeal with additional arguments we must do rbp += 16.
    lea rbp, [rsp + 16 + 8 * 8]

; We will use r9 for addressing to float args.
    lea r9, [rsp + 16]
; We will use r11 for addressing to first arguments, which caller pushed in the stack.
; We need this for float arguments to rightly behave in situations such as
; format = "[%f 9+ times][default specifiers]"
    lea r11, [rsp + 16 + 13 * 8]

; We will use r12 for counting amount of printed floats.
; r12 is a callee-saved, so we need to save it.
    push r12
    xor r12, r12

; We destroy rbx, but System V ADM64 ABI assume that rbx is a callee-save, so
    push rbx

; We will use r10 for current amount of chars in buffer.
; In func my_printf r10 contains return address, so we must save it.
    push r10
    xor r10, r10

; Initialize amount of format elements: eax = 0.
    xor eax, eax

.printing_loop:
; If current symbol is terminating, exit the loop.
    cmp byte [rdi], 0
    je .terminate

; Else if current symbol is not '%', it is a default char
    cmp byte [rdi], '%'
    jne .default_char

; Else current symbol is a specifier.
; Increment rdi, because we will parse next symbol.
    inc rdi

; If next symbol is '%' we shouldn't parse anything. Just print '%'
    cmp byte [rdi], '%'
    je .default_char

; Else we parse specifier.
    call parse_specifier

; If eax = -1 in parse_specifier an error occurred, so we exit the loop.
    cmp eax, -1
    je .terminate

; Else go to the next iteration.
    jmp .next_iteration

.default_char:
; cl = current char in format string
    mov cl, [rdi]
    put_symbol cl

.next_iteration:
; Make rdi pointing on the next char.
    inc rdi
    jmp .printing_loop

.terminate:
; Flush the buffer.
    call buffer_flush

    add rax, r12

; Restore r10, rbp.
    pop r10
    pop rbx
    pop r12
    pop rbp
    ret

; ------------- ---------------------------------------------------------------------------
; Parse specifier after '%' symbol in the string to print via function 'my_printf'
;
; Entry: [rdi] = specifier
;        rbp   = argument
;
; Exit:  eax  = -1, if invalid specifier.
;        eax++; rbp += 8, if everything ok.
;
; Destr: rbx, rcx, rdx, r8, rsi
; ----------------------------------------------------------------------------------------
parse_specifier:
; We will use jump table. It consists of english alphabet letters, so
; rdi must be between 'a' and 'z' ASCII codes. Else this is invalid specifier
    cmp byte [rdi], 'a'
    jb handle_invalid
    cmp byte [rdi], 'z'
    ja handle_invalid

; cl = ASCII code of char == index in jump table
    xor rcx, rcx
    mov cl, [rdi]

; Table consists of alphabet letters, so we need to sub 'a' code from ASCII code of char.
    mov rcx, [JUMP_TABLE - 'a' * 8 + rcx * 8]
; rcx = address of label to jump, according to rdx
    jmp rcx

; This is a routine ending of specifier handling functions.
; These functions don't do ret, because they aren't meant to be called.
; We access to them via jump on address in jump table.
routine_after_handling_specifier:
; In eax we have amount of format elements. We parsed another one so eax++.
    inc eax

; Make rbp pointing on the next argument in the stack.
    add rbp, 8

; If we wasted rsi, rdx, rcx, r8, r9 we should synchronize
    cmp eax, 5
    je  .now_we_take_default_arguments_from_stack
    ja  .synchornize_float_pointer
    jmp .exit_from_routine_after_handling_specifier

.now_we_take_default_arguments_from_stack:
    lea rbp, [r11 + r12 * 8 - 8 * 8]
    jmp .exit_from_routine_after_handling_specifier
.synchornize_float_pointer:
    inc r12
.exit_from_routine_after_handling_specifier:
    ret

routine_after_handling_f_specifier:
; ; In eax we have amount of format elements. We parsed another one so eax++.
;     inc eax

; We parsed another double.
    inc r12

    cmp eax, 5
    jae .synchornize_default_pointer
    jmp .exit_from_routine_after_handling_f_specifier

.synchornize_default_pointer:
    add rbp, 8

.exit_from_routine_after_handling_f_specifier:
    ret

handle_invalid:
; -1 is an error return code.
    mov eax, -1
    ret

; ----------------------------------------------------------------------------------------
; Put a buffer into the PRINT_BUFFER. If needed, flush it.
;
; Entry: rcx = length of buffer to put
;        rsi = address of buffer to put
;
; Exit:  None
;
; Destr: None
; ----------------------------------------------------------------------------------------
%macro put_buffer 0
; If length of buffer is less than free space in PRINT_BUFFER, we can merge them.
; r8 = PRINT_BUFFER_SIZE - r10 — amount of free space in PRINT_BUFFER.
    mov r8, PRINT_BUFFER_SIZE
    sub r8, r10

; If we can, merge buffers.
    cmp rcx, r8
    jb .merge_buffers

; Else we must flush PRINT_BUFFER before merging.
    call buffer_flush

.merge_buffers:
; rdi = address of free space in PRINT_BUFFER.
    lea rdi, [PRINT_BUFFER + r10]

; PRINT_BUFFER expands, because of merging buffers.
    add r10, rcx

; We are moving forward.
    cld

; Putting buffer in PRINT_BUFFER.
    rep movsb

%endmacro

; ----------------------------------------------------------------------------------------
; Flushes first r10 bytes of PRINT_BUFFER
;
; Entry: r10 = amount of bytes to flush
;
; Exit:  None
;
; Destr: None
; ----------------------------------------------------------------------------------------
buffer_flush:
; If buffer is empty, don't flush it.
    test r10, r10
    jz .exit

; We don't use buffer_flush frequently.
; So it's better to not scratch registers, than
; save them every time when print_char is called.
; We save r11 and rcx, because syscall may destroy it.
    push r11
    push rcx
    push rax
    push rsi
    push rdi
    push rdx

; rax = syscall code of "write"
    mov rax, 0x01
; rsi = address of buffer
    mov rsi, PRINT_BUFFER
; rdi = stdout file descriptor
    mov rdi, 1
; rdx = amount of chars to print
    mov rdx, r10

    syscall

; Update amount of chars in buffer: r10 = 0.
    xor r10, r10

    pop rdx
    pop rdi
    pop rsi
    pop rax
    pop rcx
    pop r11

.exit:
    ret

; ----------------------------------------------------------------------------------------
; Handle %c specifier.
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &char_to_print
;
; Exit:  None
;
; Destr: cl
; ----------------------------------------------------------------------------------------
handle_char:
    mov cl, [rbp]
    put_symbol cl

    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %s specifier.
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: [rbp] = &string_to_print[0]
;
; Exit:  None
;
; Destr: rcx
; ----------------------------------------------------------------------------------------
handle_string:
; Save rbp
    push rbp
    push rbx
    push rdi

; rbp = address of string to print.
    mov rbp, [rbp]

; We will use rcx for calculating length of the string.
    xor rcx, rcx

.calculate_strlen:
; cl = char_to_print.
    mov bl, [rbp]

; If current char is terminating end the loop.
    cmp bl, 0
    je .put_string_in_buffer

; Else strlen++
    inc rcx
; Going to the next char.
    inc rbp
    jmp .calculate_strlen


.put_string_in_buffer:
; rsi = address of start of the string.
    mov rsi, rbp
    sub rsi, rcx

    put_buffer

; Restore saved registers
    pop rdi
    pop rbx
    pop rbp
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %d specifier
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &number_to_print
;
; Exit: None
;
; Destr: rbx, rcx, rdx, r8
; ----------------------------------------------------------------------------------------
handle_decimal:
; Save rax, cause stack_printf uses it.
    push rax

; eax = number_ro_print
    mov eax, [rbp]
; rsi = base of the number
    mov r8, 10
    call number_to_ascii

; Restore rax.
    pop rax
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %b specifier
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr: rbx, rcx, rdx
; ----------------------------------------------------------------------------------------
handle_binary:
; Save rax, cause stack_printf uses it.
    push rax

; eax = number_to_print
    mov eax, [rbp]
; base = 2^1, rcx = ln_2(base)
    mov rcx, 1
; rbx — bit mask for getting bytes which we need for this base.
    mov rbx, 0b00000001
    call power_of_two_to_ascii

; Restore rax.
    pop rax
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %o specifier
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr: rbx, rcx, rdx, r8
; ----------------------------------------------------------------------------------------
handle_octal:
; Save rax, cause stack_printf uses it.
    push rax

; eax = number_to_print
    mov eax, [rbp]
; base = 2^3, rcx = ln_2(base)
    mov rcx, 3
; rbx — bit mask for getting bytes which we need for this base.
    mov rbx, 0b00000111
    call power_of_two_to_ascii

; Restore rax.
    pop rax
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %x specifier
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr: rbx, rcx, rdx, r8
; ----------------------------------------------------------------------------------------
handle_hex:
; Save rax, cause stack_printf uses it.
    push rax

; eax = number_to_print
    mov eax, [rbp]
; base = 2^4, rcx = ln_2(base)
    mov rcx, 4
; rbx — bit mask for getting bytes which we need for this base.
    mov rbx, 0b00001111
    call power_of_two_to_ascii

; Restore rax.
    pop rax
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Print number in specific base.
;
; Entry: rax = number_to_print
;        r8 = base
;
; Exit:  None
;
; Destr: rax, rbx, rcx, rdx, rdi, rsi, r8
; ----------------------------------------------------------------------------------------
number_to_ascii:
; Save rdi, because stack_printf uses it.
    push rdi

; Check if rax is negative, jns - checks sign flag
    test eax, eax
    jns .number_is_not_negative

.number_is_negative:
; print minus sign
    put_symbol '-'
; eax = -eax
    neg eax

.number_is_not_negative:
; We are getting ASCII codes from CONVERT_ARRAY.
    mov rsi, CONVERT_ARRAY
; rdi - end of the filling buffer.
    mov rdi, NUM_BUFFER + NUM_BUFFER_SIZE - 1
; We are filling the buffer backwards.
    std

.convert_loop:
; div r8 <=> (rdx:rax)/r8
; We divide 64-bit number, so rdx = 0.
    xor rdx, rdx
    div r8

; In rdx we have a division remainder.
; Divider is less than 255, so hole remainder is in dl.

; [rsi + rdx] = ASCII CODE of dl
    add rsi, rdx

; Put ASCII code of dl in the NUM_BUFFER.
    movsb
; Return rsi to the previous value
    mov rsi, CONVERT_ARRAY

; Convert while rax != 0.
    test eax, eax
    jnz .convert_loop

; rcx — amount of chars, putted in the NUM_BUFFER <=> length of number.
    mov rcx,  NUM_BUFFER + NUM_BUFFER_SIZE - 1
    sub rcx, rdi

; rsi = NUM_BUFFER + NUM_BUFFER_SIZE - rcx — address of number to print.
    mov rsi, NUM_BUFFER + NUM_BUFFER_SIZE
    sub rsi, rcx

    put_buffer

; Restore saved registers
    pop rdi

    ret

; ----------------------------------------------------------------------------------------
; Print number (32 bytes) in power of 2 base.
;
; Entry: eax = number_to_print
;        rcx = power of 2 (for example base = 16 <=> cl = 4)
;        rbx = bit mask
;
; Exit:  None
;
; Destr: rdx, rsi, rcx, r8
; ----------------------------------------------------------------------------------------
power_of_two_to_ascii:
; Save rdi, because stack_printf uses it.
    push rdi

; We are getting ASCII codes from CONVERT_ARRAY.
    mov rsi, CONVERT_ARRAY
; rdi - end of the filling buffer.
    mov rdi, NUM_BUFFER + NUM_BUFFER_SIZE - 1
; We are filling the buffer backwards.
    std

.convert_loop:
; rdx — copy of current number (rax == eax).
    mov rdx, rax
; Moving high bits, which we don't need.
    and rdx, rbx
; Going to the next bits.
    shr eax, cl

; [rsi + rdx] = ASCII CODE of dl
    add rsi, rdx

; Put ASCII code of dl in the NUM_BUFFER.
    movsb
; Return rsi to the previous value
    mov rsi, CONVERT_ARRAY

; Convert while rax != 0.
    test eax, eax
    jnz .convert_loop

; rcx — amount of chars, putted in the NUM_BUFFER <=> length of number.
    mov rcx,  NUM_BUFFER + NUM_BUFFER_SIZE - 1
    sub rcx, rdi

; rsi = NUM_BUFFER + NUM_BUFFER_SIZE - rcx — address of number to print.
    mov rsi, NUM_BUFFER + NUM_BUFFER_SIZE
    sub rsi, rcx

    put_buffer

; Restore saved registers
    pop rdi

    ret


; ----------------------------------------------------------------------------------------
; Handle %f specifier
;
; Entry: r12             = amount_of_printed_floats
;        [r9 + r12]      = float_to_print  (if r12 <= 7)
;        [r11 + r12 - 8] = &float_to_print (if r12 >= 8)
;
; Exit:  None
;
; Destr: rax, rdx, xmm0, xmm1, xmm2
; ----------------------------------------------------------------------------------------
handle_float:
; Save rax and rdi, because stack_printf uses it.
    push rax
    push rdi

; If amount_of_printed_chars is less than 8, we should address to saved xmm0, ... on stack
    cmp r12, 8
    jae .use_9_and_more_floats

; rax = float_to_print
    movsd xmm0, [r9 + r12 * 8]
    jmp .convert_float_to_chars

.use_9_and_more_floats:
    movsd xmm0, [r11 + r12 * 8 - 8 * 8]

.convert_float_to_chars:
; Check if xmm0 is negative.
; eax = sign bin of xmm0.
    movmskpd eax, xmm0
; If eax is 0, it means that xmm0's sign bit is 0, so xmm0 is not negative.
    test eax, 1
    jz .double_is_not_negative

; Else xmm0 is negative
    put_symbol '-'

; xmm0 = 0.0 - xmm0 = -xmm0
; xmm1 = 0.0
    xorpd xmm1, xmm1
; xmm1 = 0.0 - xmm0
    subsd xmm1, xmm0
; xmm0 = xmm1
    movapd xmm0, xmm1

.double_is_not_negative:
    call split_xmm0
; rax = integer;
; rdx = fraction;
; rcx = amount of trailing zeros
    call print_integer_and_fraction

; Restore saved registers.
    pop rdi
    pop rax

    jmp routine_after_handling_f_specifier

; ----------------------------------------------------------------------------------------
; Puts in buffer amount of zeroes
;
; Entry: rcx = amount of zeroes to print
;
; Exit:  None
;
; Destr: r8, rdi, rcx, al
; ----------------------------------------------------------------------------------------
%macro put_zeroes 0
; If rcx is less than free space in PRINT_BUFFER, we can put zeroes.
; r8 = PRINT_BUFFER_SIZE - r10 — amount of free space in PRINT_BUFFER.
    mov r8, PRINT_BUFFER_SIZE
    sub r8, r10

; If we can, put_zeroes.
    cmp rcx, r8
    jb .put_zeroes

; Else we must flush PRINT_BUFFER before merging.
    call buffer_flush

.put_zeroes:
; rdi = address of free space in PRINT_BUFFER.
    lea rdi, [PRINT_BUFFER + r10]

; PRINT_BUFFER expands, because of merging buffers.
    add r10, rcx

; We are moving forward.
    cld
; Putting zeroes.
    mov al, '0'
; Putting rcx zeroes in PRINT_BUFFER.
    rep stosb

%endmacro

; ----------------------------------------------------------------------------------------
; Prints [rax].[rdx], where [rax], [rdx] — numbers with base == 10.
;
; Entry: rax = integer
;        rdx = fraction
;
; Exit:  None
;
; Destr: rax, rbx, rcx, rdx, rdi, rsi, r8
; ----------------------------------------------------------------------------------------
print_integer_and_fraction:
; Print integer.
; r8 = base.
    mov r8, 10
; Save rcx, rdx.
    push rcx
    push rdx
    call number_to_ascii
    pop rdx
    pop rcx

; Print dot
    put_symbol '.'

    put_zeroes

; Print fraction.
; r8 = base.
    mov r8, 10
; rax = rdx — number to print.
    mov rax, rdx
    call number_to_ascii

    ret

; ----------------------------------------------------------------------------------------
; Splits double to integer and fraction.
; 10 in power of amount_of_digits_after_dot in fraction lays in precision.
;
; Entry: xmm0 = double_to_split
;
; Exit:  rax = round_towards_zero(xmm0)
;        rdx = round_towards_zero((xmm0 - round_towards_zero(xmm0)) * precision)
;        rcx = amount_of_trailing_zeroes
;
; Destr: xmm1, xmm2, xmm3
; ----------------------------------------------------------------------------------------
split_xmm0:
; Convert double to integer and fraction (truncate toward zero)
; Save xmm0 in xmm1.
    movsd xmm1, xmm0
; xmm0 = round_toward_zero(xmm0) (through rax)
    cvttsd2si rax, xmm0
    cvtsi2sd  xmm0, rax

; xmm1 = xmm1 - xmm0 == old_xmm0 - round_toward_zero(xmm0) == fraction_of_xmm0
    subsd xmm1, xmm0

; We will multiply by 10 every step, to count amount of trailing zeroes.
    movsd xmm2, [TEN]
; We will compare xmm1 with 1.
    movsd xmm3, [ONE]
; rcx = amount of digits after dot
    mov rcx, PRECISION
; If fraction is 0.000000, we need to display 5 trailing zeroes, so
    mov rdx, 1

.count_trailing_zeroes:
; xmm1 = xmm1 * 10
    mulsd xmm1, xmm2

; Compare xmm1 and 1
    ucomisd xmm1, xmm3
; If xmm1 is lower than 1 and PRECISION isn't reached, continue
    jb .is_lower_than_one

; Else xmm1 is bigger than 1.
; It means, that we have PRECISION - rcx trailing zeroes.
; Save rcx in rdx
    mov rdx, rcx

; We need xmm1 = xmm1 * 10^(rcx-1).
; If rcx == 1 loop will cause overflow, so we need to parse this case separatly.
    cmp rcx, 1
    je .end_of_cycle

    dec rcx
.multiply_on_ten:
    mulsd xmm1, xmm2
    loop .multiply_on_ten
    jmp .end_of_cycle

.is_lower_than_one:
    loop .count_trailing_zeroes

.end_of_cycle:
; rcx = amount of trailing zeroes
    mov rcx, PRECISION
    sub rcx, rdx

; In xmm1 we have fractional part. We need to round it.
; Mode 0: round to nearest (even ties).
    roundsd xmm1, xmm1, 0

; rdx = round_toward_zero(xmm1) = numbers_after_dot
    cvttsd2si rdx, xmm1

    ret
