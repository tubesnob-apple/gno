#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

int
main(argc, argv)
int argc;
char **argv;
{
    char *tmpl;
    char buf[256];
    int dflag;
    int c;
    int fd;

    dflag = 0;

    while ((c = getopt(argc, argv, "d")) != EOF) {
        switch (c) {
        case 'd':
            dflag = 1;
            break;
        default:
            fprintf(stderr, "usage: mktmp [-d] [template]\n");
            exit(1);
        }
    }
    argc -= optind;
    argv += optind;

    if (argc > 0) {
        tmpl = argv[0];
    } else {
        strncpy(buf, "/tmp/tmpXXXXXXXX", sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        tmpl = buf;
    }

    if (mktemp(tmpl) == NULL || tmpl[0] == '\0') {
        perror("mktemp");
        exit(1);
    }

    if (dflag) {
        if (mkdir(tmpl) < 0) {
            perror(tmpl);
            exit(1);
        }
    } else {
        fd = open(tmpl, O_CREAT | O_EXCL | O_RDWR, 0600);
        if (fd < 0) {
            perror(tmpl);
            exit(1);
        }
        close(fd);
    }

    puts(tmpl);
    return 0;
}
