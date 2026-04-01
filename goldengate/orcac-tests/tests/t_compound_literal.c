/*
 * t_compound_literal.c — C99 compound literals
 * EXPECT: compile success
 */

struct Point { int x; int y; };

struct Point make_point(int x, int y) {
    return (struct Point){ .x = x, .y = y };
}

int sum_array(int *a, int n) {
    int i, s = 0;
    for (i = 0; i < n; i++) s += a[i];
    return s;
}

int test_compound(void) {
    /* struct compound literal */
    struct Point p = (struct Point){ 3, 4 };

    /* array compound literal */
    int s = sum_array((int[]){ 1, 2, 3, 4, 5 }, 5);

    /* compound literal in expression */
    struct Point *pp = &(struct Point){ .x = 10, .y = 20 };

    return (p.x == 3 && s == 15 && pp->y == 20) ? 0 : 1;
}
