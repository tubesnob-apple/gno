/*
 * run_stdio.c — runtime tests for <stdio.h> (sprintf/sscanf/snprintf)
 * EXIT: 0 on pass, non-zero on first failure
 *
 * Focuses on in-memory formatting (sprintf/sscanf/snprintf) which works
 * without filesystem I/O and is most critical for the GNO runtime.
 */
#include <stdio.h>
#include <string.h>

#define CHECK(num, cond) \
    do { if (!(cond)) { \
        printf("FAIL test %d: %s\n", (num), #cond); \
        return (num); \
    } } while (0)

/* ── sprintf ────────────────────────────────────────────────────────── */
static int test_sprintf_int(void) {
    char buf[32];
    sprintf(buf, "%d", 0);       CHECK(1, strcmp(buf, "0")    == 0);
    sprintf(buf, "%d", 42);      CHECK(2, strcmp(buf, "42")   == 0);
    sprintf(buf, "%d", -1);      CHECK(3, strcmp(buf, "-1")   == 0);
    sprintf(buf, "%d", 32767);   CHECK(4, strcmp(buf, "32767")== 0);
    sprintf(buf, "%u", 65535U);  CHECK(5, strcmp(buf, "65535")== 0);
    sprintf(buf, "%x", 0xDEAD);  CHECK(6, strcmp(buf, "dead") == 0);
    sprintf(buf, "%X", 0xDEAD);  CHECK(7, strcmp(buf, "DEAD") == 0);
    sprintf(buf, "%o", 8);       CHECK(8, strcmp(buf, "10")   == 0);
    return 0;
}

static int test_sprintf_long(void) {
    char buf[32];
    sprintf(buf, "%ld", 100000L);    CHECK(10, strcmp(buf, "100000")  == 0);
    sprintf(buf, "%ld", -100000L);   CHECK(11, strcmp(buf, "-100000") == 0);
    sprintf(buf, "%lu", 65536UL);    CHECK(12, strcmp(buf, "65536")   == 0);
    sprintf(buf, "%lx", 0xABCDEFUL);CHECK(13, strcmp(buf, "abcdef")  == 0);
    return 0;
}

static int test_sprintf_string(void) {
    char buf[32];
    sprintf(buf, "%s", "hello");      CHECK(20, strcmp(buf, "hello")     == 0);
    sprintf(buf, "%s", "");           CHECK(21, strcmp(buf, "")           == 0);
    sprintf(buf, "<%5s>", "hi");      CHECK(22, strcmp(buf, "<   hi>")    == 0);
    sprintf(buf, "<%-5s>", "hi");     CHECK(23, strcmp(buf, "<hi   >")    == 0);
    sprintf(buf, "%.3s", "hello");    CHECK(24, strcmp(buf, "hel")        == 0);
    return 0;
}

static int test_sprintf_char(void) {
    char buf[8];
    sprintf(buf, "%c", 'A');   CHECK(30, buf[0] == 'A' && buf[1] == '\0');
    sprintf(buf, "%c%c", 'h', 'i'); CHECK(31, strcmp(buf, "hi") == 0);
    return 0;
}

static int test_sprintf_width(void) {
    char buf[32];
    sprintf(buf, "%5d",   42);  CHECK(40, strcmp(buf, "   42") == 0);
    sprintf(buf, "%-5d",  42);  CHECK(41, strcmp(buf, "42   ") == 0);
    sprintf(buf, "%05d",  42);  CHECK(42, strcmp(buf, "00042") == 0);
    sprintf(buf, "%+d",   42);  CHECK(43, strcmp(buf, "+42")   == 0);
    sprintf(buf, "%+d",  -42);  CHECK(44, strcmp(buf, "-42")   == 0);
    return 0;
}

static int test_sprintf_float(void) {
    char buf[32];
    /* Use generous tolerance ranges */
    sprintf(buf, "%f", 0.0);    CHECK(50, strcmp(buf, "0.000000") == 0);
    sprintf(buf, "%.2f", 3.14); CHECK(51, strcmp(buf, "3.14")     == 0);
    sprintf(buf, "%.0f", 2.5);  CHECK(52, buf[0] >= '2' && buf[0] <= '3');
    sprintf(buf, "%e", 1000.0); CHECK(53, buf[0] == '1');   /* 1.000000e+03 */
    return 0;
}

static int test_sprintf_misc(void) {
    char buf[32];
    int  n;
    sprintf(buf, "%%");             CHECK(60, strcmp(buf, "%")  == 0);
    sprintf(buf, "%d%%", 50);       CHECK(61, strcmp(buf, "50%")== 0);
    sprintf(buf, "%d%n", 42, &n);   CHECK(62, n == 2);
    return 0;
}

/* ── snprintf ───────────────────────────────────────────────────────── */
static int test_snprintf(void) {
    char buf[8];
    int  r;
    r = snprintf(buf, 4, "%d", 12345);
    CHECK(70, strcmp(buf, "123") == 0);   /* truncated */
    CHECK(71, r == 5);                     /* would-be length */

    r = snprintf(buf, sizeof(buf), "hi");
    CHECK(72, strcmp(buf, "hi") == 0 && r == 2);
    return 0;
}

/* ── sscanf ─────────────────────────────────────────────────────────── */
static int test_sscanf_int(void) {
    int  i;
    long l;
    unsigned int  u;
    unsigned long ul;

    sscanf("42",     "%d",  &i);  CHECK(80, i == 42);
    sscanf("-7",     "%d",  &i);  CHECK(81, i == -7);
    sscanf("65535",  "%u",  &u);  CHECK(82, u == 65535U);
    sscanf("ff",     "%x",  &u);  CHECK(83, u == 255U);
    sscanf("100000", "%ld", &l);  CHECK(84, l == 100000L);
    sscanf("FFFF",   "%lx", &ul); CHECK(85, ul == 65535UL);
    return 0;
}

static int test_sscanf_string(void) {
    char s[32];
    int  n;
    sscanf("hello world", "%s", s);    CHECK(90, strcmp(s, "hello") == 0);
    n = sscanf("1 2 3", "%s", s);      CHECK(91, n == 1);
    return 0;
}

static int test_sscanf_multi(void) {
    int  a, b;
    char s[16];
    int  n;
    n = sscanf("10 20 foo", "%d %d %s", &a, &b, s);
    CHECK(100, n == 3);
    CHECK(101, a == 10 && b == 20);
    CHECK(102, strcmp(s, "foo") == 0);
    return 0;
}

static int test_sscanf_float(void) {
    double d;
    sscanf("3.14", "%lf", &d);
    CHECK(110, d > 3.13 && d < 3.15);
    return 0;
}

/* ── puts / putchar interaction via stdout ──────────────────────────── */
static int test_puts(void) {
    /* Just verify they don't crash; we can't easily capture stdout here */
    int r;
    r = fputs("", stdout);    CHECK(120, r >= 0);
    return 0;
}

int main(void) {
    int r;
    if ((r = test_sprintf_int()))    return r;
    if ((r = test_sprintf_long()))   return r;
    if ((r = test_sprintf_string())) return r;
    if ((r = test_sprintf_char()))   return r;
    if ((r = test_sprintf_width()))  return r;
    if ((r = test_sprintf_float()))  return r;
    if ((r = test_sprintf_misc()))   return r;
    if ((r = test_snprintf()))       return r;
    if ((r = test_sscanf_int()))     return r;
    if ((r = test_sscanf_string()))  return r;
    if ((r = test_sscanf_multi()))   return r;
    if ((r = test_sscanf_float()))   return r;
    if ((r = test_puts()))           return r;
    printf("PASS run_stdio\n");
    return 0;
}
