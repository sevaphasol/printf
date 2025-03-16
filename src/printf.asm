; ----------------------------------------------------------------------------------------
; Implementation of printf from libC. Runs on Linux.
; Supported specifiers: %%, %c, %s, %d, %x, %o, %b.
; ----------------------------------------------------------------------------------------

section .data
NUM_BUFFER      db  64 dup(0)          ; buffer for ASCII codes of printing number's digits
NUM_BUFFER_SIZE equ $ - NUM_BUFFER

CONVERT_ARRAY   db  "0123456789abcdef" ; array for converting numbers to ASCII

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
; Wrapper for analog of libC's function printf (System V AMD64 ABI)
;
; Entry: rdi   = format
;        rsi   = 1st argument
;        rdx   = 2nd argument
;        rcx   = 3d  argument
;        r8    = 4th argument
;        r9    = 5th argument
;        stack = rsp —> |6th arg|—|7th arg|— ...
;
; Exit:  rax = amount of format elements
;
; Destr: r10, rdi, rcx
; ----------------------------------------------------------------------------------------
my_printf:
; In stack we have: rsp —> |return address|— ...
; We want make it:  rsp —> |1th arg|—|2nd arg|— ... —|last arg|—|return address|
    pop r10
; Pushing 1st to 5th arguments. 6th+ arguments are already in stack.
    push r9
    push r8
    push rcx
    push rdx
    push rsi
; If there is less than 5 arguments, it won't be crucial if we push extra registers.

    call stack_printf

; We must balance the stack.
; We pushed 5 registers — each 8 bytes, so it will be 40 bytes.
    add rsp, 48

; We don't have return address in stack, so we can do push r10, than ret. Or just
    jmp r10

; ----------------------------------------------------------------------------------------
; Analog of libC's function printf
;
; Entry: rdi = format
;        on stack: additional parameters
;
; Exit:  rax = amount of format elements
;
; Destr: rdi, rcx
; ----------------------------------------------------------------------------------------
stack_printf:
; We will use rbp for addressing to additional parameters.
    push rbp
    mov rbp, rsp

; In stack we have: rsp —> |rbp|—|return address|—|1st arg|.
; So to appeal with additional arguments we must do rbp += 16.
    add rbp, 16

; Amount of format elements.
    xor rax, rax

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

    call parse_specifier
; If rax = -1 in parse_specifier an error occurred, so we exit the loop.
    cmp rax, -1
    je .terminate
; Else go to the next iteration.
    jmp .next_iter

.default_char:
; putchar(rdi)
    call print_char

.next_iter:
; Make rdi pointing on the next char.
    inc rdi
    jmp .printing_loop

.terminate:
; Restore rbp.
    pop rbp
    ret

; ------------- ---------------------------------------------------------------------------
; Parse specifier after '%' symbol in the string to print via function 'printf'
;
; Entry: [rdi] = specifier
;        rbp   = argument
;
; Exit:  rax  = -1, if invalid specifier.
;        rax++; rbp += 8, if everything ok.
;
; Destr: rcx
; ----------------------------------------------------------------------------------------
parse_specifier:
; We will use jump table. It consists of english alphabet letters, so
; rdi must be between 'a' and 'z' ASCII codes. Else this is invalid specifier
    cmp byte [rdi], 'a'
    jb handle_invalid
    cmp byte [rdi], 'z'
    ja handle_invalid

; rcx = ASCII code of char == index in jump table
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
; In rax we have amount of format elements. We parsed another one so rax++.
    inc rax
; Make rbp pointing on the next argument in the stack.
    add rbp, 8
    ret

handle_invalid:
; -1 is an error return code.
    mov rax, -1
    ret

; ----------------------------------------------------------------------------------------
; Print a char to the std output
;
; Entry: rdi = &char_to_print
;
; Exit:  None
;
; Destr: rcx, r11 (syscall destroys it)
; ----------------------------------------------------------------------------------------
print_char:
    push rax
    push rdi
    push rsi
    push rdx

; rax = syscall code of "write"
    mov rax, 0x01
; rsi = address of buffer
    mov rsi, rdi
; rdi = stdout file descriptor
    mov rdi, 1
; rdx = amount of chars to print
    mov rdx, 1

    syscall

    pop rdx
    pop rsi
    pop rdi
    pop rax

    ret

; ----------------------------------------------------------------------------------------
; Handle %c specifier.
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &char_to_print
;
; Exit:  None
;
; Destr: rcx, r11
; ----------------------------------------------------------------------------------------
handle_char:
; putchar(rbp)
    push rdi
    mov rdi, rbp
    call print_char
    pop rdi

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
    push rdi
    mov rdi, [rbp]
.next_char:
    cmp byte [rdi], 0
    je .close
    call print_char
    inc rdi
    jmp .next_char
.close:
    pop rdi
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %d specifier
; NOT FOR CALL. NO RET HERE. ONLY JUMP.
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr:
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
; Destr:
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
; Destr:
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
; Destr:
; ----------------------------------------------------------------------------------------
handle_hex:
; rsi = base of the number
    mov rsi, 16
    call number_to_ascii
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Print number in specific base.
;
; Entry: rbp = &number_to_print
;        rsi = base
;
; Exit:  None
;
; Destr: rax, rdi, rcx, rsi, rdx
; ----------------------------------------------------------------------------------------
number_to_ascii:
; Save registers.
    push rax ; Use it for dividing and syscall.
    push rbx ; Use it for addressing to number buffer.
    push rcx ; Use it for counting digits in number.
    push rdx ; Use it for dividing and syscall.
    push rdi ; Use it for syscall.

; rax = decimal_to_print
    mov rax, [rbp]

; Check if rax is negative, jns - checks sign flag
    test rax, rax
    jns .decimal_is_not_negative

.decimal_is_negative:
; print minus sign
    mov rdi, '-'
    call print_char

; rax = -rax
    neg rax

.decimal_is_not_negative:
; rbx - end of the buffer
    mov rbx, NUM_BUFFER + NUM_BUFFER_SIZE - 1

; rcx - counter of digits
    xor rcx, rcx

.convert_loop:
    inc rcx
; div r12 <=> (rdx:rax)/r12
; We divide 64-bit number, so rdx = 0.
    xor rdx, rdx
    div rsi
; Put ASCII CODE of dl into the buffer
    mov dl, [CONVERT_ARRAY + rdx]
    mov [rbx], dl
; rbx-- — going to the next cell of buffer (right to left)
    dec rbx
; Convert while rax != 0.
    test rax, rax
    jnz .convert_loop

; rax = syscall code of "write"
    mov rax, 0x01
; rsi = address of buffer
    mov rsi, NUM_BUFFER + NUM_BUFFER_SIZE
    sub rsi, rcx
; rdi = stdout file descriptor
    mov rdi, 1
; rdx = amount of chars to print
    mov rdx, rcx

    syscall

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
