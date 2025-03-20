#ifndef _MY_PRINTF_H__
#define _MY_PRINTF_H__

/* Codes for specifier %q */
enum COLORS
{
    RESET      = -1,
    BLACK      = 0,
    RED        = 1,
    GREEN      = 2,
    YELLOW     = 3,
    BLUE       = 4,
    PURPLE     = 5,
    LIGHT_BLUE = 6,
};

/* We have to use extern "C" here, because we don't want the compiler to change the function names. */
/* It happens because of "name mangling" for .cpp files.                                            */
extern "C" int my_printf(const char* format, ...);

#endif // _MY_PRINTF_H__
