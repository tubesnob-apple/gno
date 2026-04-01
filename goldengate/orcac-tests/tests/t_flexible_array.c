/*
 * t_flexible_array.c — C99 flexible array members
 * EXPECT: compile success
 */
#include <stddef.h>

/* struct with flexible array member */
struct Buffer {
    size_t len;
    unsigned char data[];   /* flexible array member — must be last */
};

struct StringBuf {
    int count;
    char strings[];
};

/* sizeof does not include the FAM */
int test_flexible(void) {
    /* sizeof(struct Buffer) == sizeof(size_t) */
    size_t sz = sizeof(struct Buffer);
    (void)sz;
    return 0;
}
