/*
 * t_mixed_decl.c — C99 mixed declarations and statements
 * EXPECT: compile success
 *
 * Note: ORCA/C requires #pragma optimize 16 for C99 mixed decls.
 * Without it, declarations must precede statements (C89 rule).
 */
#pragma optimize 16

int test_mixed(void) {
    int a = 1;
    a = a + 1;          /* statement */
    int b = a * 2;      /* declaration after statement — C99 */
    for (int i = 0; i < 5; i++) {   /* for-init declaration — C99 */
        b += i;
    }
    return (b > 0) ? 0 : 1;
}

int test_for_decl(void) {
    int sum = 0;
    for (int i = 1; i <= 10; i++)
        sum += i;
    return (sum == 55) ? 0 : 1;
}
