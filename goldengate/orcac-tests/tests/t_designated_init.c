/*
 * t_designated_init.c — C99 designated initializers (struct and array)
 * EXPECT: compile success
 */

struct Point { int x; int y; int z; };
struct Named { char *name; int value; };

/* struct designated initializers */
struct Point p1 = { .x = 1, .y = 2, .z = 3 };
struct Point p2 = { .z = 10, .x = 5 };   /* y defaults to 0, order irrelevant */

/* array designated initializers */
int arr[10] = { [0] = 1, [5] = 6, [9] = 10 };
int arr2[] = { [3] = 'A', [1] = 'B' };   /* size inferred as 4 */

/* nested designated initializers */
struct { struct Point pt; int w; } box = {
    .pt = { .x = 1, .y = 2, .z = 3 },
    .w = 4
};

int test_designated(void) {
    struct Named n = { .value = 42, .name = "hello" };
    return (p1.x == 1 && p2.z == 10 && p2.y == 0
            && arr[5] == 6 && n.value == 42) ? 0 : 1;
}
