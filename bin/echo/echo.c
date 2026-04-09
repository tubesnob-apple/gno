#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int
octval(char *p, int *advance)
{
    int val;
    int n;

    val = 0;
    n = 0;
    while (n < 3 && *p >= '0' && *p <= '7') {
        val = val * 8 + (*p - '0');
        p++;
        n++;
    }
    *advance = n;
    return val;
}

static int
process(char *s)
{
    int advance;
    int c;

    while (*s) {
        if (*s != '\\') {
            putchar(*s++);
            continue;
        }
        s++;
        switch (*s) {
        case 'b':  putchar('\b'); s++; break;
        case 'c':  s++; return 1;
        case 'f':  putchar('\f'); s++; break;
        case 'n':  putchar('\n'); s++; break;
        case 'r':  putchar('\r'); s++; break;
        case 't':  putchar('\t'); s++; break;
        case 'v':  putchar('\v'); s++; break;
        case '\\': putchar('\\'); s++; break;
        case '0':
            s++;
            c = octval(s, &advance);
            s += advance;
            putchar(c);
            break;
        default:
            putchar('\\');
            break;
        }
    }
    return 0;
}

int
main(argc, argv)
int argc;
char **argv;
{
    int nflag;
    int eflag;
    int i;
    int suppress;

    nflag = 0;
    eflag = 0;

    i = 1;
    if (i < argc && argv[i][0] == '-') {
        char *p;
        p = argv[i] + 1;
        if (*p != '\0') {
            int valid;
            char *q;
            valid = 1;
            for (q = p; *q; q++) {
                if (*q != 'n' && *q != 'e') {
                    valid = 0;
                    break;
                }
            }
            if (valid) {
                for (q = p; *q; q++) {
                    if (*q == 'n') nflag = 1;
                    if (*q == 'e') eflag = 1;
                }
                i++;
            }
        }
    }

    suppress = 0;
    while (i < argc) {
        if (eflag) {
            if (process(argv[i]))
                suppress = 1;
        } else {
            fputs(argv[i], stdout);
        }
        if (!suppress && i + 1 < argc)
            putchar(' ');
        if (suppress)
            break;
        i++;
    }

    if (!nflag && !suppress)
        putchar('\n');

    return 0;
}
