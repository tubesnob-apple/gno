/*
 * t_static_assert.c — C11 _Static_assert
 * EXPECT: compile success
 */
#include <assert.h>     /* provides static_assert macro if C11 */

/* _Static_assert at file scope */
_Static_assert(sizeof(int) >= 2, "int must be at least 16 bits");
_Static_assert(sizeof(long) >= 4, "long must be at least 32 bits");
_Static_assert(1 + 1 == 2, "basic arithmetic must work");

/* _Static_assert inside a function */
int test_static_assert(void) {
    _Static_assert(sizeof(char) == 1, "char must be 1 byte");
    _Static_assert(sizeof(void *) >= 2, "pointer must be at least 2 bytes");
    return 0;
}

/* _Static_assert in struct */
struct Sized {
    char buf[4];
    _Static_assert(sizeof(int) <= 4, "int must fit in 4 bytes on IIgs");
    int value;
};
