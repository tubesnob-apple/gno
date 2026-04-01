/*
 * t_snprintf.c — C99 snprintf / vsnprintf
 * EXPECT: compile success
 */
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

static int my_fmt(char *buf, size_t n, const char *fmt, ...) {
    va_list ap;
    int r;
    va_start(ap, fmt);
    r = vsnprintf(buf, n, fmt, ap);
    va_end(ap);
    return r;
}

int test_snprintf(void) {
    char buf[32];
    int n;

    /* basic snprintf */
    n = snprintf(buf, sizeof(buf), "%d + %d = %d", 1, 2, 3);

    /* truncation: snprintf returns the would-be length */
    n = snprintf(buf, 5, "hello world");   /* writes "hell\0", returns 11 */

    /* vsnprintf */
    n = my_fmt(buf, sizeof(buf), "val=%d", 42);

    return (n > 0) ? 0 : 1;
}
