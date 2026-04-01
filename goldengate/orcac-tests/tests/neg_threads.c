/*
 * neg_threads.c — C11 <threads.h>
 * EXPECT: compile FAIL
 *
 * ORCA/C defines __STDC_NO_THREADS__ — threading not supported.
 */
#include <threads.h>

int thread_fn(void *arg) {
    return 0;
}
