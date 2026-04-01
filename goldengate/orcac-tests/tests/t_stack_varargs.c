/*
 * t_stack_varargs.c — varargs calling convention and va_arg stepping
 * EXPECT: compile success
 *
 * Tests that va_arg advances the va_list pointer by the correct number of
 * bytes for each type.  On the 65816 / ORCA/C:
 *   - char, short, int  → 2 bytes on stack  (promoted)
 *   - long              → 4 bytes on stack
 *   - long long         → 8 bytes on stack
 *   - pointer           → 4 bytes on stack  (32-bit)
 *   - double            → 8 bytes on stack
 *
 * What to look for in the disassembly:
 *   - va_start: initialise pointer to first variadic arg slot
 *   - va_arg(ap, int): load 2 bytes, advance ap by 2
 *   - va_arg(ap, long): load 4 bytes, advance ap by 4
 *   - va_arg(ap, double): advance ap by 8
 *   - No off-by-one errors in ap arithmetic
 */
#pragma optimize 16
#include <stdarg.h>

/* Sum N ints */
int sum_ints(int n, ...) {
    va_list ap;
    va_start(ap, n);
    int total = 0;
    int i;
    for (i = 0; i < n; i++)
        total += va_arg(ap, int);
    va_end(ap);
    return total;
}

/* Sum N longs */
long sum_longs(int n, ...) {
    va_list ap;
    va_start(ap, n);
    long total = 0;
    int i;
    for (i = 0; i < n; i++)
        total += va_arg(ap, long);
    va_end(ap);
    return total;
}

/* Mixed: int, long, int, long — verifies stride correctness */
long mixed_varargs(int dummy, ...) {
    va_list ap;
    va_start(ap, dummy);
    int  a = va_arg(ap, int);
    long b = va_arg(ap, long);
    int  c = va_arg(ap, int);
    long d = va_arg(ap, long);
    va_end(ap);
    return a + b + c + d;
}

/* char args are promoted to int on the 65816 */
int sum_chars_as_int(int n, ...) {
    va_list ap;
    va_start(ap, n);
    int total = 0;
    int i;
    for (i = 0; i < n; i++)
        total += va_arg(ap, int);   /* char is promoted to int */
    va_end(ap);
    return total;
}

/* Pointer args — 4 bytes on 65816 */
void *last_ptr(int n, ...) {
    va_list ap;
    va_start(ap, n);
    void *p = 0;
    int i;
    for (i = 0; i < n; i++)
        p = va_arg(ap, void *);
    va_end(ap);
    return p;
}
