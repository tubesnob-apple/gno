/*
 * t_stdbool.c — C99 <stdbool.h> macros
 * EXPECT: compile success
 */
#include <stdbool.h>

/* Verify macros expand as expected */
_Static_assert(true  == 1, "true must be 1");
_Static_assert(false == 0, "false must be 0");
_Static_assert(sizeof(bool) == sizeof(_Bool), "bool == _Bool");

bool global_flag = true;
bool another     = false;

bool toggle(bool b) {
    return !b;
}

int test_stdbool(void) {
    bool a = true;
    bool b = false;
    bool c = toggle(a);
    bool d = (3 > 2);   /* relational expression yields bool */

    return (a && !b && c == false && d == true) ? 0 : 1;
}
