/* We have to use extern "C" here, because we don't want the compiler to change the function names. */
/* It happens because of "name mangling" for .cpp files.                                            */
extern "C" long my_printf(const char* format, ...);

/* We compile with -nostdlib flag, so we don't have an entry point.     */
/* Because of that we name this function _start — it is an entry point. */
extern "C" void _start()
{
    /* Testing my_printf. It returns amount of formatted elements. */
    /* If there is an error, it returns -1.                        */
    long ret_value = my_printf("Hello %x %o %d %s %%!\n", 0x123, 0123, 111111111111, "\ttest string");
    my_printf("%d\n", ret_value);

    /* We compile with -nostdlib flag, so we have to exit the program all alone. */
    /* asm - insert asm code, volatile - no need for an optimization.            */
    asm volatile (
        ".intel_syntax noprefix" "\n" /* I don't want to use AT&T.                     */
        "mov rax, 0x3c"          "\n" /* rax = syscall exit code.                      */
        "mov rdi, 0"             "\n" /* rdi = return value.                           */
        "syscall"                "\n" /* exit.                                         */
        ".att_syntax prefix"     "\n" /* gcc wants to use AT&T, so we restore it.      */
    );
}
