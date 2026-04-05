/*
 * uptimed -- uptime daemon for GNO/ME
 *
 * Records the time at startup and serves queries via GNO port IPC:
 *   ~uptime~daemon1  -- receive response-port-id, reply with boot_time (time_t as long)
 *   ~uptime~daemon2  -- receive response-port-id, reply with 3 load-avg longs (scaled *100)
 *
 * Since GNO has no kernel load-average tracking, daemon2 always reports 0.
 *
 * Add to /etc/inittab to start at boot:
 *   ud:b:once::/usr/sbin/uptimed
 *
 * GNO/ME -- written for GoldenGate cross-build
 */

#pragma noroot

#include <stdio.h>
#include <time.h>
#include <sys/ports.h>
#include <stdlib.h>
#include <unistd.h>
#ifdef __GNO__
#include <sys/errno.h>
#endif

#define DAEMON1_PORT  "~uptime~daemon1"
#define DAEMON2_PORT  "~uptime~daemon2"
#define QUEUE_DEPTH   10

int
main(int argc, char **argv)
{
    time_t boot_time;
    int port1, port2;
    int resp;

    time(&boot_time);

    port1 = pcreate(QUEUE_DEPTH);
    if (port1 < 0) {
        fprintf(stderr, "uptimed: pcreate failed\n");
        exit(1);
    }
    if (pbind(port1, DAEMON1_PORT) < 0) {
        fprintf(stderr, "uptimed: pbind(%s) failed\n", DAEMON1_PORT);
        exit(1);
    }

    port2 = pcreate(QUEUE_DEPTH);
    if (port2 < 0) {
        fprintf(stderr, "uptimed: pcreate failed\n");
        exit(1);
    }
    if (pbind(port2, DAEMON2_PORT) < 0) {
        fprintf(stderr, "uptimed: pbind(%s) failed\n", DAEMON2_PORT);
        exit(1);
    }

    /* Service requests from both ports forever */
    for (;;) {
        /* Drain daemon1: boot_time queries */
        while (pgetcount(port1) > 0) {
            resp = (int)preceive(port1);
            if (resp >= 0)
                psend(resp, (long)boot_time);
        }

        /* Drain daemon2: load-average queries (always 0) */
        while (pgetcount(port2) > 0) {
            resp = (int)preceive(port2);
            if (resp >= 0) {
                psend(resp, 0L);
                psend(resp, 0L);
                psend(resp, 0L);
            }
        }

        sleep(1);
    }

    /* NOTREACHED */
    return 0;
}
