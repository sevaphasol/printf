extern "C" long my_printf(const char* format, ...);

int main()
{
    long ret_value = my_printf("Hello %x %o %d %s %%!\n", 0x123, 0123, 111111111111, "\ttest string");
    my_printf("%d\n", ret_value);

    return 0;
}
