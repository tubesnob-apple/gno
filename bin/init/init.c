/*
 * init - GNO/ME run-level manager (user-space)
 *
 * Sends run-level change requests to initd (PID 2) via GNO IPC.
 * Source reconstructed from 65816 disassembly of the GNO 2.0.6 binary.
 *
 * Usage: init [run-level] [qcwv] [+name] [-name]
 *
 * Run levels: 0-9, s (single-user), b (boot)
 * Flags:      q (query/quiet), v (verbose), c (checkpoint), w (wait)
 * +name:      send enable-entry message to initd for entry 'name'
 * -name:      send disable-entry message to initd for entry 'name'
 *
 * IPC message format (32-bit long, sent to initd PID 2):
 *   Run-level change:
 *     bits[31:24] = cw_flag (1=c, 2=w, 0=none)
 *     bits[23:16] = q_flag  (1=quiet, 0=normal)
 *     bits[15:8]  = run-level char (e.g. '7', 's', 'b')
 *     bits[7:0]   = 0
 *   Query current level:   (0x0300 << 16) | getpid()
 *   Verbose/version query: (0x0301 << 16) | getpid()
 *   Enable entry +X:       (0x0400 << 16) | char_X
 *   Disable entry -X:      (0x0500 << 16) | char_X
 *
 * After each procsend, SIGUSR1 is sent to initd to wake it.
 */

/* #pragma memorymodel 1 — removed: ABI mismatch with GNO libc */

#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <grp.h>
#include <pwd.h>
#include <errno.h>
#include <gno/gno.h>

#define INITD_PID   2
#define MAX_RETRIES 10

/* SIGUSR1 = 30 (from <sys/signal.h>) */
#ifndef SIGUSR1
#define SIGUSR1 30
#endif

/* IPC command codes (go in high word of message) */
#define CMD_QUERY       0x0300UL    /* query current run level */
#define CMD_VQUERY      0x0301UL    /* verbose query (returns initd version) */
#define CMD_ENABLE      0x0400UL    /* enable inittab entry */
#define CMD_DISABLE     0x0500UL    /* disable inittab entry */

/*
 * send_to_initd -- retry procsend up to MAX_RETRIES times,
 *                  then send SIGUSR1 to wake initd.
 * Returns 0 on success, -1 on failure.
 */
static int
send_to_initd(unsigned long msg)
{
    int i;

    for (i = 0; i < MAX_RETRIES; i++) {
        if (procsend(INITD_PID, msg) != -1) {
            kill(INITD_PID, SIGUSR1);
            return 0;
        }
    }

    fprintf(stderr, "init: %s: while sending messages to init\r",
            strerror(errno));
    return -1;
}

/*
 * check_permission -- verify caller is root or in the "wheel" group.
 * Exits with an error message on failure.
 */
static void
check_permission(void)
{
    struct group  *grp;
    struct passwd *pw;
    char         **mem;

    /* Root is always allowed */
    if (geteuid() == 0)
        return;

    grp = getgrnam("wheel");
    if (grp == NULL) {
        fprintf(stderr, "init: %s: Permission denied.\r",
                strerror(errno));
        exit(1);
    }

    /* Direct gid match */
    if (getegid() == grp->gr_gid) {
        endgrent();
        return;
    }

    /* Scan member list for username match */
    pw = getpwuid(geteuid());
    if (pw != NULL) {
        for (mem = grp->gr_mem; mem && *mem; mem++) {
            if (strcmp(*mem, pw->pw_name) == 0) {
                endgrent();
                return;
            }
        }
    }

    endgrent();
    fprintf(stderr, "init: %s: Permission denied.\r", strerror(errno));
    exit(1);
}

/*
 * dispatch_char -- process a single option character, updating flags.
 * Returns:
 *   0  on success
 *  -1  unrecognized character (usage error)
 *  -2  run-level specified twice
 */
static int
dispatch_char(int c, int *p_runlevel, int *p_qflag, int *p_vflag,
              int *p_cwflag)
{
    /* Fold uppercase to lowercase */
    if (c >= 'A' && c <= 'Z')
        c |= 0x20;

    if ((c >= '0' && c <= '9') || c == 's' || c == 'b') {
        if (*p_runlevel != 0 && *p_runlevel != c)
            return -2;
        *p_runlevel = c;
        return 0;
    }
    switch (c) {
    case 'q': *p_qflag  = 1; return 0;
    case 'v': *p_vflag  = 1; return 0;
    case 'c': *p_cwflag = 1; return 0;
    case 'w': *p_cwflag = 2; return 0;
    }
    return -1;
}

int
main(int argc, char **argv)
{
    int runlevel  = 0;  /* run-level char ('0'-'9', 's', 'b'), 0=none */
    int qflag     = 0;  /* quiet flag */
    int vflag     = 0;  /* verbose flag */
    int cwflag    = 0;  /* checkpoint(1) or wait(2) modifier */
    int processed = 0;  /* non-zero if +/- entries were processed */
    const char *p;
    int i, ret;

    check_permission();

    /* Process arguments */
    for (i = 1; i < argc; i++) {
        p = argv[i];

        if (*p == '+' || *p == '-') {
            int sign = *p++;
            unsigned long cmd = (sign == '+') ? CMD_ENABLE : CMD_DISABLE;

            /* +/- takes exactly one entry-name character */
            if (p[0] == '\0' || p[1] != '\0') {
                fprintf(stderr,
                    "usage: init [run-level] [qcwv] [+name] [-name]\r");
                exit(1);
            }
            if (send_to_initd(cmd << 16 | (unsigned char)p[0]) == -1)
                exit(1);
            processed = 1;
        } else {
            /* Plain argument: dispatch each character */
            while (*p) {
                ret = dispatch_char((unsigned char)*p,
                                    &runlevel, &qflag, &vflag, &cwflag);
                if (ret == -2) {
                    fprintf(stderr,
                        "init: cannot specify multiple run levels\r");
                    exit(1);
                }
                if (ret < 0) {
                    fprintf(stderr,
                        "usage: init [run-level] [qcwv] [+name] [-name]\r");
                    exit(1);
                }
                p++;
            }
        }
    }

    /* Verbose: query initd version and display banner */
    if (vflag) {
        unsigned long resp;
        int major, minor;

        printf("GNO/ME init (user init)   version 1.1\r"
               "            (init daemon) version ");
        fflush(stdout);

        if (send_to_initd((CMD_VQUERY << 16) | (unsigned long)getpid()) == 0) {
            resp = procreceive();
            major = (int)((resp >> 8) & 0xFF);
            minor = (int)(resp & 0xFF);
            printf("%d.%d\r", major, minor);
        }
        fflush(stdout);
    }

    /* If any action flags are set, send run-level change message */
    if (runlevel || qflag || cwflag) {
        unsigned long msg;
        /*
         * bits[31:24] = cwflag, bits[23:16] = qflag,
         * bits[15:8] = runlevel char, bits[7:0] = 0
         */
        msg = ((unsigned long)cwflag  << 24) |
              ((unsigned long)qflag   << 16) |
              ((unsigned long)runlevel << 8);
        if (send_to_initd(msg) == -1)
            exit(1);
        return 0;
    }

    /* If only +/- entries were processed, we are done */
    if (processed)
        return 0;

    /* No action args: query and print the current run level */
    {
        unsigned long resp;
        unsigned char lvl;

        if (send_to_initd((CMD_QUERY << 16) | (unsigned long)getpid()) == -1)
            exit(1);
        resp = procreceive();
        lvl  = (unsigned char)(resp & 0xFF);
        printf("Current run level is %c.\r", lvl ? (char)lvl : '?');
        fflush(stdout);
    }

    return 0;
}
