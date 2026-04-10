#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ktrace.h>

#define MAXHOSTNAMELEN 256

int
main(argc, argv)
int argc;
char **argv;
{
    char buf[MAXHOSTNAMELEN];
    int sflag;
    int c;
    char *p;

    KTRACE_LOGF("hostname: argc=%d", argc);
    if (argc > 0)
        KTRACE_LOGF("hostname: argv[0]=%s", argv[0]);
    if (argc > 1)
        KTRACE_LOGF("hostname: argv[1]=%s", argv[1]);

    sflag = 0;

    while ((c = getopt(argc, argv, "s")) != EOF) {
        switch (c) {
        case 's':
            sflag = 1;
            break;
        default:
            fprintf(stderr, "usage: hostname [-s] [name]\n");
            exit(1);
        }
    }
    argc -= optind;
    argv += optind;

    KTRACE_LOGF("hostname: after getopt argc=%d", argc);

    if (argc > 0) {
        KTRACE_LOGF("hostname: sethostname(%s)", argv[0]);
        if (sethostname(argv[0], strlen(argv[0])) < 0) {
            perror("sethostname");
            exit(1);
        }
        return 0;
    }

    KTRACE_LOG("hostname: calling gethostname (no args path)");
    if (gethostname(buf, (int)sizeof(buf)) < 0) {
        perror("gethostname");
        exit(1);
    }
    buf[sizeof(buf) - 1] = '\0';

    if (sflag) {
        p = strchr(buf, '.');
        if (p != NULL)
            *p = '\0';
    }

    puts(buf);
    return 0;
}
