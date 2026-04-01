/*
 * t_bool.c — C99 _Bool type
 * EXPECT: compile success
 */
#include <stdbool.h>

_Bool flag1 = 0;
_Bool flag2 = 1;

/* stdbool.h macros */
bool bval = true;
bool bval2 = false;

int test_bool(void) {
    _Bool x = 5;    /* non-zero converts to 1 */
    _Bool y = 0;
    return (x == 1 && y == 0) ? 0 : 1;
}
