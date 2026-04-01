/*
 * run_ctype.c — runtime tests for <ctype.h>
 * EXIT: 0 on pass, non-zero on first failure
 */
#include <stdio.h>
#include <ctype.h>

#define CHECK(num, cond) \
    do { if (!(cond)) { \
        printf("FAIL test %d: %s\n", (num), #cond); \
        return (num); \
    } } while (0)

static int test_isalpha(void) {
    CHECK(1, isalpha('a'));
    CHECK(2, isalpha('Z'));
    CHECK(3, !isalpha('0'));
    CHECK(4, !isalpha(' '));
    CHECK(5, !isalpha('!'));
    return 0;
}

static int test_isdigit(void) {
    CHECK(10, isdigit('0'));
    CHECK(11, isdigit('9'));
    CHECK(12, !isdigit('a'));
    CHECK(13, !isdigit(' '));
    return 0;
}

static int test_isalnum(void) {
    CHECK(20, isalnum('a'));
    CHECK(21, isalnum('0'));
    CHECK(22, !isalnum('!'));
    return 0;
}

static int test_isspace(void) {
    CHECK(30, isspace(' '));
    CHECK(31, isspace('\t'));
    CHECK(32, isspace('\n'));
    CHECK(33, !isspace('a'));
    return 0;
}

static int test_isupper_islower(void) {
    CHECK(40, isupper('A'));
    CHECK(41, !isupper('a'));
    CHECK(42, islower('a'));
    CHECK(43, !islower('A'));
    return 0;
}

static int test_toupper_tolower(void) {
    CHECK(50, toupper('a') == 'A');
    CHECK(51, toupper('A') == 'A');
    CHECK(52, toupper('0') == '0');
    CHECK(53, tolower('A') == 'a');
    CHECK(54, tolower('a') == 'a');
    CHECK(55, tolower('9') == '9');
    return 0;
}

static int test_isxdigit(void) {
    CHECK(60, isxdigit('0'));
    CHECK(61, isxdigit('9'));
    CHECK(62, isxdigit('a'));
    CHECK(63, isxdigit('F'));
    CHECK(64, !isxdigit('g'));
    CHECK(65, !isxdigit(' '));
    return 0;
}

static int test_ispunct(void) {
    CHECK(70, ispunct('!'));
    CHECK(71, ispunct('.'));
    CHECK(72, !ispunct('a'));
    CHECK(73, !ispunct(' '));
    return 0;
}

int main(void) {
    int r;
    if ((r = test_isalpha()))        return r;
    if ((r = test_isdigit()))        return r;
    if ((r = test_isalnum()))        return r;
    if ((r = test_isspace()))        return r;
    if ((r = test_isupper_islower()))return r;
    if ((r = test_toupper_tolower()))return r;
    if ((r = test_isxdigit()))       return r;
    if ((r = test_ispunct()))        return r;
    printf("PASS run_ctype\n");
    return 0;
}
