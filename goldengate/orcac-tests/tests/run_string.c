/*
 * run_string.c — runtime tests for <string.h>
 * EXIT: 0 on pass, 1+ on failure (first failing test number printed)
 *
 * Each CHECK() prints FAIL + description and exits non-zero on mismatch.
 */
#include <stdio.h>
#include <string.h>

#define CHECK(num, cond) \
    do { if (!(cond)) { \
        printf("FAIL test %d: %s\n", (num), #cond); \
        return (num); \
    } } while (0)

static int test_strlen(void) {
    CHECK(1, strlen("") == 0);
    CHECK(2, strlen("a") == 1);
    CHECK(3, strlen("hello") == 5);
    return 0;
}

static int test_strcpy(void) {
    char dst[16];
    strcpy(dst, "hello");
    CHECK(10, strcmp(dst, "hello") == 0);
    strncpy(dst, "abcdef", 3);
    dst[3] = '\0';
    CHECK(11, strcmp(dst, "abc") == 0);
    return 0;
}

static int test_strcmp(void) {
    CHECK(20, strcmp("abc", "abc") == 0);
    CHECK(21, strcmp("abc", "abd") < 0);
    CHECK(22, strcmp("abd", "abc") > 0);
    CHECK(23, strncmp("abcX", "abcY", 3) == 0);
    CHECK(24, strncmp("abcX", "abcY", 4) != 0);
    return 0;
}

static int test_strcat(void) {
    char buf[32];
    strcpy(buf, "foo");
    strcat(buf, "bar");
    CHECK(30, strcmp(buf, "foobar") == 0);
    strcpy(buf, "foo");
    strncat(buf, "barXXX", 3);
    CHECK(31, strcmp(buf, "foobar") == 0);
    return 0;
}

static int test_strchr(void) {
    const char *s = "hello world";
    CHECK(40, strchr(s, 'o') == s + 4);
    CHECK(41, strrchr(s, 'o') == s + 7);
    CHECK(42, strchr(s, 'z') == NULL);
    return 0;
}

static int test_strstr(void) {
    const char *s = "hello world";
    CHECK(50, strstr(s, "world") == s + 6);
    CHECK(51, strstr(s, "xyz") == NULL);
    CHECK(52, strstr(s, "") == s);
    return 0;
}

static int test_memcpy(void) {
    char src[8] = "abcdefg";
    char dst[8];
    memcpy(dst, src, 7);
    dst[7] = '\0';
    CHECK(60, strcmp(dst, "abcdefg") == 0);
    return 0;
}

static int test_memmove(void) {
    char buf[16] = "abcdefgh";
    /* overlapping move forward */
    memmove(buf + 2, buf, 6);
    CHECK(70, buf[2] == 'a');
    CHECK(71, buf[7] == 'f');
    return 0;
}

static int test_memset(void) {
    char buf[8];
    memset(buf, 'X', 8);
    CHECK(80, buf[0] == 'X');
    CHECK(81, buf[7] == 'X');
    return 0;
}

static int test_memcmp(void) {
    char a[4] = {1, 2, 3, 4};
    char b[4] = {1, 2, 3, 4};
    char c[4] = {1, 2, 3, 5};
    CHECK(90, memcmp(a, b, 4) == 0);
    CHECK(91, memcmp(a, c, 4) < 0);
    CHECK(92, memcmp(c, a, 4) > 0);
    return 0;
}

static int test_strtok(void) {
    char buf[32];
    char *tok;
    strcpy(buf, "one,two,three");
    tok = strtok(buf, ",");
    CHECK(100, tok != NULL && strcmp(tok, "one") == 0);
    tok = strtok(NULL, ",");
    CHECK(101, tok != NULL && strcmp(tok, "two") == 0);
    tok = strtok(NULL, ",");
    CHECK(102, tok != NULL && strcmp(tok, "three") == 0);
    tok = strtok(NULL, ",");
    CHECK(103, tok == NULL);
    return 0;
}

static int test_strerror(void) {
    /* strerror(0) should return a non-null, non-empty string */
    char *s = strerror(0);
    CHECK(110, s != NULL);
    CHECK(111, strlen(s) > 0);
    return 0;
}

int main(void) {
    int r;
    if ((r = test_strlen()))   return r;
    if ((r = test_strcpy()))   return r;
    if ((r = test_strcmp()))   return r;
    if ((r = test_strcat()))   return r;
    if ((r = test_strchr()))   return r;
    if ((r = test_strstr()))   return r;
    if ((r = test_memcpy()))   return r;
    if ((r = test_memmove()))  return r;
    if ((r = test_memset()))   return r;
    if ((r = test_memcmp()))   return r;
    if ((r = test_strtok()))   return r;
    if ((r = test_strerror())) return r;
    printf("PASS run_string\n");
    return 0;
}
