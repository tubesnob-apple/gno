/*
 * lib_assert.c — compile-only validation of <assert.h>
 * EXPECT: compile success
 */
#include <assert.h>

static void test_assert(void) {
    int x = 1;
    assert(x == 1);     /* should not fire */
    assert(x > 0);

    /* NDEBUG disables assert */
}

/* _Static_assert works at file scope */
_Static_assert(sizeof(int) >= 2, "int must be at least 16-bit");
_Static_assert(sizeof(long) >= 4, "long must be at least 32-bit");
