/*
 * lib_string.c — compile-only validation of <string.h>
 * EXPECT: compile success
 */
#pragma optimize 16
#include <string.h>

static char  dst[64];
static char  src[64];
static void *vp;

static void test_copy(void) {
    (void)strcpy(dst, src);
    (void)strncpy(dst, src, 10);
    (void)memcpy(dst, src, 10);
    (void)memmove(dst, src, 10);
}

static void test_compare(void) {
    int r;
    r = strcmp(dst, src);    (void)r;
    r = strncmp(dst, src, 5);(void)r;
    r = memcmp(dst, src, 5); (void)r;
    r = strcasecmp(dst, src);(void)r;
    r = strncasecmp(dst, src, 5); (void)r;
}

static void test_search(void) {
    (void)strchr(src, 'x');
    (void)strrchr(src, 'x');
    (void)strstr(src, "ab");
    (void)strpbrk(src, "aeiou");
    (void)strcspn(src, "aeiou");
    (void)strspn(src, "aeiou");
}

static void test_len_cat(void) {
    size_t n;
    n = strlen(src);   (void)n;
    (void)strcat(dst, src);
    (void)strncat(dst, src, 5);
}

static void test_mem(void) {
    (void)memset(dst, 0, sizeof(dst));
    (void)memchr(src, 'x', 10);
}

static void test_misc(void) {
    (void)strerror(0);
    (void)strtok(dst, ",");
    (void)vp;
}
