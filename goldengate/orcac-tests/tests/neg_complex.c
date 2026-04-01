/*
 * neg_complex.c — C99 complex number types
 * EXPECT: compile FAIL
 *
 * ORCA/C defines __STDC_NO_COMPLEX__ — complex types not supported.
 */
#include <complex.h>

double complex z = 1.0 + 2.0 * I;
