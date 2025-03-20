#include <stdio.h>
#include "my_printf.h"

int test1();
int test2();
int test3();

int main()
{
    /* Testing my_printf. It returns amount of formatted elements. */
    /* If there is an error, it returns -1.                        */

    test1() ? my_printf("%qTEST 1 failed%q\n\n", RED, RESET) : my_printf("%qTEST 1 successfull%q\n\n", GREEN, RESET);
    test2() ? my_printf("%qTEST 2 failed%q\n\n", RED, RESET) : my_printf("%qTEST 2 successfull%q\n\n", GREEN, RESET);
    test3() ? my_printf("%qTEST 3 failed%q\n\n", RED, RESET) : my_printf("%qTEST 3 successfull%q\n\n", GREEN, RESET);

    return 0;
}

int test1()
{
    my_printf("%q", PURPLE);

    my_printf("TEST1\n"
              "----------------------------------------------------------------------------------------\n");

    int res1 = my_printf("my_printf:\n"
                         "%f %f %f %f %f %f %f\n%f %f %f %f %f %c %c\n%c %c %c %f %c %f\n%d %f %f %c %s\n\n",
                         1.111111, -2.222222, 3.333333, 4.444444, 5.555555, -6.666666, 7.777777, 8.888888,
                         -9.999999, 10.101010, -11.111111, 12.121212, 'a', 'b', 'c', 'd', 'e', 13.131313,
                         'f', 14.141414, -1, -15.151515, 16.161616, '1', "test1");
    int res2 =  printf   ("printf:\n"
                         "%f %f %f %f %f %f %f\n%f %f %f %f %f %c %c\n%c %c %c %f %c %f\n%d %f %f %c %s\n",
                         1.111111, -2.222222, 3.333333, 4.444444, 5.555555, -6.666666, 7.777777, 8.888888,
                         -9.999999, 10.101010, -11.111111, 12.121212, 'a', 'b', 'c', 'd', 'e', 13.131313,
                         'f', 14.141414, -1, -15.151515, 16.161616, '1', "test1");

    my_printf("----------------------------------------------------------------------------------------\n\n");

    my_printf("%q", RESET);

    return res1 == res2;
}

int test2()
{
    my_printf("%q", YELLOW);

    my_printf("TEST2\n"
              "----------------------------------------------------------------------------------------\n");

    int res1 = my_printf("my_printf:\n"
                         "%f %f %c %c %c %c %c %c %f %c %c %f %f %f %f %c\n%s %d %o %x %b\n",
                         1.123, 2.31231312, '1', '1', '1', '1', '1', '1', 3.13123213, '1', '1', 4.14412,
                         5.123123, 6.654765, 7.858568, '1', "asdasdasdasdasdasdasd", -1, -1, -1, -1);
    int res2 =  printf  ("printf:\n"
                         "%f %f %c %c %c %c %c %c %f %c %c %f %f %f %f %c\n%s %d %o %x %b\n",
                         1.123, 2.31231312, '1', '1', '1', '1', '1', '1', 3.13123213, '1', '1', 4.14412,
                         5.123123, 6.654765, 7.858568, '1', "asdasdasdasdasdasdasd", -1, -1, -1, -1);

    my_printf("----------------------------------------------------------------------------------------\n\n");

    my_printf("%q", RESET);

    return res1 == res2;
}

int test3()
{
    my_printf("%q", LIGHT_BLUE);

    my_printf("TEST3\n"
              "----------------------------------------------------------------------------------------\n");

    int res1 = my_printf("my_printf\n"
                         "%o\n%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b\n",
                         -1, -1, "love", 3802, 100, 33, 127, -1, "love",
                         3802, 100, 33, 127);

    int res2 = printf   ("printf:\n"
                         "%o\n%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b\n",
                         -1, -1, "love", 3802, 100, 33, 127, -1, "love",
                         3802, 100, 33, 127);

    my_printf("----------------------------------------------------------------------------------------\n\n");

    my_printf("%q", RESET);

    return res1 == res2;
}
