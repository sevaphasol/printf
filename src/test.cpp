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

    my_printf("%f %f %f %f %f %f %f %f %f %f %f %f %c %c %c %c %c %f %c %f %c %f %f %c %c\n",
              1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, '1', '1', '1', '1', '1', 13.0, '1',
              13.0, '1', 13.0, 13.0, '1', '1' );
    // my_printf("%f %d %s %f %c %b\n", 112313.12312, 123, "papoe", 14.88, '1', 0b11110000 );
    // my_printf("%o %s\n", -1, "huy");

    // printf("%f\n", 11111111111111111111.0);

//     my_printf("%o\n%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b\n",
//       -1,
//       -1,
//       "love",
//       3802,
//       100,
//       33,
//       127,
//       -1,
//      "love", 3802, 100, 33, 127);
//
//     printf("%o\n%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b\n",
//       -1,
//       -1,
//       "love",
//       3802,
//       100,
//       33,
//       127,
//       -1,
//      "love", 3802, 100, 33, 127);

    return 0;
}
