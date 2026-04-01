/*
 * neg_atomics.c — C11 _Atomic types
 * EXPECT: compile FAIL
 *
 * ORCA/C defines __STDC_NO_ATOMICS__ — atomics not supported.
 */
#include <stdatomic.h>

_Atomic int counter = 0;
