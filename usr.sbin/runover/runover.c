#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

int
main(argc, argv)
int argc;
char **argv;
{
    int fd;

    if (argc < 3) {
        fprintf(stderr, "usage: runover ttydev program [args...]\n");
        exit(1);
    }

    fd = open(argv[1], O_RDWR);
    if (fd < 0) {
        perror("runover");
        exit(1);
    }

    dup2(fd, 0);
    dup2(fd, 1);
    dup2(fd, 2);

    if (fd > 2)
        close(fd);

    execvp(argv[2], &argv[2]);
    perror("runover");
    exit(1);
}
