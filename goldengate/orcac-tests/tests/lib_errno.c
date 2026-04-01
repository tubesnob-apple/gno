/*
 * lib_errno.c — compile-only validation of <errno.h>
 * EXPECT: compile success
 */
#include <errno.h>
#include <string.h>

static void test_errno(void) {
    /* Standard errno constants */
    (void)EDOM;
    (void)ERANGE;
    (void)ENOENT;
    (void)ENOMEM;
    (void)EACCES;
    (void)EEXIST;
    (void)EINVAL;
    (void)EIO;
    (void)EBADF;
#ifdef ECHILD
    (void)ECHILD;
#endif
#ifdef EAGAIN
    (void)EAGAIN;
#endif
#ifdef ENOSPC
    (void)ENOSPC;
#endif
#ifdef EPERM
    (void)EPERM;
#endif
#ifdef ENOTDIR
    (void)ENOTDIR;
#endif
#ifdef EISDIR
    (void)EISDIR;
#endif
#ifdef EMFILE
    (void)EMFILE;
#endif

    /* errno is settable and readable */
    errno = 0;
    (void)errno;

    /* strerror maps errno values */
    (void)strerror(ENOENT);
    (void)strerror(ENOMEM);
    (void)strerror(0);
}
