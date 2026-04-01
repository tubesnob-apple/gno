/*
 * lib_signal.c — compile-only validation of <signal.h>
 * EXPECT: compile success
 */
#include <signal.h>

static void my_handler(int sig) {
    (void)sig;
}

static void test_signal(void) {
    /* Standard signals */
    (void)SIGABRT;
    (void)SIGFPE;
    (void)SIGILL;
    (void)SIGINT;
    (void)SIGSEGV;
    (void)SIGTERM;

    /* GNO/POSIX signals (may not all be present in ORCA SDK) */
#ifdef SIGHUP
    (void)SIGHUP;
#endif
#ifdef SIGPIPE
    (void)SIGPIPE;
#endif
#ifdef SIGALRM
    (void)SIGALRM;
#endif

    /* signal() registration */
    (void)signal(SIGINT, my_handler);
    (void)signal(SIGINT, SIG_DFL);
    (void)signal(SIGINT, SIG_IGN);

    /* raise() */
    /* raise(SIGINT) would actually raise — skip at compile time */
}
