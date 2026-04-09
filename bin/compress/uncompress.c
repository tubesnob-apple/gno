/*
 * uncompress.c -- stub that execs compress -d
 *
 * On GNO/ME the uncompress binary is a tiny (~1.8 KB) stub.
 * It reconstructs argv with "-d" prepended and hands off to
 * compress(1) via execvp.
 *
 * Ported to GNO/ME (Apple IIgs, ORCA/C 2.2.2) by the GNO project.
 */

#ifdef __GNO__
#include <types.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int
main(argc, argv)
    int   argc;
    char *argv[];
{
    char **new_argv;
    int    i;

    /*
     * Build new_argv = { "compress", "-d", argv[1], argv[2], ..., NULL }
     * We need argc + 2 slots: one for "compress", one for "-d",
     * argc-1 for original argv[1..argc-1], one for NULL.
     */
    new_argv = (char **)malloc((unsigned int)(argc + 2) * sizeof(char *));
    if (new_argv == NULL) {
        fprintf(stderr, "uncompress: out of memory\n");
        exit(1);
    }

    new_argv[0] = "compress";
    new_argv[1] = "-d";
    for (i = 1; i < argc; i++)
        new_argv[i + 1] = argv[i];
    new_argv[argc + 1] = NULL;

    execvp("compress", new_argv);

    /* execvp only returns on error */
    perror("uncompress: exec compress");
    exit(1);
    return 1;   /* suppress ORCA/C warning */
}
