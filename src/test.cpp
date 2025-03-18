#include <stdio.h>

/* We have to use extern "C" here, because we don't want the compiler to change the function names. */
/* It happens because of "name mangling" for .cpp files.                                            */
extern "C" int my_printf(const char* format, ...);

/* We compile with -nostdlib flag, so we don't have an entry point.     */
/* Because of that we name this function _start — it is an entry point. */
int main()
{
    /* Testing my_printf. It returns amount of formatted elements. */
    /* If there is an error, it returns -1.                        */
    my_printf("%o\n%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b\n",
      -1,
      -1,
      "love",
      3802,
      100,
      33,
      127,
      -1,
     "love", 3802, 100, 33, 127);

    printf("%o\n%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b\n",
      -1,
      -1,
      "love",
      3802,
      100,
      33,
      127,
      -1,
     "love", 3802, 100, 33, 127);

    return 0;

    /* We compile with -nostdlib flag, so we have to exit the program all alone. */
    /* asm - insert asm code, volatile - no need for an optimization.            */
    // asm volatile (
    //     ".intel_syntax noprefix" "\n" /* I don't want to use AT&T.                     */
    //     "mov rax, 0x3c"          "\n" /* rax = syscall exit code.                      */
    //     "mov rdi, 0"             "\n" /* rdi = return value.                           */
    //     "syscall"                "\n" /* exit.                                         */
    //     ".att_syntax prefix"     "\n" /* gcc wants to use AT&T, so we restore it.      */
    // );
}
