/*
 * uptime -- display system uptime, user count, and load averages.
 *
 * Contacts uptimed via GNO port IPC:
 *   ~uptime~daemon1  -- send response-port-id, receive boot_time (time_t)
 *   ~uptime~daemon2  -- send response-port-id, receive 3 load averages (long, scaled *100)
 *
 * Falls back gracefully if uptimed is not running.
 *
 * GNO/ME -- written for GoldenGate cross-build
 */

#pragma noroot

#include <stdio.h>
#include <time.h>
#include <utmp.h>
#include <sys/ports.h>
#include <stdlib.h>
#include <string.h>
#ifdef __GNO__
#include <sys/errno.h>
#endif

#define DAEMON1_PORT  "~uptime~daemon1"
#define DAEMON2_PORT  "~uptime~daemon2"

static int
count_users(void)
{
    FILE *fp;
    struct utmp ut;
    int n = 0;

    fp = fopen(_PATH_UTMP, "r");
    if (fp == NULL)
        return 0;
    while (fread(&ut, sizeof(ut), 1, fp) == 1) {
        if (ut.ut_name[0] != '\0' &&
            (ut.ut_type == USER_PROCESS))
            n++;
    }
    fclose(fp);
    return n;
}

/*
 * Send our response-port-id to a daemon port and collect nresp replies.
 * Returns 0 on success, -1 if daemon is not running.
 */
static int
query_daemon(const char *portname, int nresp, long *buf)
{
    int daemon_port, resp_port, i;

    daemon_port = pgetport(portname);
    if (daemon_port < 0)
        return -1;

    resp_port = pcreate(nresp);
    if (resp_port < 0)
        return -1;

    if (psend(daemon_port, (long)resp_port) < 0) {
        pdelete(resp_port, NULL);
        return -1;
    }

    for (i = 0; i < nresp; i++)
        buf[i] = preceive(resp_port);

    pdelete(resp_port, NULL);
    return 0;
}

int
main(int argc, char **argv)
{
    time_t now, boot_time;
    struct tm *tp;
    long elapsed;
    int up_days, up_hours, up_mins;
    int users;
    long avg_buf[3];
    double avg1, avg5, avg15;
    int hour;
    char *ampm;
    long scratch[1];

    time(&now);
    tp = localtime(&now);

    /* Current time with am/pm */
    hour = tp->tm_hour;
    if (hour == 0) {
        hour = 12; ampm = "AM";
    } else if (hour < 12) {
        ampm = "AM";
    } else if (hour == 12) {
        ampm = "PM";
    } else {
        hour -= 12; ampm = "PM";
    }

    /* Get boot time from daemon1 (fall back to now = 0 uptime) */
    if (query_daemon(DAEMON1_PORT, 1, scratch) == 0)
        boot_time = (time_t)scratch[0];
    else
        boot_time = now;

    elapsed = (long)(now - boot_time);
    if (elapsed < 0L)
        elapsed = 0L;
    up_days  = (int)(elapsed / 86400L);
    elapsed -= (long)up_days * 86400L;
    up_hours = (int)(elapsed / 3600L);
    up_mins  = (int)((elapsed % 3600L) / 60L);

    users = count_users();

    /* Get load averages from daemon2 (scaled by 100); default 0.00 */
    if (query_daemon(DAEMON2_PORT, 3, avg_buf) == 0) {
        avg1  = avg_buf[0] / 100.0;
        avg5  = avg_buf[1] / 100.0;
        avg15 = avg_buf[2] / 100.0;
    } else {
        avg1 = avg5 = avg15 = 0.0;
    }

    printf("  %d:%02d%s  up ", hour, tp->tm_min, ampm);

    if (up_days == 1)
        printf("%d day,  ", up_days);
    else if (up_days > 1)
        printf("%d days,  ", up_days);

    printf("%02d:%02d,  ", up_hours, up_mins);

    if (users == 1)
        printf("%d user,  ", users);
    else
        printf("%d users,  ", users);

    printf("load average:  %.2f, %.2f, %.2f\n", avg1, avg5, avg15);

    return 0;
}
