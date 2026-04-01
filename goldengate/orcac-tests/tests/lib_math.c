/*
 * lib_math.c — compile-only validation of <math.h>
 * EXPECT: compile success
 */
#include <math.h>

static void test_trig(void) {
    double x = 1.0;
    (void)sin(x);
    (void)cos(x);
    (void)tan(x);
    (void)asin(x);
    (void)acos(x);
    (void)atan(x);
    (void)atan2(x, x);
}

static void test_exp(void) {
    double x = 2.0;
    (void)exp(x);
    (void)log(x);
    (void)log10(x);
    (void)pow(x, x);
    (void)sqrt(x);
}

static void test_round(void) {
    double x = 1.7;
    (void)floor(x);
    (void)ceil(x);
    (void)fabs(x);
}

static void test_misc(void) {
    double x = 1.5;
    double intpart;
    int    exp2;
    (void)modf(x, &intpart);
    (void)frexp(x, &exp2);
    (void)ldexp(x, 3);
    (void)fmod(x, 1.0);
}
