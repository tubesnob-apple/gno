/*
 * t_func_name.c — C99 __func__ predefined identifier
 * EXPECT: compile success
 */

const char *get_name(void) {
    return __func__;    /* "get_name" */
}

static const char *inner(void) {
    return __func__;
}

int test_func_name(void) {
    const char *s = get_name();
    const char *t = inner();
    return (s != 0 && t != 0) ? 0 : 1;
}
