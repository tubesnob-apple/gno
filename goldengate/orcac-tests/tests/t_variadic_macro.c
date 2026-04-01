/*
 * t_variadic_macro.c — C99 variadic macros (__VA_ARGS__)
 * EXPECT: compile success
 */
#include <stdio.h>

/* basic variadic macro */
#define MY_PRINTF(fmt, ...) printf(fmt, __VA_ARGS__)

/* variadic macro wrapping another variadic */
#define DBG(fmt, ...) fprintf(stderr, "[DBG] " fmt "\n", __VA_ARGS__)

/* zero-argument variadic (GNU extension but common) */
#define LOG(fmt, ...) printf(fmt "\n", ##__VA_ARGS__)

/* macro that counts variadic args indirectly */
#define CALL2(f, a, b, ...) f(a, b)

int add(int a, int b) { return a + b; }

int test_variadic_macro(void) {
    int r = CALL2(add, 1, 2, "ignored");
    return (r == 3) ? 0 : 1;
}
