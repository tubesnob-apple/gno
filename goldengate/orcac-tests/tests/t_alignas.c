/*
 * t_alignas.c — C11 _Alignas / _Alignof
 * EXPECT: compile success
 *
 * Notes on ORCA/C support:
 *   - _Alignof(type) is supported
 *   - _Alignas(type) is supported
 *   - _Alignas(constant) is NOT supported by ORCA/C 2.2
 *   - stdalign.h macros alignas/alignof map to the keywords
 */
#include <stddef.h>
#include <stdalign.h>   /* alignas / alignof macros */

/* _Alignof on basic types */
_Static_assert(_Alignof(char) == 1, "char align");
_Static_assert(_Alignof(int) >= 1,  "int align");

/* _Alignas(type) — align a buffer to the same alignment as a given type */
_Alignas(int)  char buf_int[4];
_Alignas(long) char buf_long[8];

/* alignof macro form */
_Static_assert(_Alignof(struct { char c; int i; }) >= 1, "struct align");

int test_align(void) {
    _Alignas(int) char local[4];
    size_t a = alignof(double);
    (void)local;
    (void)a;
    return 0;
}
