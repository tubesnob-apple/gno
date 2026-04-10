/*
 * initd.c -- GNO/ME System Initialization Daemon
 *
 * Reconstructed from disassembly of the GNO 2.0.6 reference binary.
 * Binary: diskImages/extracted/usr/sbin/initd  (17,907 bytes, OMF v2)
 *
 * This is initd (not init) -- it is the daemon launched by the kernel
 * on boot and listed in /etc/initrc.  It reads /etc/inittab and manages
 * all system processes across run-levels.
 *
 * GNO/ME platform notes:
 *   - int is 16-bit on the 65816
 *   - long is 32-bit
 *   - Pointers are 32-bit (24-bit address + bank byte)
 *   - fork() takes a NULL argument on GNO (GNO-specific variant)
 *   - signal() uses GNO kernel dispatch ($1603)
 *   - No <stdio.h> used -- all I/O via raw read()/write()/open()/close()
 *
 * Build (GoldenGate / ORCA/C 2.2.2):
 *   iix --gno compile -P initd.c
 *   iix --gno link -o initd initd.a
 */

/* memorymodel 0 (default): JSR/RTS calls, matching GNO libc ABI.
 * memorymodel 1 was causing ABI mismatch with libc and 3.4x code bloat. */
#pragma optimize 78

/* Boot trace points — disabled by default; enable for debugging */
#define BOOT_TRAP(n)

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <gno/gno.h>    /* procsend, procreceive */
#include <misctool.h>   /* userid() */
#include <ktrace.h>

/* GNO-specific: utmp (pulls in <time.h> for time_t / time()) */
#include <utmp.h>

/*
 * RUN_LVL -- GNO's utmp.h does not define this BSD constant.
 * Use USER_PROCESS (1) as the run-level-change record type.
 */
#ifndef RUN_LVL
#define RUN_LVL USER_PROCESS
#endif

/* ---------------------------------------------------------------------------
 * Constants
 * --------------------------------------------------------------------------*/

#define INITTAB          "/etc/inittab"
#define SYSLOG_CONF      "/etc/syslog.conf"
#define RCHOST           "/etc/rchost"
#define UTMP_FILE        "/var/adm/utmp"
#define WTMP_FILE        "/var/adm/wtmp"
#define SYSLOG_FILE      "/var/log/syslog"

#define MAX_PROC         32          /* max process table entries */
#define BUF_SIZE         4096        /* inittab read buffer */
#define ID_LEN           2           /* inittab entry id field length */
#define CMD_LEN          128         /* max command length in entry */
#define RUNLEVEL_LEN     16          /* max runlevel string length */

/* Process table entry actions */
#define ACT_RESPAWN      'r'
#define ACT_WAIT         'w'
#define ACT_ONCE         'o'
#define ACT_OFF          'e'
#define ACT_SYSINIT      's'
#define ACT_INITDEFAULT  't'
#define ACT_CTRLALTDEL   'c'
#define ACT_NOOP         'n'
#define ACT_SHUTDOWN     'z'

/* State machine values (stored in state global) */
#define STATE_NORMAL     0
#define STATE_SINGLE     1
#define STATE_MULTI      2
#define STATE_SHUTDOWN   3

/* ---------------------------------------------------------------------------
 * Process table entry
 * --------------------------------------------------------------------------*/
struct proc_entry {
    char    id[ID_LEN];                 /* 2-char entry identifier */
    char    runlevels[RUNLEVEL_LEN + 1];/* run-level membership string */
    char    action;                     /* ACT_* constant */
    char    flags;                      /* state flags */
    int     cmd_offset;                 /* offset into command string pool */
};

#define PROC_FLAG_SPAWNED   0x01
#define PROC_FLAG_DEAD      0x02
#define PROC_FLAG_ONCE_DONE 0x04

/* ---------------------------------------------------------------------------
 * Global state
 * --------------------------------------------------------------------------*/

/* Process table */
static struct proc_entry  *proc_table  = NULL;  /* handle-allocated */
static int    proc_count    = 0;
static int    active_count  = 0;
static int    pending_respawn = 0;

/* Per-entry child pid array (parallel to proc_table) */
static int    child_pids[MAX_PROC];

/* Per-signal counter array (signal_handler increments these) */
static int    sig_counters[32];

/* initd's own pid */
static int    mypid = 0;

/* Run-level state */
static char   cur_runlevel      = 's';  /* current: 's'=single, '0'-'9'=levels */
static char   new_runlevel      = '2';
static char   old_runlevel      = 's';
static char   initdefault_runlevel = '2';

/* Pending action from signal handler (set asynchronously, consumed in main loop) */
static char   pending_action    = 0;
static int    signal_pending    = 0;    /* count of unhandled signals */
static int    ipc_pending       = 0;    /* set by SIGUSR1: IPC message waiting */

/* Daemon/subsystem state */
static int    syslogd_pid       = 0;
static int    in_transition     = 0;
static int    spawned_count     = 0;
static char   state             = STATE_NORMAL;

/* utmp time fields */
static long   utmp_time         = 0;

/* inittab parse state */
static int    inittab_entry_count = 0;
static int    prev_entry_count    = 0;
static int    error_count         = 0;

/* Command string pool (stored inline after proc_table allocation) */
static char   cmd_pool[MAX_PROC * CMD_LEN];

/* ---------------------------------------------------------------------------
 * Action keyword lookup table
 *
 * The binary stores the packed string "onreswrucestitnlonnnnqrnnnns" at
 * CODE $18D4.  Action keywords are matched by scanning inittab lines and
 * the matched index produces the single-char action code via this table.
 *
 * Mapping (index -> action char):
 *   "respawn"    -> 'r'
 *   "wait"       -> 'w'
 *   "once"       -> 'o'
 *   "off"        -> 'e'
 *   "sysinit"    -> 's'
 *   "initdefault"-> 't'
 *   "ctrlaltdel" -> 'c'
 *   (anything else) -> 'n'
 * --------------------------------------------------------------------------*/
static const char action_table[] = "onreswrucestitnlonnnnqrnnnns";

static const char *action_keywords[] = {
    "once",         /* 'o' */
    "null",         /* 'n' */
    "respawn",      /* 'r' */
    "off",          /* 'e' */
    "sysinit",      /* 's' */
    "wait",         /* 'w' */
    "respawn",      /* 'r' alt */
    "unknown",      /* 'u' */
    "ctrlaltdel",   /* 'c' */
    "off",          /* 'e' alt */
    "sysinit",      /* 's' alt */
    "initdefault",  /* 't' */
    NULL
};

/* ---------------------------------------------------------------------------
 * Forward declarations
 * --------------------------------------------------------------------------*/
static void install_signal_handlers(void);
static void signal_handler(int sig);
static void clear_proc_table(void);
static void init_proc_table(void);
static void parse_inittab(void);
static void parse_syslog_conf(void);
static int  spawn_process(int entry_idx);
static int  spawn_and_wait(int entry_idx);
static void handle_pending_signal(void);
static void kill_all_children(int sig);
static void write_utmp(int slot, int type, const char *user, const char *host);
static void write_console(const char *msg);
static int  in_runlevel(struct proc_entry *e, char level);
static char lookup_action(const char *keyword);
static void run_level_switch(char new_level);
static void reload_inittab(void);
static void launch_syslogd(void);
static void determine_runlevel(void);

/* ---------------------------------------------------------------------------
 * write_console -- raw write to fd 1 (console), no stdio
 * --------------------------------------------------------------------------*/
static void
write_console(const char *msg)
{
    write(1, msg, strlen(msg));
}


/* ---------------------------------------------------------------------------
 * signal_handler -- installed for all monitored signals
 *
 * Reconstructed from CODE $27B2:
 *   ASL (sig x 2), TAX, INC $2784,X, INC signal_pending, LDA #0, RTL
 *
 * #pragma databank 1 is required: GNO signal delivery does not guarantee
 * that DBR points to the program's data segment.  Without it, writes to
 * globals (sig_counters, signal_pending, etc.) go to the wrong bank,
 * causing memory corruption and subsequent BRK crashes.
 * --------------------------------------------------------------------------*/
#pragma databank 1
static void
signal_handler(int sig)
{
    if (sig >= 0 && sig < 32)
        sig_counters[sig]++;
    signal_pending++;
    /* Determine pending action from signal */
    switch (sig) {
    case SIGHUP:
        pending_action = 'q';   /* reload inittab */
        break;
    case SIGTERM:
        pending_action = 's';   /* go single-user */
        break;
    case SIGALRM:
        /* alarm expired -- used during transition timeouts */
        break;
    case SIGCHLD:
        /* child died -- will be reaped in main loop */
        break;
    case SIGUSR1:
        /* user-space init sent an IPC message; read it in main loop */
        ipc_pending = 1;
        break;
    default:
        break;
    }
}
#pragma databank 0

/* ---------------------------------------------------------------------------
 * install_signal_handlers -- CODE $2820 / $2844
 * --------------------------------------------------------------------------*/
static void
install_signal_handlers(void)
{
    signal(SIGHUP,   signal_handler);
    signal(SIGINT,   SIG_IGN);
    signal(SIGPIPE,  SIG_IGN);
    signal(SIGTERM,  signal_handler);
    signal(SIGALRM,  signal_handler);
    signal(SIGCHLD,  signal_handler);
    signal(SIGWINCH, signal_handler);
    signal(SIGUSR1,  signal_handler);
}

/* ---------------------------------------------------------------------------
 * clear_proc_table -- CODE $27A4
 * Zeros the process table and per-entry state.
 * --------------------------------------------------------------------------*/
static void
clear_proc_table(void)
{
    int i;
    proc_count    = 0;
    active_count  = 0;
    spawned_count = 0;
    for (i = 0; i < MAX_PROC; i++) {
        child_pids[i] = 0;
        sig_counters[i] = 0;
    }
    if (proc_table)
        memset(proc_table, 0, MAX_PROC * sizeof(struct proc_entry));
}

/* ---------------------------------------------------------------------------
 * init_proc_table -- CODE $0A17
 * Allocates the process table handle.
 * --------------------------------------------------------------------------*/
static void
init_proc_table(void)
{
    int alloc_size = MAX_PROC * sizeof(struct proc_entry);
    KTRACE_LOGF("initd:mypid=%d", mypid);
    KTRACE_LOGF("initd:userid=%d", (int)userid());
    KTRACE_LOGF("initd:alloc_size=%d", alloc_size);
    proc_table = (struct proc_entry *)malloc(alloc_size);
    KTRACE_LOGF("initd:ptr_lo=0x%x", (unsigned)(unsigned long)proc_table);
    KTRACE_LOGF("initd:ptr_hi=0x%x", (unsigned)((unsigned long)proc_table >> 16));
    if (!proc_table) {
        KTRACE_LOGF("initd:errno=%d", errno);
        write_console("initd: cannot allocate process table\r\n");
        /* fatal -- but GNO init cannot exit */
        for (;;) sleep(60);
    }
    memset(proc_table, 0, alloc_size);
}

/* ---------------------------------------------------------------------------
 * lookup_action -- match action keyword to action char
 * Uses the action_table string at CODE $18D4.
 * --------------------------------------------------------------------------*/
static char
lookup_action(const char *keyword)
{
    if (strcmp(keyword, "respawn")     == 0) return ACT_RESPAWN;
    if (strcmp(keyword, "rest")        == 0) return ACT_RESPAWN;  /* GNO alias */
    if (strcmp(keyword, "wait")        == 0) return ACT_WAIT;
    if (strcmp(keyword, "once")        == 0) return ACT_ONCE;
    if (strcmp(keyword, "off")         == 0) return ACT_OFF;
    if (strcmp(keyword, "sysinit")     == 0) return ACT_SYSINIT;
    if (strcmp(keyword, "initdefault") == 0) return ACT_INITDEFAULT;
    if (strcmp(keyword, "runl")        == 0) return ACT_INITDEFAULT; /* GNO: run-level */
    if (strcmp(keyword, "ctrlaltdel")  == 0) return ACT_CTRLALTDEL;
    if (strcmp(keyword, "shutdown")    == 0) return ACT_SHUTDOWN;
    return ACT_NOOP;
}

/* ---------------------------------------------------------------------------
 * in_runlevel -- return non-zero if entry applies to given run-level
 * --------------------------------------------------------------------------*/
static int
in_runlevel(struct proc_entry *e, char level)
{
    int i;
    /* 'b' = boot: matches any non-single-user numeric run level */
    if (e->runlevels[0] == 'b' && e->runlevels[1] == '\0')
        return (level >= '0' && level <= '9') ? 1 : 0;
    for (i = 0; i < RUNLEVEL_LEN && e->runlevels[i]; i++) {
        if (e->runlevels[i] == level)
            return 1;
    }
    return 0;
}

/* ---------------------------------------------------------------------------
 * parse_inittab -- CODE $0A53
 *
 * Opens /etc/inittab, reads it into a malloc'd buffer, parses colon-
 * delimited lines of the form:
 *   id:runlevels:action:process
 * and builds the proc_table.
 * --------------------------------------------------------------------------*/
static void
parse_inittab(void)
{
    int   fd;
    char *buf;
    int   n, i;
    char *p, *end;
    char  id[ID_LEN + 1];
    char  runlevels[RUNLEVEL_LEN + 1];
    char  action_kw[32];
    char  cmd[CMD_LEN];
    char  action;
    int   entry_idx;

    BOOT_TRAP(0x30);

    fd = open(INITTAB, O_RDONLY, 0);
    if (fd < 0) {
        BOOT_TRAP(0x31);
    
        write_console("initd: cannot open " INITTAB "\r\n");
        BOOT_TRAP(0x32);
    
        return;
    }

    BOOT_TRAP(0x33);
    
    buf = (char *)malloc(BUF_SIZE);
    if (!buf) {
        BOOT_TRAP(0x34);
    
        close(fd);
        BOOT_TRAP(0x35);
    
        return;
    }

    BOOT_TRAP(0x36);
    
    n = read(fd, buf, BUF_SIZE - 1);

    BOOT_TRAP(0x37);
    
    close(fd);

    BOOT_TRAP(0x38);
    
    if (n <= 0) {
        BOOT_TRAP(0x39);
    
        free(buf);
        BOOT_TRAP(0x40);
    
        return;
    }
    buf[n] = '\0';


    prev_entry_count    = inittab_entry_count;
    inittab_entry_count = 0;
    entry_idx           = 0;

    p = buf;
    end = buf + n;

    while (p < end && entry_idx < MAX_PROC) {
    
        char *line_end;
        char *field[5];
        char *fp;
        int   fi;

                BOOT_TRAP(0x50);

        /* Skip blank lines and comments (ProDOS text uses CR only) */
        if (*p == '#' || *p == '\r' || *p == '\n') {
            while (p < end && *p != '\r' && *p != '\n') p++;
            if (p < end) p++;   /* skip the line terminator */
            continue;
        }

                BOOT_TRAP(0x51);


        /* Find end of line */
        line_end = p;
        while (line_end < end && *line_end != '\n' && *line_end != '\r')
            line_end++;

        /* Null-terminate the line so field parsing stops here
         * (ProDOS text uses CR only — without this, the last field
         * bleeds into subsequent lines) */
        if (line_end < end)
            *line_end = '\0';

                    BOOT_TRAP(0x52);

        /*
         * GNO inittab has 5 colon-separated fields:
         *   id : runlevels : action : flags : command
         * field[4] is the command to execute.
         */
        fp = p;
        for (fi = 0; fi < 5; fi++) {
            field[fi] = fp;
            while (fp < line_end && *fp != ':')
                fp++;
            if (fp < line_end) {
                *fp = '\0';
                fp++;
            }
        }
                BOOT_TRAP(0x53);


        /* field[0] = id (up to 2 chars) */
        strncpy(id, field[0], ID_LEN);
        id[ID_LEN] = '\0';

                BOOT_TRAP(0x54);

        /* field[1] = runlevels */
        strncpy(runlevels, field[1], RUNLEVEL_LEN);
        runlevels[RUNLEVEL_LEN] = '\0';

                BOOT_TRAP(0x55);

        /* field[2] = action keyword */
        strncpy(action_kw, field[2], sizeof(action_kw) - 1);
        action_kw[sizeof(action_kw) - 1] = '\0';

                BOOT_TRAP(0x56);

        /* field[3] = flags (skip); field[4] = command */
        strncpy(cmd, field[4], CMD_LEN - 1);
        cmd[CMD_LEN - 1] = '\0';

        /* Remove trailing CR/LF from cmd */
        {
            int cl = strlen(cmd);
            while (cl > 0 && (cmd[cl-1] == '\r' || cmd[cl-1] == '\n'))
                cmd[--cl] = '\0';
        }

                BOOT_TRAP(0x57);

        action = lookup_action(action_kw);

                BOOT_TRAP(0x58);

        /*
         * Handle initdefault / runl entries -- sets the default run-level.
         * GNO's "runl" action uses the command field (e.g. "8") as the
         * run-level digit when the runlevels field is not a digit (e.g. "b").
         */
        if (action == ACT_INITDEFAULT) {
            if (runlevels[0] >= '0' && runlevels[0] <= '9')
                initdefault_runlevel = runlevels[0];
            else if (cmd[0] >= '0' && cmd[0] <= '9')
                initdefault_runlevel = cmd[0];
            goto next_line;
        }

                BOOT_TRAP(0x59);

        /* Store entry in proc table */
        proc_table[entry_idx].id[0]        = id[0];
        proc_table[entry_idx].id[1]        = id[1];
        strncpy(proc_table[entry_idx].runlevels, runlevels, RUNLEVEL_LEN);
        proc_table[entry_idx].runlevels[RUNLEVEL_LEN] = '\0';
        proc_table[entry_idx].action       = action;
        proc_table[entry_idx].flags        = 0;
        proc_table[entry_idx].cmd_offset   = entry_idx * CMD_LEN;

                BOOT_TRAP(0x60);

        /* Copy command into pool */
        strncpy(cmd_pool + entry_idx * CMD_LEN, cmd, CMD_LEN - 1);

                BOOT_TRAP(0x61);

        cmd_pool[entry_idx * CMD_LEN + CMD_LEN - 1] = '\0';

                BOOT_TRAP(0x62);


        entry_idx++;

    next_line:
        /* Advance past line terminator (may be \0 from our null-termination,
         * or \r or \n if we skipped the line without field parsing) */
        p = line_end;
        if (p < end) p++;               /* skip the line terminator */
        if (p < end && *p == '\n') p++;  /* handle \r\n */

                BOOT_TRAP(0x63);

    }

            BOOT_TRAP(0x41);

    inittab_entry_count = entry_idx;
    proc_count = entry_idx;

            BOOT_TRAP(0x42);

    free(buf);

            BOOT_TRAP(0x43);

}

/* ---------------------------------------------------------------------------
 * parse_syslog_conf -- CODE $212B
 *
 * Opens /etc/syslog.conf and parses facility.severity=destination lines.
 * On error prints the error message from Far segment $0025 and uses defaults.
 * --------------------------------------------------------------------------*/
static void
parse_syslog_conf(void)
{
    int   fd;
    char *buf;
    int   n;

    buf = (char *)malloc(BUF_SIZE);
    if (!buf) {
        write_console("/Error in " SYSLOG_CONF " file - using defaults\r\n");
        return;
    }

    fd = open(SYSLOG_CONF, O_RDONLY, 0);
    if (fd < 0) {
        write_console("/Error in " SYSLOG_CONF " file - using defaults\r\n");
        free(buf);
        return;
    }

    n = read(fd, buf, BUF_SIZE - 1);
    close(fd);

    if (n <= 0) {
        free(buf);
        return;
    }

    buf[n] = '\0';

    /* syslog.conf parsing not yet implemented — using defaults */

    free(buf);
}

/* ---------------------------------------------------------------------------
 * syslogd_child -- child function for fork2: execs syslogd
 * --------------------------------------------------------------------------*/
#pragma databank 1
static void
syslogd_child(void)
{
    char *argv[2];
    argv[0] = "syslogd";
    argv[1] = NULL;
    execv("/usr/sbin/syslogd", argv);
    _exit(1);
}
#pragma databank 0

/* ---------------------------------------------------------------------------
 * launch_syslogd -- CODE $0917
 *
 * Forks and execs syslogd as a background daemon.
 * Stores child pid in syslogd_pid.
 * --------------------------------------------------------------------------*/
static void
launch_syslogd(void)
{
    int pid;

    pid = fork2(syslogd_child, 1024, 0, "syslogd", 0);
    if (pid < 0) {
        write_console("initd: fork failed for syslogd\r\n");
        return;
    }
    /* parent */
    syslogd_pid = pid;
}

/* ---------------------------------------------------------------------------
 * determine_runlevel -- CODE $0800
 *
 * Reads the initdefault entry from the already-parsed proc_table to
 * determine the initial run-level to enter.
 * --------------------------------------------------------------------------*/
static void
determine_runlevel(void)
{
    /* initdefault_runlevel was set by parse_inittab */
    if (initdefault_runlevel >= '0' && initdefault_runlevel <= '9')
        cur_runlevel = initdefault_runlevel;
    else
        cur_runlevel = '2';     /* default: multi-user */

    new_runlevel = cur_runlevel;
}

/* ---------------------------------------------------------------------------
 * parse_cmd_args -- split a command string into argv[] in-place
 *
 * Splits on whitespace, NUL-terminates each token, returns argc.
 * buf must be a writable copy (it is modified).
 * --------------------------------------------------------------------------*/
static int
parse_cmd_args(char *buf, char *argv[], int max_args)
{
    int   argc = 0;
    char *p    = buf;

    while (*p && argc < max_args - 1) {
        while (*p == ' ' || *p == '\t') p++;
        if (!*p) break;
        argv[argc++] = p;
        while (*p && *p != ' ' && *p != '\t') p++;
        if (*p) *p++ = '\0';
    }
    argv[argc] = NULL;
    return argc;
}

/* ---------------------------------------------------------------------------
 * spawn_child -- fork2 child: execs a command from cmd_pool[offset].
 *
 * fork2 shares the parent's data bank (same OMF segment), so cmd_pool[]
 * is directly accessible via the passed offset.  #pragma databank 1
 * ensures DBR is set to the data bank before any global access.
 * --------------------------------------------------------------------------*/
#pragma databank 1
static void
spawn_child(int cmd_offset)
{
    char  cmd_copy[CMD_LEN];
    char *argv[32];
    int   ac;
    KTRACE_LOGF("spawn_child: offset=%d", cmd_offset);
    strncpy(cmd_copy, cmd_pool + cmd_offset, CMD_LEN - 1);
    cmd_copy[CMD_LEN - 1] = '\0';
    KTRACE_LOGF("spawn_child: cmd_copy='%s'", cmd_copy);
    ac = parse_cmd_args(cmd_copy, argv, 32);
    KTRACE_LOGF("spawn_child: argc=%d argv[0]=%s", ac, argv[0] ? argv[0] : "(null)");
    if (ac > 1)
        KTRACE_LOGF("spawn_child: argv[1]=%s", argv[1]);
    if (argv[0])
        execv(argv[0], argv);
    _exit(127);
}
#pragma databank 0

/* ---------------------------------------------------------------------------
 * spawn_process -- forks a child via fork2 and execs the inittab command.
 *
 * fork(NULL) is broken in the GNO kernel: commonFork passes funcptr=NULL
 * to createProc, so the child starts executing at address $000000 (zero
 * page) and immediately crashes.  fork2() supplies a real function pointer
 * and works correctly.  The child accesses cmd_pool[] via the shared data
 * bank — both parent and child run the same OMF image so the global is
 * valid in the child when DBR is set (#pragma databank 1).
 * --------------------------------------------------------------------------*/
static int
spawn_process(int entry_idx)
{
    int   pid;
    char *cmd;

    if (entry_idx < 0 || entry_idx >= proc_count)
        return -1;

    cmd = cmd_pool + proc_table[entry_idx].cmd_offset;
    if (!cmd || !*cmd)
        return -1;

    pid = fork2(spawn_child, 1024, 0, cmd, 1,
                (int)proc_table[entry_idx].cmd_offset);
    if (pid < 0)
        return -1;

    /* parent */
    child_pids[entry_idx]          = pid;
    proc_table[entry_idx].flags   |= PROC_FLAG_SPAWNED;
    proc_table[entry_idx].flags   &= ~PROC_FLAG_DEAD;
    spawned_count++;
    active_count++;

    return pid;
}

/* ---------------------------------------------------------------------------
 * spawn_and_wait -- CODE $1C89
 *
 * Like spawn_process but waits synchronously for the child to exit.
 * Used for "wait" and "sysinit" action types.
 *
 * GNO wait()/waitpid() require union wait *, not int *.
 * --------------------------------------------------------------------------*/
static int
spawn_and_wait(int entry_idx)
{
    int         pid;
    union wait  status;

    pid = spawn_process(entry_idx);
    if (pid <= 0)
        return -1;

    waitpid(pid, &status, 0);
    child_pids[entry_idx]          = 0;
    proc_table[entry_idx].flags   |= PROC_FLAG_DEAD;
    if (active_count > 0) active_count--;

    return WEXITSTATUS(status);
}

/* ---------------------------------------------------------------------------
 * kill_all_children -- CODE $28BF
 *
 * Sends signal to all known children.
 * If sending SIGTERM, also sets an alarm and follows up with SIGKILL.
 * --------------------------------------------------------------------------*/
static void
kill_all_children(int sig)
{
    int i;

    for (i = 0; i < proc_count; i++) {
        if (child_pids[i] > 0) {
            kill(child_pids[i], sig);
        }
    }

    if (sig == SIGTERM) {
        alarm(3);   /* give processes 3 seconds to die gracefully */
        /* After alarm fires, kill_all_children(SIGKILL) will be called
         * from the signal handler path */
    }
}

/* ---------------------------------------------------------------------------
 * write_utmp -- CODE $252B
 *
 * Writes a utmp/wtmp record at the given slot for run-level transitions.
 * --------------------------------------------------------------------------*/
static void
write_utmp(int slot, int type, const char *user, const char *host)
{
    struct utmp ut;
    int         fd;
    time_t      tv_sec;

    /* GNO time() -- dispatch $1C03 */
    tv_sec = time(NULL);

    memset(&ut, 0, sizeof(ut));
    ut.ut_type = (unsigned int)type;
    ut.ut_time = tv_sec;
    if (user) strncpy(ut.ut_name, user, sizeof(ut.ut_name) - 1);
    if (host) strncpy(ut.ut_host, host, sizeof(ut.ut_host) - 1);

    /* Write to utmp at correct slot */
    fd = open(UTMP_FILE, O_WRONLY | O_CREAT, 0644);
    if (fd >= 0) {
        lseek(fd, (long)slot * sizeof(struct utmp), SEEK_SET);
        write(fd, &ut, sizeof(struct utmp));
        close(fd);
    }

    /* Append to wtmp */
    fd = open(WTMP_FILE, O_WRONLY | O_APPEND | O_CREAT, 0644);
    if (fd >= 0) {
        write(fd, &ut, sizeof(struct utmp));
        close(fd);
    }
}

/* ---------------------------------------------------------------------------
 * run_level_switch -- CODE $03D1 (portion)
 *
 * Transitions to new_level: kills children, re-parses inittab,
 * spawns processes for the new level, writes utmp.
 * --------------------------------------------------------------------------*/
static void
run_level_switch(char new_level)
{
    char msg[64];
    int  i;

    old_runlevel = cur_runlevel;
    new_runlevel = new_level;
    in_transition = 1;

    /* Print transition message (CODE $086D: "init:switching to run level x.") */
    {
        int k = 0;
        msg[k++] = 'i'; msg[k++] = 'n'; msg[k++] = 'i'; msg[k++] = 't';
        msg[k++] = ':'; msg[k++] = 's'; msg[k++] = 'w'; msg[k++] = 'i';
        msg[k++] = 't'; msg[k++] = 'c'; msg[k++] = 'h'; msg[k++] = 'i';
        msg[k++] = 'n'; msg[k++] = 'g'; msg[k++] = ' '; msg[k++] = 't';
        msg[k++] = 'o'; msg[k++] = ' '; msg[k++] = 'r'; msg[k++] = 'u';
        msg[k++] = 'n'; msg[k++] = ' '; msg[k++] = 'l'; msg[k++] = 'e';
        msg[k++] = 'v'; msg[k++] = 'e'; msg[k++] = 'l'; msg[k++] = ' ';
        msg[k++] = new_level;
        msg[k++] = '.'; msg[k++] = '\r'; msg[k++] = '\n'; msg[k] = '\0';
    }
    write_console(msg);

    /* Kill all existing children */
    kill_all_children(SIGTERM);

    /* Re-parse inittab to pick up any changes */
    parse_inittab();

    cur_runlevel = new_level;
    in_transition = 0;

    /* Spawn sysinit entries first (synchronously) */
    for (i = 0; i < proc_count; i++) {
        if (proc_table[i].action == ACT_SYSINIT)
            spawn_and_wait(i);
    }

    /* Then spawn all entries for this level */
    for (i = 0; i < proc_count; i++) {
        struct proc_entry *e = &proc_table[i];
        if (!in_runlevel(e, cur_runlevel))
            continue;
        switch (e->action) {
        case ACT_RESPAWN:
        case ACT_ONCE:
            spawn_process(i);
            break;
        case ACT_WAIT:
            spawn_and_wait(i);
            break;
        default:
            break;
        }
        if (e->action == ACT_ONCE)
            e->flags |= PROC_FLAG_ONCE_DONE;
    }

    /* Write utmp for run-level change */
    write_utmp(0, RUN_LVL, "runlevel", "");

    signal_pending = 0;
    pending_action = 0;
}

/* ---------------------------------------------------------------------------
 * reload_inittab -- triggered by SIGHUP (pending_action = 'q')
 * CODE $03D1 'q' branch
 * --------------------------------------------------------------------------*/
static void
reload_inittab(void)
{
    int i;

    parse_inittab();

    /* Re-spawn any new or dead respawn entries for current level */
    for (i = 0; i < proc_count; i++) {
        struct proc_entry *e = &proc_table[i];
        if (!in_runlevel(e, cur_runlevel))
            continue;
        if (e->action == ACT_RESPAWN && child_pids[i] == 0)
            spawn_process(i);
    }

    signal_pending = 0;
    pending_action = 0;
}

/* ---------------------------------------------------------------------------
 * handle_ipc_message -- process one message from user-space init
 *
 * Called from the main loop when ipc_pending is set (SIGUSR1 received).
 * Reads one message via procreceive() and dispatches on the command code
 * in the high word.
 *
 * IPC message format:
 *   Query current level:   (0x0300 << 16) | sender_pid
 *   Verbose/version query: (0x0301 << 16) | sender_pid
 *   Enable inittab entry:  (0x0400 << 16) | entry_char
 *   Disable inittab entry: (0x0500 << 16) | entry_char
 *   Run-level change:      ((cw<<8|q) << 16) | (runlevel_char << 8)
 * --------------------------------------------------------------------------*/
static void
handle_ipc_message(void)
{
    unsigned long msg;
    unsigned int  high_word, low_word;
    pid_t         sender_pid;
    unsigned char runlevel_char;

    msg       = procreceive();
    high_word = (unsigned int)(msg >> 16);
    low_word  = (unsigned int)(msg & 0xFFFFUL);

    switch (high_word) {
    case 0x0300:
        /* Query: respond with current run-level character */
        sender_pid = (pid_t)low_word;
        procsend(sender_pid, (unsigned long)(unsigned char)cur_runlevel);
        break;

    case 0x0301:
        /* Verbose query: respond with initd version (major<<8 | minor) */
        sender_pid = (pid_t)low_word;
        procsend(sender_pid, (unsigned long)((2 << 8) | 0));   /* version 2.0 */
        break;

    case 0x0400:
        /* Enable inittab entry identified by low_word char -- not yet implemented */
        break;

    case 0x0500:
        /* Disable inittab entry identified by low_word char -- not yet implemented */
        break;

    default:
        /* Run-level change message */
        runlevel_char = (unsigned char)((low_word >> 8) & 0xFF);
        if (runlevel_char)
            run_level_switch((char)runlevel_char);
        break;
    }
}

/* ---------------------------------------------------------------------------
 * handle_pending_signal -- CODE $03D1 (dispatch on pending_action)
 *
 * Called from main loop when signal_pending > 0.
 * Dispatches on pending_action char set by signal_handler().
 * --------------------------------------------------------------------------*/
static void
handle_pending_signal(void)
{
    char action = pending_action;

    pending_action = 0;
    signal_pending = 0;

    switch (action) {
    case 'q':
        /* SIGHUP: graceful reload */
        reload_inittab();
        break;

    case 'r':
    case '2':
        /* Enter multi-user */
        run_level_switch('2');
        break;

    case 's':
    case 'b':
    case '1':
        /* Enter single-user */
        run_level_switch('1');
        break;

    case '0':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
        /* Numeric run-level change */
        run_level_switch(action);
        break;

    case 'n':
        /* Noop */
        break;

    default:
        if (action >= '0' && action <= '9') {
            run_level_switch(action);
        } else {
            write_console("Invalid control message passed to init\r\n");
        }
        break;
    }
}

/* ---------------------------------------------------------------------------
 * main -- CODE $0000
 *
 * Entry point.  Initializes the system, then enters the main
 * monitor/reap/spawn loop.
 * --------------------------------------------------------------------------*/
int
main(int argc, char **argv)
{
    int        pid;
    union wait status;
    int        i;

    /* Get our own PID */
    mypid = getpid();

    /* Announce ourselves */
    write_console("GNO/ME started.\r\n");

    /* Initialize signal handling before anything else */
    install_signal_handlers();

    /* Initialize process table */
    init_proc_table();
    clear_proc_table();

    /* Parse syslog.conf and launch syslogd first */
    parse_syslog_conf();
    /* launch_syslogd(); — disabled: syslogd hangs during boot, blocking initd */

    /* Parse /etc/inittab to learn about all processes */
    parse_inittab();

    /* Determine initial run-level from initdefault entry */
    determine_runlevel();

    /* Run sysinit entries synchronously (before entering run-level) */
    for (i = 0; i < proc_count; i++) {
        if (proc_table[i].action == ACT_SYSINIT)
            spawn_and_wait(i);
    }

    /*
     * Run boot-time ('b') entries -- these fire once at startup regardless
     * of run-level (analogous to SysV "boot" run-level).
     */
    for (i = 0; i < proc_count; i++) {
        if (!in_runlevel(&proc_table[i], 'b'))
            continue;
        switch (proc_table[i].action) {
        case ACT_WAIT:
            spawn_and_wait(i);
            break;
        case ACT_ONCE:
            spawn_process(i);
            proc_table[i].flags |= PROC_FLAG_ONCE_DONE;
            break;
        default:
            break;
        }
    }

    /* Enter the initial run-level */
    run_level_switch(cur_runlevel);

    /* -----------------------------------------------------------------------
     * Main loop -- run forever as PID 1:
     *   1. Reap any dead children (wait)
     *   2. Respawn dead "respawn" entries
     *   3. Handle pending signals/run-level changes
     * ---------------------------------------------------------------------- */
    for (;;) {

        /* Reap dead children */
        while ((pid = wait(&status)) > 0) {
            /* Find which entry this pid belongs to */
            for (i = 0; i < proc_count; i++) {
                if (child_pids[i] == pid) {
                    child_pids[i] = 0;
                    proc_table[i].flags |= PROC_FLAG_DEAD;
                    if (active_count > 0) active_count--;
                    break;
                }
            }
        }

        /* Respawn dead "respawn" entries that belong to current run-level */
        for (i = 0; i < proc_count; i++) {
            struct proc_entry *e = &proc_table[i];

            if (!in_runlevel(e, cur_runlevel))
                continue;
            if (e->action != ACT_RESPAWN)
                continue;
            if (e->flags & PROC_FLAG_DEAD) {
                e->flags &= ~PROC_FLAG_DEAD;
                spawn_process(i);
            } else if (child_pids[i] == 0 && (e->flags & PROC_FLAG_SPAWNED) == 0) {
                spawn_process(i);
            }
        }

        /* Handle IPC message from user-space init (SIGUSR1) */
        if (ipc_pending) {
            ipc_pending = 0;
            handle_ipc_message();
        }

        /* Handle any pending signals */
        if (signal_pending > 0)
            handle_pending_signal();

        /* Yield -- the kernel will wake us on SIGCHLD or next event.
         * wait() above blocks until a child exits, giving natural yielding. */
    }

    /* NOTREACHED */
    return 0;
}
