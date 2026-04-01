/*
 * lib_setjmp.c — compile-only validation of <setjmp.h>
 * EXPECT: compile success
 */
#include <setjmp.h>

static jmp_buf g_env;

static void may_jump(int x) {
    if (x < 0)
        longjmp(g_env, 1);
}

static void test_setjmp(void) {
    int r;
    r = setjmp(g_env);
    if (r == 0) {
        may_jump(-1);   /* will jump back */
    }
    /* arrives here from longjmp with r==1 */
    (void)r;
}
