/*
 * t_inline.c — C99 inline functions
 * EXPECT: compile success
 */

/* inline function in file scope */
inline int square(int x) {
    return x * x;
}

/* static inline — common idiom */
static inline int cube(int x) {
    return x * x * x;
}

/* inline with external linkage (definition unit) */
extern inline int square(int x);

int test_inline(void) {
    int a = square(4);
    int b = cube(3);
    return (a == 16 && b == 27) ? 0 : 1;
}
