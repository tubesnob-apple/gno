/*
 * run_stdlib.c — runtime tests for <stdlib.h>
 * EXIT: 0 on pass, non-zero on first failure
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(num, cond) \
    do { if (!(cond)) { \
        printf("FAIL test %d: %s\n", (num), #cond); \
        return (num); \
    } } while (0)

static int test_atoi(void) {
    CHECK(1, atoi("0")    == 0);
    CHECK(2, atoi("42")   == 42);
    CHECK(3, atoi("-7")   == -7);
    CHECK(4, atoi("  10") == 10);
    return 0;
}

static int test_atol(void) {
    CHECK(10, atol("100000") == 100000L);
    CHECK(11, atol("-1")     == -1L);
    return 0;
}

static int test_atof(void) {
    double d = atof("3.14");
    /* compare with tolerance */
    CHECK(20, d > 3.13 && d < 3.15);
    CHECK(21, atof("0.0") == 0.0);
    return 0;
}

static int test_strtol(void) {
    char *end;
    long v;
    v = strtol("42", &end, 10);
    CHECK(30, v == 42 && *end == '\0');
    v = strtol("0xff", &end, 16);
    CHECK(31, v == 255 && *end == '\0');
    v = strtol("0x1A", &end, 0);   /* auto-detect base */
    CHECK(32, v == 26);
    v = strtol("010", &end, 0);    /* octal */
    CHECK(33, v == 8);
    return 0;
}

static int test_strtoul(void) {
    char *end;
    unsigned long v;
    v = strtoul("65535", &end, 10);
    CHECK(40, v == 65535UL);
    v = strtoul("0xFFFF", NULL, 16);
    CHECK(41, v == 65535UL);
    return 0;
}

static int test_abs_labs(void) {
    CHECK(50, abs(5)    == 5);
    CHECK(51, abs(-5)   == 5);
    CHECK(52, abs(0)    == 0);
    CHECK(53, labs(100000L)  == 100000L);
    CHECK(54, labs(-100000L) == 100000L);
    return 0;
}

static int test_div(void) {
    div_t  d  = div(17, 5);
    ldiv_t ld = ldiv(17L, 5L);
    CHECK(60, d.quot == 3 && d.rem == 2);
    CHECK(61, ld.quot == 3L && ld.rem == 2L);
    return 0;
}

static int cmp_int(const void *a, const void *b) {
    int ia = *(int *)a;
    int ib = *(int *)b;
    if (ia < ib) return -1;
    if (ia > ib) return  1;
    return 0;
}

static int test_qsort(void) {
    int arr[6] = {5, 3, 1, 4, 2, 6};
    int i;
    qsort(arr, 6, sizeof(int), cmp_int);
    for (i = 0; i < 6; i++)
        CHECK(70 + i, arr[i] == i + 1);
    return 0;
}

static int test_bsearch(void) {
    int arr[5] = {1, 2, 3, 4, 5};
    int key;
    int *found;

    key = 3;
    found = (int *)bsearch(&key, arr, 5, sizeof(int), cmp_int);
    CHECK(80, found != NULL && *found == 3);

    key = 9;
    found = (int *)bsearch(&key, arr, 5, sizeof(int), cmp_int);
    CHECK(81, found == NULL);
    return 0;
}

static int test_malloc(void) {
    char *p;
    int   i;

    p = (char *)malloc(128);
    CHECK(90, p != NULL);
    memset(p, 0xAB, 128);
    for (i = 0; i < 128; i++)
        CHECK(91, (unsigned char)p[i] == 0xAB);
    free(p);

    p = (char *)calloc(16, sizeof(char));
    CHECK(92, p != NULL);
    for (i = 0; i < 16; i++)
        CHECK(93, p[i] == 0);
    p = (char *)realloc(p, 32);
    CHECK(94, p != NULL);
    free(p);
    return 0;
}

static int test_rand(void) {
    int i, got_nonzero = 0;
    srand(12345);
    for (i = 0; i < 20; i++)
        if (rand() != 0) got_nonzero = 1;
    CHECK(100, got_nonzero);           /* extremely unlikely to be all zero */
    CHECK(101, rand() >= 0);
    CHECK(102, rand() <= RAND_MAX);
    return 0;
}

int main(void) {
    int r;
    if ((r = test_atoi()))    return r;
    if ((r = test_atol()))    return r;
    if ((r = test_atof()))    return r;
    if ((r = test_strtol()))  return r;
    if ((r = test_strtoul())) return r;
    if ((r = test_abs_labs()))return r;
    if ((r = test_div()))     return r;
    if ((r = test_qsort()))   return r;
    if ((r = test_bsearch())) return r;
    if ((r = test_malloc()))  return r;
    if ((r = test_rand()))    return r;
    printf("PASS run_stdlib\n");
    return 0;
}
