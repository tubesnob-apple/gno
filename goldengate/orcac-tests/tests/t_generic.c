/*
 * t_generic.c — C11 _Generic selection expression
 * EXPECT: compile success
 */

/* type-generic absolute value */
#define myabs(x) _Generic((x), \
    int:            abs_int,   \
    long:           abs_long,  \
    double:         abs_double, \
    default:        abs_int    \
)(x)

static int    abs_int(int x)       { return x < 0 ? -x : x; }
static long   abs_long(long x)     { return x < 0L ? -x : x; }
static double abs_double(double x) { return x < 0.0 ? -x : x; }

/* type classification macro */
#define type_name(x) _Generic((x), \
    int:    "int",   \
    double: "double",\
    char:   "char",  \
    default:"other"  \
)

int test_generic(void) {
    int    a = myabs(-5);
    long   b = myabs(-10L);
    double c = myabs(-3.14);

    const char *s1 = type_name(42);
    const char *s2 = type_name(3.14);

    return (a == 5 && b == 10L && c > 3.0 && s1 && s2) ? 0 : 1;
}
