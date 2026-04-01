/*
 * t_restrict.c — C99 restrict qualifier
 * EXPECT: compile success
 */

/* restrict on pointer parameters */
void copy(int * restrict dst, const int * restrict src, int n) {
    int i;
    for (i = 0; i < n; i++)
        dst[i] = src[i];
}

/* restrict on local pointer */
int sum(int * restrict p, int n) {
    int i, s = 0;
    for (i = 0; i < n; i++)
        s += p[i];
    return s;
}

/* restrict in typedef */
typedef int * restrict rip;
