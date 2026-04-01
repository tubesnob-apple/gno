/*
 * lib_ctype.c — compile-only validation of <ctype.h>
 * EXPECT: compile success
 */
#include <ctype.h>

static void test_classify(void) {
    int c = 'A';
    (void)isalpha(c);
    (void)isdigit(c);
    (void)isalnum(c);
    (void)isspace(c);
    (void)isupper(c);
    (void)islower(c);
    (void)ispunct(c);
    (void)isprint(c);
    (void)isgraph(c);
    (void)iscntrl(c);
    (void)isxdigit(c);
}

static void test_convert(void) {
    int c = 'a';
    (void)toupper(c);
    (void)tolower(c);
}
