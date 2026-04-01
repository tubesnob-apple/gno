/*
 * t_stdint.c — C99 <stdint.h> exact-width types
 * EXPECT: compile success
 */
#include <stdint.h>

/* Exact-width integer types */
int8_t   i8  = -128;
uint8_t  u8  = 255;
int16_t  i16 = -32768;
uint16_t u16 = 65535;
int32_t  i32 = -2147483648L;
uint32_t u32 = 4294967295UL;
int64_t  i64 = INT64_MIN;
uint64_t u64 = UINT64_MAX;

/* Minimum-width types */
int_least8_t  li8;
uint_least8_t lu8;

/* Fastest types */
int_fast8_t  fi8;
uint_fast8_t fu8;

/* Pointer-sized integer */
intptr_t  iptr;
uintptr_t uptr;

/* Maximum-width type */
intmax_t  imax = INTMAX_MAX;
uintmax_t umax = UINTMAX_MAX;

_Static_assert(sizeof(int8_t) == 1,  "int8_t size");
_Static_assert(sizeof(int16_t) == 2, "int16_t size");
_Static_assert(sizeof(int32_t) == 4, "int32_t size");

int test_stdint(void) {
    uint8_t a = 0xFF;
    uint16_t b = 0xFFFF;
    uint32_t c = 0xFFFFFFFFUL;
    return (a == 255 && b == 65535 && c == 4294967295UL) ? 0 : 1;
}
