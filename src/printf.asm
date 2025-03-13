; ----------------------------------------------------------------------------------------
; Writes "Hola, mundo" to the console using a C library. Runs on Linux.
;
;     nasm -felf64 hola.asm && gcc hola.o && ./a.out
; ----------------------------------------------------------------------------------------

section .note.GNU-stack noalloc noexec nowrite progbits

section .text
global _start

; ----------------------------------------------------------------------------------------

_start:
    ; ———————— Testing my_printf ————————
    ; Preparing arguments to call my_printf
    push format

    call my_printf

    ; ———————— Exit the programm ————————
    mov rax, 0x3c ; syscall: exit
    xor rdi, rdi  ; exit code = 0
    syscall

; ----------------------------------------------------------------------------------------
; Analog of function printf from libC
;
; Args:     rdi = const char* format
; ----------------------------------------------------------------------------------------
my_printf:
    push rbp
    mov rbp, rsp

    mov rdi, format
    mov rsi, 10
    call buf_dump

    pop rbp
    ret


; ----------------------------------------------------------------------------------------
; Writes buffer in std output
;
; Args:     rdi = const char* buffer
;           rsi = size_t      n_chars
; ----------------------------------------------------------------------------------------
buf_dump:
    push rbp
    mov rbp, rsp

    ; ———————— Save args on stack ————————
    mov [rbp - 8],  rdi
    mov [rbp - 16], rsi

    ; ———————— Prepare to syscall write ————————
    mov rax, 0x01       ; syscall: write(unsigned int fd, const char *buf, size_t count)
    mov rdi, 1          ; stdout
    mov rsi, [rbp - 8]  ; buffer
    mov rdx, [rbp - 16] ; n_chars
    syscall
    ; ——————————————————————————————————————————

    pop rbp
    ret

section .data
format db "First iteration, no %"
