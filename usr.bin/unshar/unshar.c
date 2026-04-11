/*
 * unshar -- extract files from a shell archive
 *
 * Usage: unshar [file ...]
 *   If no files given, read stdin.
 *
 * Passes each shar file to /bin/sh for execution.
 * For stdin, copies to a temp file first, then execs sh.
 */

#ifndef lint
static const char sccsid[] = "@(#)unshar.c  GNO/ME 2.0.6";
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

#ifdef __ORCAC__
/* #pragma memorymodel 1 — removed: ABI mismatch with GNO libc */
#endif

#define SHELL   "/bin/sh"

/*
 * Run /bin/sh on fname.
 * Returns the shell's exit status, or -1 on fork/exec error.
 */
#pragma databank 1
static void
unshar_child(char *fname)
{
    execl(SHELL, "sh", fname, (char *)NULL);
    perror("unshar: exec");
    _exit(127);
}
#pragma databank 0

static int
run_sh(fname)
    char *fname;
{
    pid_t       pid;
    union wait  st;
    int         ret;

    pid = fork(unshar_child, 1024, 0, "unshar", 2, fname);
    if (pid < 0) {
        perror("unshar: fork");
        return -1;
    }
    /* parent: wait */
    ret = 0;
    if (waitpid(pid, &st, 0) < 0) {
        perror("unshar: waitpid");
        return -1;
    }
    if (WIFEXITED(st))
        ret = WEXITSTATUS(st);
    else
        ret = 1;
    return ret;
}

/*
 * Copy stdin to a temp file, return the temp filename.
 * Returns NULL on error.
 * Caller is responsible for unlinking the temp file.
 */
static char *
stdin_to_tmp()
{
    static char tmpname[64];
    FILE       *fp;
    int         c;

    strcpy(tmpname, "/tmp/unsharXXXXXX");
    mktemp(tmpname);
    if (tmpname[0] == '\0') {
        fprintf(stderr, "unshar: mktemp failed\n");
        return (char *)NULL;
    }

    fp = fopen(tmpname, "w");
    if (fp == NULL) {
        perror(tmpname);
        return (char *)NULL;
    }

    while ((c = getchar()) != EOF)
        putc(c, fp);

    if (ferror(fp)) {
        perror(tmpname);
        fclose(fp);
        unlink(tmpname);
        return (char *)NULL;
    }

    fclose(fp);
    return tmpname;
}

int
main(argc, argv)
    int   argc;
    char *argv[];
{
    int     i;
    int     ret;
    int     ec;
    char   *tmp;

    ec = 0;

    if (argc <= 1) {
        /* no file args: copy stdin to temp, run sh on it */
        tmp = stdin_to_tmp();
        if (tmp == NULL)
            exit(1);
        ret = run_sh(tmp);
        unlink(tmp);
        if (ret != 0)
            ec = ret;
    } else {
        for (i = 1; i < argc; i++) {
            ret = run_sh(argv[i]);
            if (ret != 0)
                ec = ret;
        }
    }

    exit(ec);
}
