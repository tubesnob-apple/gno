/*
 * lib_time.c — compile-only validation of <time.h>
 * EXPECT: compile success
 */
#include <time.h>

static void test_time(void) {
    time_t   t;
    clock_t  c;
    struct tm tm_val;
    char      buf[64];

    t = time(NULL);
    (void)t;
    c = clock();
    (void)c;

    (void)difftime(t, t);

    tm_val.tm_year = 124;   /* 2024 */
    tm_val.tm_mon  = 0;
    tm_val.tm_mday = 1;
    tm_val.tm_hour = 0;
    tm_val.tm_min  = 0;
    tm_val.tm_sec  = 0;
    tm_val.tm_isdst= -1;
    (void)mktime(&tm_val);

    (void)gmtime(&t);
    (void)localtime(&t);
    (void)asctime(&tm_val);
    (void)ctime(&t);
    (void)strftime(buf, sizeof(buf), "%Y-%m-%d", &tm_val);
}
