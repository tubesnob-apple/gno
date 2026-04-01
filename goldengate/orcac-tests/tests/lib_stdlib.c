/*
 * lib_stdlib.c — compile-only validation of <stdlib.h>
 * EXPECT: compile success
 */
#pragma optimize 16
#include <stdlib.h>

/* ── Memory allocation ──────────────────────────────────────────────── */
static void test_alloc(void) {
    void *p;
    p = malloc(100);
    p = calloc(10, sizeof(int));
    p = realloc(p, 200);
    free(p);
    (void)p;
}

/* ── String conversions ─────────────────────────────────────────────── */
static void test_conv(void) {
    int    i;
    long   l;
    double d;
    char  *end;

    i = atoi("42");    (void)i;
    l = atol("99");    (void)l;
    d = atof("3.14"); (void)d;

    l = strtol("0xff", &end, 16);  (void)l; (void)end;
    (void)strtoul("100", NULL, 10);
    (void)strtod("1.5", NULL);
}

/* ── Arithmetic ─────────────────────────────────────────────────────── */
static void test_arith(void) {
    (void)abs(-5);
    (void)labs(-100000L);
    div_t  dv = div(17, 3);   (void)dv;
    ldiv_t ld = ldiv(17L, 3L);(void)ld;
}

/* ── Searching and sorting ──────────────────────────────────────────── */
static int cmp(const void *a, const void *b) {
    return *(int*)a - *(int*)b;
}

static void test_sort(void) {
    int arr[5] = {3, 1, 4, 1, 5};
    qsort(arr, 5, sizeof(int), cmp);
    int key = 4;
    (void)bsearch(&key, arr, 5, sizeof(int), cmp);
}

/* ── Random ─────────────────────────────────────────────────────────── */
static void test_rand(void) {
    srand(42);
    (void)rand();
}

/* ── Environment / process ──────────────────────────────────────────── */
static void test_env(void) {
    (void)getenv("PATH");
    /* exit(0) and abort() omitted — would stop the test */
}
