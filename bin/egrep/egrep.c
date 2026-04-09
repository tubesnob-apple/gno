/*
 * egrep -- extended regex grep using POSIX regcomp/regexec
 *
 * Usage: egrep [-cilnsvx] [-e pattern] [-f file] [pattern] [file ...]
 *
 * Status returns:
 *   0 - match found
 *   1 - no match
 *   2 - error
 */

#ifndef lint
static const char sccsid[] = "@(#)egrep.c  GNO/ME 2.0.6";
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <regex.h>

#ifdef __ORCAC__
/* #pragma memorymodel 1 — removed: ABI mismatch with GNO libc */
#endif

/* Maximum number of -e patterns */
#define MAX_PATTERNS    64

/* Line buffer: 4 * BUFSIZ to handle long lines; static to avoid stack overflow */
#define LINE_BUF_SIZE   (BUFSIZ * 4)

/* Compiled patterns */
static regex_t  patterns[MAX_PATTERNS];
static int      npatterns = 0;

/* Flags */
static int  cflag = 0;  /* count only */
static int  iflag = 0;  /* case insensitive */
static int  lflag = 0;  /* filenames only */
static int  nflag = 0;  /* line numbers */
static int  sflag = 0;  /* silent */
static int  vflag = 0;  /* invert match */
static int  xflag = 0;  /* whole line */

static int  nfiles = 0; /* number of file arguments */
static int  found  = 0; /* any match across all files */
static int  status = 1; /* exit status: 1 = no match */

/* Static line buffer */
static char linebuf[LINE_BUF_SIZE];

static void
usage()
{
    fprintf(stderr,
        "usage: egrep [-cilnsvx] [-e pattern] [-f file] [pattern] [file ...]\n");
    exit(2);
}

/*
 * Compile and add one pattern string.
 * Wraps in ^(...)$ if -x was given.
 */
static void
add_pattern(pat)
    char *pat;
{
    char    wrapped[LINE_BUF_SIZE + 8];
    char   *actual;
    int     cflags;
    int     err;
    char    errbuf[256];

    if (npatterns >= MAX_PATTERNS) {
        fprintf(stderr, "egrep: too many -e patterns (max %d)\n", MAX_PATTERNS);
        exit(2);
    }

    if (xflag) {
        /* wrap pattern as ^(pat)$ for whole-line match */
        if ((int)strlen(pat) + 6 > (int)sizeof(wrapped) - 1) {
            fprintf(stderr, "egrep: pattern too long\n");
            exit(2);
        }
        strcpy(wrapped, "^(");
        strcat(wrapped, pat);
        strcat(wrapped, ")$");
        actual = wrapped;
    } else {
        actual = pat;
    }

    cflags = REG_EXTENDED;
    if (iflag)
        cflags |= REG_ICASE;
    cflags |= REG_NOSUB;

    err = regcomp(&patterns[npatterns], actual, cflags);
    if (err != 0) {
        regerror(err, &patterns[npatterns], errbuf, sizeof(errbuf));
        fprintf(stderr, "egrep: %s\n", errbuf);
        exit(2);
    }
    npatterns++;
}

/*
 * Read pattern strings from a file, one per line.
 */
static void
read_pattern_file(fname)
    char *fname;
{
    FILE   *fp;
    char    buf[BUFSIZ];
    char   *p;
    int     len;

    fp = fopen(fname, "r");
    if (fp == NULL) {
        perror(fname);
        exit(2);
    }
    while (fgets(buf, (int)sizeof(buf), fp) != NULL) {
        len = (int)strlen(buf);
        if (len > 0 && buf[len - 1] == '\n')
            buf[len - 1] = '\0';
        /* skip empty lines */
        p = buf;
        if (*p == '\0')
            continue;
        add_pattern(p);
    }
    fclose(fp);
}

/*
 * Test whether the current line matches any compiled pattern.
 * Returns 1 if matched, 0 if not.
 */
static int
line_matches(line)
    char *line;
{
    int i;
    int r;

    for (i = 0; i < npatterns; i++) {
        r = regexec(&patterns[i], line, (size_t)0, (regmatch_t *)NULL, 0);
        if (r == 0)
            return 1;
    }
    return 0;
}

/*
 * Process one open stream.
 * fname: display name (NULL for stdin display as "(standard input)").
 * show_fname: prefix matching lines with "fname:" when 1.
 */
static void
process(fp, fname, show_fname)
    FILE       *fp;
    char       *fname;
    int         show_fname;
{
    long    lnum;
    long    count;
    int     matched;
    int     printed_fname;

    lnum = 0L;
    count = 0L;
    printed_fname = 0;

    while (fgets(linebuf, (int)sizeof(linebuf), fp) != NULL) {
        int len;

        lnum++;

        /* strip trailing newline for matching */
        len = (int)strlen(linebuf);
        if (len > 0 && linebuf[len - 1] == '\n')
            linebuf[len - 1] = '\0';

        matched = line_matches(linebuf);

        /* invert if -v */
        if (vflag)
            matched = !matched;

        if (!matched)
            continue;

        /* we have a match */
        found = 1;
        status = 0;

        if (sflag)
            continue;

        if (cflag) {
            count++;
            continue;
        }

        if (lflag) {
            if (!printed_fname) {
                printf("%s\n", fname ? fname : "(standard input)");
                fflush(stdout);
                printed_fname = 1;
                /* skip to next file */
                return;
            }
            continue;
        }

        /* normal output */
        if (show_fname)
            printf("%s:", fname ? fname : "(standard input)");
        if (nflag)
            printf("%ld:", lnum);
        printf("%s\n", linebuf);
        fflush(stdout);
    }

    if (cflag) {
        if (show_fname)
            printf("%s:", fname ? fname : "(standard input)");
        printf("%ld\n", count);
        fflush(stdout);
    }
}

int
main(argc, argv)
    int   argc;
    char *argv[];
{
    extern char *optarg;
    extern int   optind;

    int     ch;
    int     i;
    FILE   *fp;

    while ((ch = getopt(argc, argv, "cilnsvxe:f:")) != EOF) {
        switch ((char)ch) {
        case 'c':
            cflag = 1;
            break;
        case 'i':
            iflag = 1;
            break;
        case 'l':
            lflag = 1;
            break;
        case 'n':
            nflag = 1;
            break;
        case 's':
            sflag = 1;
            break;
        case 'v':
            vflag = 1;
            break;
        case 'x':
            xflag = 1;
            break;
        case 'e':
            add_pattern(optarg);
            break;
        case 'f':
            read_pattern_file(optarg);
            break;
        case '?':
        default:
            usage();
            /* NOTREACHED */
        }
    }
    argc -= optind;
    argv += optind;

    /* If no -e patterns given, first non-option arg is the pattern */
    if (npatterns == 0) {
        if (argc == 0) {
            usage();
            /* NOTREACHED */
        }
        add_pattern(*argv);
        argc--;
        argv++;
    }

    nfiles = argc;

    if (nfiles == 0) {
        /* read stdin */
        process(stdin, NULL, 0);
    } else if (nfiles == 1) {
        fp = fopen(argv[0], "r");
        if (fp == NULL) {
            perror(argv[0]);
            exit(2);
        }
        process(fp, argv[0], 0);
        fclose(fp);
    } else {
        for (i = 0; i < nfiles; i++) {
            fp = fopen(argv[i], "r");
            if (fp == NULL) {
                perror(argv[i]);
                status = 2;
                continue;
            }
            process(fp, argv[i], 1);
            fclose(fp);
        }
    }

    /* free compiled patterns */
    for (i = 0; i < npatterns; i++)
        regfree(&patterns[i]);

    exit(status);
}
