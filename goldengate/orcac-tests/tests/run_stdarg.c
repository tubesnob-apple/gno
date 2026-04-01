/*
 * run_stdarg.c — runtime tests for <stdarg.h>
 * EXIT: 0 on pass, non-zero on first failure
 */
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

#define CHECK(num, cond) \
    do { if (!(cond)) { \
        printf("FAIL test %d: %s\n", (num), #cond); \
        return (num); \
    } } while (0)

/* ── Helpers ────────────────────────────────────────────────────────── */
static int sum_n_ints(int n, ...) {
    va_list ap;
    int total = 0, i;
    va_start(ap, n);
    for (i = 0; i < n; i++)
        total += va_arg(ap, int);
    va_end(ap);
    return total;
}

static long sum_n_longs(int n, ...) {
    va_list ap;
    long total = 0;
    int i;
    va_start(ap, n);
    for (i = 0; i < n; i++)
        total += va_arg(ap, long);
    va_end(ap);
    return total;
}

/* mixed: int, long, int, long */
static long mixed4(int dummy, ...) {
    va_list ap;
    int  a, c;
    long b, d;
    (void)dummy;
    va_start(ap, dummy);
    a = va_arg(ap, int);
    b = va_arg(ap, long);
    c = va_arg(ap, int);
    d = va_arg(ap, long);
    va_end(ap);
    return a + b + c + d;
}

static int vsprintf_helper(char *buf, int bufsz, const char *fmt, ...) {
    va_list ap;
    int r;
    va_start(ap, fmt);
    r = vsnprintf(buf, (size_t)bufsz, fmt, ap);
    va_end(ap);
    return r;
}

/* ── Tests ──────────────────────────────────────────────────────────── */
static int test_sum_ints(void) {
    CHECK(1, sum_n_ints(1, 42)          == 42);
    CHECK(2, sum_n_ints(3, 1, 2, 3)     == 6);
    CHECK(3, sum_n_ints(5, 1,2,3,4,5)   == 15);
    CHECK(4, sum_n_ints(0)              == 0);
    return 0;
}

static int test_sum_longs(void) {
    CHECK(10, sum_n_longs(1, 100000L)           == 100000L);
    CHECK(11, sum_n_longs(2, 100000L, 200000L)  == 300000L);
    CHECK(12, sum_n_longs(3, 1L, 2L, 3L)        == 6L);
    return 0;
}

static int test_mixed(void) {
    /* 1 + 2L + 3 + 4L = 10 */
    CHECK(20, mixed4(0, 1, 2L, 3, 4L) == 10L);
    /* 10 + 100L + 1000 + 10000L = 11110 */
    CHECK(21, mixed4(0, 10, 100L, 1000, 10000L) == 11110L);
    return 0;
}

static int test_vsnprintf(void) {
    char buf[32];
    int  r;
    r = vsprintf_helper(buf, sizeof(buf), "%d %s", 42, "hi");
    CHECK(30, strcmp(buf, "42 hi") == 0);
    CHECK(31, r == 5);

    r = vsprintf_helper(buf, 4, "%d", 12345);
    CHECK(32, strcmp(buf, "123") == 0);
    CHECK(33, r == 5);
    return 0;
}

int main(void) {
    int r;
    if ((r = test_sum_ints()))  return r;
    if ((r = test_sum_longs())) return r;
    if ((r = test_mixed()))     return r;
    if ((r = test_vsnprintf())) return r;
    printf("PASS run_stdarg\n");
    return 0;
}
