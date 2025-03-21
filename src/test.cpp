#include <stdio.h>
#include <gtest/gtest.h>
#include "my_printf.h"
#include "test_my_printf.h"

TEST(my_printf_test, doubles)
{
    LABEL1
    int res1 = my_printf(ARGS_FOR_TEST1);
    LABEL2
    int res2 = printf(ARGS_FOR_TEST1);
    LABEL3
    RETURN_VALUES(res1, res2);
    LABEL4

    ASSERT_TRUE(res1 == res2);
}

TEST(my_printf_test, test_deda)
{
    LABEL1
    int res1 = my_printf(ARGS_FOR_TEST2);
    LABEL2
    int res2 = printf(ARGS_FOR_TEST2);
    LABEL3
    RETURN_VALUES(res1, res2);
    LABEL4

    ASSERT_TRUE(res1 == res2);
}

TEST(my_printf_test, long_string)
{
    LABEL1
    int res1 = my_printf(ARGS_FOR_TEST3);
    LABEL2
    int res2 = printf(ARGS_FOR_TEST3);
    LABEL3
    RETURN_VALUES(res1, res2);
    LABEL4

    ASSERT_TRUE(res1 == res2);
}

TEST(my_printf_test, double_mixed_with_others)
{
    LABEL1
    int res1 = my_printf(ARGS_FOR_TEST4);
    LABEL2
    int res2 = printf   (ARGS_FOR_TEST4);
    LABEL3
    RETURN_VALUES(res1, res2);
    LABEL4

    ASSERT_TRUE(res1 == res2);
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
