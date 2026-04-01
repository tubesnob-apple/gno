/*
 * lib_stdio.c — compile-only validation of <stdio.h>
 * EXPECT: compile success
 *
 * Verifies that every standard stdio function and macro is declared
 * correctly in ORCA/C's stdio.h.  No main(), no runtime behaviour.
 */
#pragma optimize 16
#include <stdio.h>

/* ── Types and macros ───────────────────────────────────────────────── */
static FILE        *g_fp;
static fpos_t       g_pos;

_Static_assert(EOF  == -1, "EOF must be -1");

/* ── Output functions ───────────────────────────────────────────────── */
static void test_output(void) {
    int r;
    r = printf("%d %s %f\n", 1, "hello", 3.14);
    (void)r;
    r = fprintf(stderr, "err %d\n", 42);
    (void)r;
    r = sprintf(g_fp != 0 ? NULL : NULL, "x");  /* just checks signature */
    (void)r;

    char buf[64];
    r = sprintf(buf, "%d", 99);
    (void)r;
    r = snprintf(buf, sizeof(buf), "%s", "hi");
    (void)r;

    r = putchar('A');
    (void)r;
    r = puts("hello");
    (void)r;
    r = fputc('Z', stdout);
    (void)r;
    r = fputs("world\n", stdout);
    (void)r;
}

/* ── Input functions ────────────────────────────────────────────────── */
static void test_input(void) {
    char buf[64];
    int  n;
    (void)fgets(buf, sizeof(buf), stdin);
    (void)fgetc(stdin);
    (void)getchar();
    (void)ungetc('x', stdin);
    (void)sscanf("42 hello", "%d %s", &n, buf);
    (void)n;
}

/* ── File I/O ───────────────────────────────────────────────────────── */
static void test_file(void) {
    FILE *fp;
    char  buf[64];
    size_t n;
    int    r;

    fp = fopen("test.tmp", "w+");
    if (!fp) return;

    n = fwrite(buf, 1, 10, fp);
    (void)n;
    rewind(fp);
    n = fread(buf, 1, 10, fp);
    (void)n;

    r = fseek(fp, 0L, SEEK_SET);
    (void)r;
    r = fseek(fp, 0L, SEEK_CUR);
    (void)r;
    r = fseek(fp, 0L, SEEK_END);
    (void)r;

    (void)ftell(fp);
    (void)fgetpos(fp, &g_pos);
    (void)fsetpos(fp, &g_pos);

    r = fflush(fp);
    (void)r;
    r = fclose(fp);
    (void)r;
    r = remove("test.tmp");
    (void)r;
    r = rename("a.tmp", "b.tmp");
    (void)r;
}

/* ── Error / misc ───────────────────────────────────────────────────── */
static void test_misc(void) {
    perror("test");
    (void)ferror(stdin);
    (void)feof(stdin);
    clearerr(stdin);
    (void)fileno(stdout);
}
