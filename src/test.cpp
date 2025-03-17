/* We have to use extern "C" here, because we don't want the compiler to change the function names. */
/* It happens because of "name mangling" for .cpp files.                                            */
extern "C" int my_printf(const char* format, ...);

/* We compile with -nostdlib flag, so we don't have an entry point.     */
/* Because of that we name this function _start — it is an entry point. */
extern "C" void _start()
{
    /* Testing my_printf. It returns amount of formatted elements. */
    /* If there is an error, it returns -1.                        */
    int test1 = my_printf("\na lot of vars  "
                          "%%b: %b %b, "
                          "%%c: %c %c, "
                          "%%o: %o %o, "
                          "%%d: %d %d, "
                          "%%x: %x %x, "
                          "%%s: %s\n",
                           0, 1,
                           '2', '3',
                           04, 05,
                           6, 7,
                           0x8, 0x9,
                           "10 11");
    my_printf("a lot of vars returned %d\n\n", test1);

    int test2 = my_printf("maximum positive int %d\n", 0x7fffffff);
    my_printf("maximum positive int returned %d\n\n", test2);

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
