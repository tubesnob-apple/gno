/*
 * t_longlong.c — C99 long long integer type
 * EXPECT: compile success
 */
#include <limits.h>

long long ll_min = LLONG_MIN;
long long ll_max = LLONG_MAX;
unsigned long long ull_max = ULLONG_MAX;

long long add(long long a, long long b) {
    return a + b;
}

long long shift(long long x) {
    return x << 32LL;
}

unsigned long long hex_literal = 0xDEADBEEFCAFEBABEULL;

int test_longlong(void) {
    long long x = 1LL;
    long long y = x << 32;
    unsigned long long u = 0xFFFFFFFFFFFFFFFFULL;
    (void)y;
    (void)u;
    return 0;
}
