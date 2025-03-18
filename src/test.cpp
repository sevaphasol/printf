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
}
