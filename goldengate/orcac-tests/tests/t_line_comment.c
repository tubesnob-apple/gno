/*
 * t_line_comment.c — C99 // line comments (also valid in C89 ORCA/C extension)
 * EXPECT: compile success
 */

// This is a line comment
int x = 1; // inline line comment

// Multiple consecutive line comments
// covering several lines

int test_line_comment(void) {
    int a = 1;  // a is one
    int b = 2;  // b is two
    // int c = 3; -- this line is commented out
    return (a + b == 3) ? 0 : 1;
}
