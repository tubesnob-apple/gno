/*
 * t_hex_float.c — C99 hexadecimal floating-point constants
 * EXPECT: compile success
 *
 * Notes on ORCA/C support:
 *   - Hex float literals (0x1.0p0) are supported for double and long double.
 *   - The 'f' suffix on hex floats (0x1.0p-1f) is NOT supported by ORCA/C 2.2.
 *   - Use explicit cast or double/long double only.
 */

/* 0x1.0p0 == 1.0, 0x1.8p1 == 3.0, 0x1.0p-1 == 0.5 */
double d1 = 0x1.0p0;
double d2 = 0x1.8p1;
double d3 = 0x1.0p-1;              /* 0.5 — no 'f' suffix */
long double ld1 = 0x1.fffffep+127L;

double hex_neg = -0x1.0p4;         /* -16.0 */
double hex_frac = 0x1.8p0;         /* 1.5 */

int test_hex_float(void) {
    double a = 0x1.0p0;    /* 1.0 */
    double b = 0x1.0p1;    /* 2.0 */
    double c = 0x1.8p1;    /* 3.0 */
    double half = 0x1.0p-1; /* 0.5 */

    return (a == 1.0 && b == 2.0 && c == 3.0 && half == 0.5) ? 0 : 1;
}
