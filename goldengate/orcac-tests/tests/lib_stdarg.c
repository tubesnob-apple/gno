/*
 * lib_stdarg.c — compile-only validation of <stdarg.h>
 * EXPECT: compile success
 */
#include <stdarg.h>
#include <stdio.h>

/* Build a string via vsnprintf */
static int my_fmt(char *buf, int bufsz, const char *fmt, ...) {
    va_list ap;
    int     r;
    va_start(ap, fmt);
    r = vsnprintf(buf, (size_t)bufsz, fmt, ap);
    va_end(ap);
    return r;
}

/* Forward va_list to vfprintf */
static void my_vprint(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    (void)vfprintf(stdout, fmt, ap);
    va_end(ap);
}

/* va_arg with multiple types */
static long sum_mixed(int n, ...) {
    va_list ap;
    long total = 0;
    int i;
    va_start(ap, n);
    for (i = 0; i < n; i++) {
        if (i % 2 == 0)
            total += va_arg(ap, int);
        else
            total += va_arg(ap, long);
    }
    va_end(ap);
    return total;
}

static void test_stdarg(void) {
    char buf[64];
    (void)my_fmt(buf, sizeof(buf), "%d %s", 42, "hi");
    my_vprint("%d\n", 1);
    (void)sum_mixed(4, 1, 2L, 3, 4L);
}
