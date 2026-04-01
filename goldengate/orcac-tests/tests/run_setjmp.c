/*
 * run_setjmp.c — runtime tests for <setjmp.h>
 * EXIT: 0 on pass, non-zero on first failure
 */
#include <stdio.h>
#include <setjmp.h>

#define CHECK(num, cond) \
    do { if (!(cond)) { \
        printf("FAIL test %d: %s\n", (num), #cond); \
        return (num); \
    } } while (0)

static jmp_buf env;

/* basic setjmp/longjmp round trip */
static int test_basic(void) {
    int r = setjmp(env);
    if (r == 0) {
        longjmp(env, 1);
        return 99;   /* should not reach here */
    }
    CHECK(1, r == 1);
    return 0;
}

/* longjmp with value != 1 */
static int test_value(void) {
    int r = setjmp(env);
    if (r == 0) {
        longjmp(env, 42);
    }
    CHECK(10, r == 42);
    return 0;
}

/* longjmp(env, 0) must deliver 1 per the C standard */
static int test_zero_val(void) {
    int r = setjmp(env);
    if (r == 0) {
        longjmp(env, 0);
    }
    CHECK(20, r == 1);
    return 0;
}

/* nested setjmp: inner longjmp must not disturb outer env */
static jmp_buf outer_env;
static jmp_buf inner_env;

static int test_nested(void) {
    int r_outer, r_inner;

    r_outer = setjmp(outer_env);
    if (r_outer == 0) {
        r_inner = setjmp(inner_env);
        if (r_inner == 0) {
            longjmp(inner_env, 7);
        }
        CHECK(30, r_inner == 7);
        /* now jump out of the outer frame */
        longjmp(outer_env, 3);
    }
    CHECK(31, r_outer == 3);
    return 0;
}

int main(void) {
    int r;
    if ((r = test_basic()))    return r;
    if ((r = test_value()))    return r;
    if ((r = test_zero_val())) return r;
    if ((r = test_nested()))   return r;
    printf("PASS run_setjmp\n");
    return 0;
}
