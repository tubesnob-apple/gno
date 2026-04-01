/*
 * t_noreturn.c — C11 _Noreturn function specifier
 * EXPECT: compile success
 */
#include <stdlib.h>
#include <stdnoreturn.h>    /* provides 'noreturn' macro */

/* _Noreturn keyword form */
_Noreturn void die_keyword(int code) {
    exit(code);
}

/* noreturn macro form (from stdnoreturn.h) */
noreturn void die_macro(int code) {
    exit(code);
}

/* _Noreturn on static function */
static _Noreturn void fatal(void) {
    exit(1);
}

int test_noreturn(void) {
    /* just verify the symbols exist and have correct types */
    if (0) die_keyword(0);
    if (0) die_macro(0);
    if (0) fatal();
    return 0;
}
