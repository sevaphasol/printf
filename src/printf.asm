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

; Array for converting numbers to ASCII.
CONVERT_ARRAY     db  "0123456789abcdef"

; Jump table for handling specifiers.
JUMP_TABLE:
            dq handle_invalid ; a
            dq handle_binary  ; b
            dq handle_char    ; c
            dq handle_decimal ; d
            dq handle_invalid ; e
            dq handle_invalid ; f
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

    call stack_printf

; We must balance the stack.
; We pushed 5 registers — each 8 bytes, so it will be 40 bytes.
    add rsp, 40

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
; Destr: rdi, rsi, rdx, rcx, rbx, r11
; ----------------------------------------------------------------------------------------
stack_printf:
; We will use rbp for addressing to additional parameters.
    push rbp
    mov rbp, rsp

; In stack we have: rsp —> |rbp|—|return address|—|1st arg|.
; So to appeal with additional arguments we must do rbp += 16.
    add rbp, 16

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
    call putchar

.next_iteration:
; Make rdi pointing on the next char.
    inc rdi
    jmp .printing_loop

.terminate:
; Flush the buffer.
    call buffer_flush

; Restore r10, rbp.
    pop r10
    pop rbx
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
; Destr: rbx, rcx, rdx
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
    ret

handle_invalid:
; -1 is an error return code.
    mov eax, -1
    ret

; ----------------------------------------------------------------------------------------
; Put a char into the PRINTING_BUFFER. If needed, flush it.
;
; Entry: cl  = char_to_print
;        r10 = current amount of chars in buffer
;
; Exit:  None
;
; Destr: r11 (syscall destroys it, if buffer flushes)
; ----------------------------------------------------------------------------------------
putchar:
; If current amount of chars in buffer is lower than size of buffer don't flush it
    cmp r10, PRINT_BUFFER_SIZE
    jb .no_flush

; buffer_flush will make r10 = 0, which will update buffer.
    call buffer_flush

.no_flush:
; Put into the buffer cl == char_to_print.
    mov byte [PRINT_BUFFER + r10], cl

; Moving to the next position in the PRINTING_BUFFER.
    inc r10

    ret

; ----------------------------------------------------------------------------------------
; Flushes first r10 bytes of PRINT_BUFFER
;
; Entry: r10 = amount of bytes to flush
;
; Exit:  None
;
; Destr: r11 (syscall destroys it)
; ----------------------------------------------------------------------------------------
buffer_flush:
; If buffer is empty, don't flush it.
    test r10, r10
    jz .exit

; We don't use buffer_flush frequently.
; So it's better to not scratch registers, than
; save them every time when print_char is called.
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
; Destr: r11
; ----------------------------------------------------------------------------------------
handle_char:
; putchar(*rbp)
    mov cl, [rbp]
    call putchar

    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %s specifier.
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: [rbp] = &string_to_print[0]
;
; Exit:  None
;
; Destr: rcx, r11
; ----------------------------------------------------------------------------------------
handle_string:
; Save rbp
    push rbp

; rbp = address of string to print.
    mov rbp, [rbp]

.next_char:
; cl = char_to_print.
    mov cl, [rbp]

; If current char is terminating end the loop.
    cmp cl, 0
    je .close

; Else print put char in buffer.
    call putchar

; Going to the next char.
    inc rbp
    jmp .next_char

.close:
    pop rbp
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %d specifier
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr: rbx, rcx, rdx
; ----------------------------------------------------------------------------------------
handle_decimal:
; rsi = base of the number
    mov rsi, 10
    call number_to_ascii

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
; rsi = base of the number
    mov rsi, 2
    call number_to_ascii

    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %o specifier
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr: rbx, rcx, rdx
; ----------------------------------------------------------------------------------------
handle_octal:
; rsi = base of the number
    mov rsi, 8
    call number_to_ascii

    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %x specifier
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr: rbx, rcx, rdx
; ----------------------------------------------------------------------------------------
handle_hex:
; rsi = base of the number
    mov rsi, 16
    call number_to_ascii

    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Print number (32 bytes) in specific base.
;
; Entry: rbp = &number_to_print
;        rsi = base
;
; Exit:  None
;
; Destr: rax, rbx, rcx, rdx, rdi
; ----------------------------------------------------------------------------------------
number_to_ascii:
; Save rax and rdi, because stack_printf uses them.
    push rdi
    push rax

; rax = decimal_to_print
    mov eax, [rbp]

; Check if rax is negative, jns - checks sign flag
    test eax, eax
    jns .decimal_is_not_negative

.decimal_is_negative:
; print minus sign
    mov cl, '-'
    call putchar

; eax = -eax
    neg eax

.decimal_is_not_negative:
; rbx - end of the buffer
    mov rbx, NUM_BUFFER + NUM_BUFFER_SIZE - 1

; rcx - counter of digits
    xor rcx, rcx

.convert_loop:
; One more digit.
    inc rcx

; div r12 <=> (rdx:rax)/r12
; We divide 64-bit number, so rdx = 0.
    xor rdx, rdx
    div rsi

; In rdx we have a division remainder.
; Divider is less than 255, so hole remainder is in dl.

; Get ASCII code of remainder.
    mov dl, [CONVERT_ARRAY + rdx]
; Put ASCII code of remainder in the NUM_BUFFER.
    mov [rbx], dl
; rbx-- — going to the next cell of buffer (right to left)
    dec rbx
; Convert while rax != 0.
    test eax, eax
    jnz .convert_loop

; If length of number is less than free space in PRINT_BUFFER,
; we can merge part of NUM_BUFFER (number to print) and PRINT_BUFFER.

; Save r12, because System V AMD64 ABI assume that r12 is a callee-save
    push r12

; r12 = PRINT_BUFFER_SIZE - r10 — amount of free space in PRINT_BUFFER.
    mov r12, r10
    sub r12, PRINT_BUFFER_SIZE
    neg r12

; If we can merge buffers.
    cmp rcx, r12
    jb .merge_buffers

; Else we must flush PRINT_BUFFER, than merge buffers.
    call buffer_flush

.merge_buffers:
; rsi = NUM_BUFFER + NUM_BUFFER_SIZE - rcx — address of number to print.
    mov rsi, rcx
    sub rsi, NUM_BUFFER + NUM_BUFFER_SIZE
    neg rsi

; rdi = address of free space in PRINT_BUFFER.
    lea rdi, [PRINT_BUFFER + r10]

; PRINT_BUFFER expands, because of merging buffers.
    add r10, rcx

; Putting number in PRINT_BUFFER.
    rep movsb

; Restore saved resisters
    pop r12
    pop rax
    pop rdi

    ret
