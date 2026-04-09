/*
 * compress.c -- classic Unix LZW file compression
 *
 * Derived from the public-domain Unix compress by Spencer Thomas,
 * Jim McKie, Steve Davies, Ken Turkowski, James A. Woods, Joe Orost,
 * and many others.
 *
 * Ported to GNO/ME (Apple IIgs, ORCA/C 2.2.2) by the GNO project.
 *
 * 65816 constraints observed:
 *   - int  = 16 bits (INT_MAX = 32767)
 *   - long = 32 bits
 *   - MAXBITS = 12  → MAXCODE = 4095  (fits in unsigned int)
 *   - HSIZE   = 5003 (prime > 4096; fits in unsigned int)
 *   - htab[]  = 5003 longs  = ~20 KB  (global data segment — OK)
 *   - codetab = 5003 uints  = ~10 KB  (global — OK)
 *   - No array uses a signed-int index beyond 32767
 *   - Shift expressions cast to (long) to avoid 16-bit UB
 *   - K&R / C89 style; all variable declarations at top of each block
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>

/* ── compile-time parameters ─────────────────────────────────────────── */

#define MAXBITS_DEFAULT 12      /* max code width; safe for 65816            */
#define HSIZE           5003    /* hash table size (prime > 2^MAXBITS)       */

/* MAXCODE: cast to long before shift so 1<<12 is not 16-bit UB on 65816.
 * Result fits in unsigned int since MAXBITS <= 12.
 */
#define MAXCODE(n)      ((unsigned int)(((long)1 << (n)) - 1L))

#define MAGIC_1         ((unsigned char)0x1F)
#define MAGIC_2         ((unsigned char)0x9D)
#define BIT_MASK        0x1F    /* mask for max-bits field in header          */
#define BLOCK_MODE_FLAG 0x80    /* enable CLEAR code                          */

#define CODE_CLEAR      256     /* table clear code                           */
#define CODE_FIRST      257     /* first free entry after CLEAR               */
#define INIT_BITS       9       /* initial code width                         */

#define CHECK_GAP       10000L  /* bytes between ratio checks                 */
#define BUFSZ           1024    /* local I/O buffer                           */

/* ── types ───────────────────────────────────────────────────────────── */

/* code_t: unsigned int, range 0–65535.
 * MAXBITS=12 → codes 0..4095 — well within range.
 */
typedef unsigned int code_t;

/* ── global tables (allocated in static data, not stack) ─────────────── */

/* htab[i] stores the 20-bit hash key as a long (negative = empty slot).
 * 5003 * 4 bytes = ~20 KB.
 */
static long     htab[HSIZE];

/* codetab[i] stores the code_t assigned to hash slot i.
 * 5003 * 2 bytes = ~10 KB.
 */
static code_t   codetab[HSIZE];

/* Decode tables (expand path) */
#define TSIZE 4096      /* 2^MAXBITS — string table entries */
static code_t        tab_prefix[TSIZE]; /* 4096 * 2 = 8 KB  */
static unsigned char tab_suffix[TSIZE]; /* 4096 * 1 = 4 KB  */
static unsigned char de_stack[TSIZE];   /* 4096 bytes        */

/* ── per-stream state ─────────────────────────────────────────────────── */

static int      maxbits;            /* configured max code width              */
static int      block_mode;         /* 1 = BLOCK_MODE                         */
static int      n_bits;             /* current code width                     */
static code_t   maxcode;            /* = MAXCODE(n_bits)                      */
static code_t   maxmaxcode;         /* = MAXCODE(maxbits)                     */
static code_t   free_ent;           /* next free code                         */
static long     ratio;              /* last recorded ratio                    */
static long     checkpoint;         /* next byte count for ratio check        */
static long     in_count;           /* input bytes processed                  */
static long     bytes_out;          /* output bytes written                   */
static int      clear_flg;          /* clear-table flag                       */

/* ── file descriptors and names ──────────────────────────────────────── */

static int  infp  = -1;
static int  outfp = -1;
static char ofname[512];

/* ── option flags ─────────────────────────────────────────────────────── */

static int verbose_flag;
static int force_flag;
static int decompress_flag;
static int stdout_flag;
static int maxbits_opt;

/* ── bit-packing output buffer ───────────────────────────────────────── */

/* Classic compress packs codes into blocks of n_bits bytes each.
 * Maximum block size = MAXBITS_DEFAULT bytes = 12 bytes.
 * We keep the buffer padded.
 */
#define GBUF_SIZE  (MAXBITS_DEFAULT * 8 + 8)
static unsigned char g_buf[GBUF_SIZE];
static int           g_offset;         /* current bit offset into g_buf   */
static int           g_buf_size;        /* current block size in bytes      */

/* ── bit-unpacking input buffer ──────────────────────────────────────── */

static unsigned char in_buf[GBUF_SIZE];
static int           in_buf_bits;       /* bits remaining in in_buf         */
static int           in_buf_off;        /* current bit offset into in_buf   */
static int           in_eof;            /* seen EOF                         */

/* ── forward declarations ────────────────────────────────────────────── */
static void    usage         (void);
static void    onintr        (int);
static void    writechk      (int, unsigned char *, int);
static void    cl_hash       (void);
static void    out_code      (code_t);
static void    flush_codes   (void);
static code_t  in_code       (void);
static void    compress_stream (void);
static void    expand_stream   (void);
static int     process_file  (char *);

/* ── signal handler ──────────────────────────────────────────────────── */

static void
onintr(sig)
    int sig;
{
    if (outfp >= 0 && !stdout_flag) {
        close(outfp);
        outfp = -1;
        unlink(ofname);
    }
    exit(1);
}

/* ── checked write ───────────────────────────────────────────────────── */

static void
writechk(fd, buf, n)
    int            fd;
    unsigned char *buf;
    int            n;
{
    if (write(fd, (char *)buf, n) != n) {
        perror("compress: write");
        if (outfp >= 0 && !stdout_flag)
            unlink(ofname);
        exit(1);
    }
}

/* ── hash table clear ────────────────────────────────────────────────── */

static void
cl_hash()
{
    int i;
    for (i = 0; i < HSIZE; i++)
        htab[i] = -1L;
}

/* ── output one code (packing into bytes, n_bits bits per code) ──────── */

/*
 * Classic compress "block" scheme:
 * Accumulate codes into g_buf, n_bits bits per code, LSB first.
 * When g_buf is full (g_offset == g_buf_size * 8 bits), flush it.
 * After flushing, bump n_bits if free_ent > maxcode.
 */
static void
out_code(code)
    code_t code;
{
    unsigned int r_off;
    unsigned int bits;
    unsigned char *bp;

    /* deposit code into g_buf, LSB first */
    r_off = (unsigned int)g_offset;
    bits  = (unsigned int)n_bits;
    bp    = g_buf + (r_off >> 3);

    r_off &= 7u;
    if (r_off != 0) {
        *bp = (unsigned char)(*bp | ((unsigned char)code << r_off));
        code = (code_t)(code >> (8u - r_off));
        bits -= (8u - r_off);
        bp++;
    }
    while (bits >= 8u) {
        *bp++ = (unsigned char)code;
        code  = (code_t)(code >> 8u);
        bits -= 8u;
    }
    if (bits != 0)
        *bp = (unsigned char)code;

    g_offset += n_bits;

    if (g_offset == g_buf_size * 8) {
        writechk(outfp, g_buf, g_buf_size);
        bytes_out += (long)g_buf_size;
        memset(g_buf, 0, (unsigned int)g_buf_size);
        g_offset  = 0;
    }

    /* bump code width once we've exhausted the current range */
    if (free_ent > maxcode) {
        if (n_bits < maxbits) {
            n_bits++;
            g_buf_size = n_bits;
            maxcode    = MAXCODE(n_bits);
        }
    }
}

static void
flush_codes()
{
    int nb;
    if (g_offset > 0) {
        nb = (g_offset + 7) / 8;
        writechk(outfp, g_buf, nb);
        bytes_out += (long)nb;
        g_offset   = 0;
    }
}

/* ── input one code (unpacking from bytes) ───────────────────────────── */

/*
 * Read a block of n_bits bytes, then dispense n_bits-bit codes from it.
 */
static code_t
in_code()
{
    code_t         code;
    unsigned int   r_off;
    unsigned int   bits;
    unsigned char *bp;

    if (in_buf_bits < n_bits) {
        /* read next block */
        int nr;
        if (in_eof)
            return (code_t)(-1);
        nr = read(infp, (char *)in_buf, n_bits);
        if (nr <= 0) {
            in_eof = 1;
            return (code_t)(-1);
        }
        if (nr < n_bits) {
            /* partial block: zero-pad */
            memset(in_buf + nr, 0, (unsigned int)(n_bits - nr));
        }
        in_buf_off  = 0;
        in_buf_bits = n_bits * 8;
    }

    /* extract n_bits bits from in_buf, LSB first */
    r_off = (unsigned int)in_buf_off;
    bits  = (unsigned int)n_bits;
    bp    = in_buf + (r_off >> 3);
    r_off &= 7u;

    code = (code_t)(*bp++ >> r_off);
    bits -= (8u - r_off);
    while (bits >= 8u) {
        code |= (code_t)*bp++ << (n_bits - (int)bits);
        bits -= 8u;
    }
    if (bits != 0)
        code |= (code_t)(*bp & (unsigned char)((1u << bits) - 1u)) << (n_bits - (int)bits);

    code &= MAXCODE(n_bits);

    in_buf_off  += n_bits;
    in_buf_bits -= n_bits;

    return code;
}

/* ── compress ─────────────────────────────────────────────────────────── */

static void
compress_stream()
{
    unsigned char  inbuf[BUFSZ];
    int            nr;
    int            pos;
    code_t         ent;
    code_t         disp;
    unsigned int   fcode_i;
    long           fcode;
    int            c;

    /* write 3-byte header */
    {
        unsigned char hdr[3];
        hdr[0] = MAGIC_1;
        hdr[1] = MAGIC_2;
        hdr[2] = (unsigned char)(maxbits | (block_mode ? BLOCK_MODE_FLAG : 0));
        writechk(outfp, hdr, 3);
        bytes_out = 3L;
    }

    n_bits      = INIT_BITS;
    maxcode     = MAXCODE(n_bits);
    maxmaxcode  = MAXCODE(maxbits);
    free_ent    = block_mode ? (code_t)CODE_FIRST : (code_t)256;
    clear_flg   = 0;
    ratio       = 0L;
    in_count    = 0L;
    checkpoint  = CHECK_GAP;

    cl_hash();
    memset(g_buf, 0, sizeof(g_buf));
    g_offset   = 0;
    g_buf_size = n_bits;

    /* read first byte */
    nr = read(infp, (char *)inbuf, BUFSZ);
    if (nr <= 0) {
        flush_codes();
        return;
    }
    pos = 0;
    ent = (code_t)(unsigned char)inbuf[pos++];
    in_count = 1L;

    for (;;) {
        /* get next input byte */
        if (pos >= nr) {
            nr = read(infp, (char *)inbuf, BUFSZ);
            if (nr <= 0)
                break;
            pos = 0;
        }
        c = (unsigned char)inbuf[pos++];
        in_count++;

        /* hash: fcode encodes (prefix, suffix) pair */
        fcode   = ((long)c << 12) + (long)ent;
        fcode_i = (unsigned int)((unsigned long)fcode % (unsigned long)HSIZE);

        if (htab[fcode_i] == fcode) {
            /* cache hit */
            ent = codetab[fcode_i];
            continue;
        }

        if (htab[fcode_i] >= 0L) {
            /* collision: secondary probe */
            disp = (fcode_i == 0) ? 1 : (code_t)(HSIZE - (int)fcode_i);
            do {
                if (fcode_i >= (unsigned int)disp)
                    fcode_i -= (unsigned int)disp;
                else
                    fcode_i += (unsigned int)(HSIZE - (int)disp);
                if (htab[fcode_i] == fcode) {
                    ent = codetab[fcode_i];
                    goto next_char;
                }
            } while (htab[fcode_i] >= 0L);
        }

        /* not found: output current prefix code */
        out_code(ent);

        if (free_ent < maxmaxcode) {
            /* add new entry */
            codetab[fcode_i] = free_ent++;
            htab[fcode_i]    = fcode;
        } else if (block_mode && in_count >= checkpoint) {
            /* periodic ratio check */
            long new_ratio;
            if (in_count > 0x7fffffL)
                new_ratio = bytes_out >> 8;
            else
                new_ratio = (bytes_out << 8) / in_count;
            if (new_ratio > ratio) {
                ratio = new_ratio;
            } else {
                ratio     = 0L;
                clear_flg = 1;
                cl_hash();
                free_ent  = (code_t)CODE_FIRST;
                out_code((code_t)CODE_CLEAR);
                n_bits     = INIT_BITS;
                maxcode    = MAXCODE(n_bits);
                g_buf_size = n_bits;
            }
            checkpoint = in_count + CHECK_GAP;
        }

        ent = (code_t)c;

        if (clear_flg) {
            cl_hash();
            free_ent  = (code_t)CODE_FIRST;
            clear_flg = 0;
            /* re-insert the current character */
            fcode   = ((long)c << 12) + (long)ent;
            fcode_i = (unsigned int)((unsigned long)fcode % (unsigned long)HSIZE);
        }
        htab[fcode_i]    = fcode;
        codetab[fcode_i] = ent;

        next_char: ;
    }

    out_code(ent);
    /* sentinel: one code beyond maxmaxcode signals EOF to decoder */
    out_code((code_t)(maxmaxcode + 1u));
    flush_codes();
}

/* ── expand ───────────────────────────────────────────────────────────── */

static void
expand_stream()
{
    unsigned char  hdr[3];
    int            hdr_maxbits;
    int            hdr_block;
    code_t         code;
    code_t         oldcode;
    code_t         incode;
    int            finchar;
    unsigned char *stackp;
    unsigned int   i;
    unsigned char  wrbuf[BUFSZ];
    int            wrcnt;

    /* read and verify header */
    {
        int nr = read(infp, (char *)hdr, 3);
        if (nr < 3 || hdr[0] != MAGIC_1 || hdr[1] != MAGIC_2) {
            fprintf(stderr, "compress: not in compress format\n");
            exit(1);
        }
    }
    hdr_maxbits = (int)(hdr[2] & (unsigned char)BIT_MASK);
    hdr_block   = (hdr[2] & (unsigned char)BLOCK_MODE_FLAG) ? 1 : 0;

    if (hdr_maxbits > MAXBITS_DEFAULT) {
        fprintf(stderr,
            "compress: compressed with %d bits, can only handle %d\n",
            hdr_maxbits, MAXBITS_DEFAULT);
        exit(1);
    }

    maxbits    = hdr_maxbits;
    block_mode = hdr_block;
    n_bits     = INIT_BITS;
    maxcode    = MAXCODE(n_bits);
    maxmaxcode = MAXCODE(maxbits);
    free_ent   = block_mode ? (code_t)CODE_FIRST : (code_t)256;
    in_eof     = 0;
    in_buf_bits= 0;
    in_buf_off = 0;

    /* identity initialise string table */
    for (i = 0; i < 256; i++) {
        tab_prefix[i] = 0;
        tab_suffix[i] = (unsigned char)i;
    }

    oldcode = (code_t)(-1);
    finchar = 0;
    stackp  = de_stack;
    wrcnt   = 0;

    while ((code = in_code()) != (code_t)(-1)) {

        if ((int)code == CODE_CLEAR && block_mode) {
            for (i = 0; i < 256; i++) {
                tab_prefix[i] = 0;
                tab_suffix[i] = (unsigned char)i;
            }
            free_ent    = (code_t)CODE_FIRST;
            n_bits      = INIT_BITS;
            maxcode     = MAXCODE(n_bits);
            in_buf_bits = 0;
            in_buf_off  = 0;
            oldcode     = (code_t)(-1);
            continue;
        }

        incode = code;

        /* special case: code == free_ent */
        if (code >= free_ent) {
            if (code > free_ent || oldcode == (code_t)(-1)) {
                fprintf(stderr, "compress: corrupt input\n");
                exit(1);
            }
            *stackp++ = (unsigned char)finchar;
            code      = oldcode;
        }

        /* unwind string */
        while (code >= 256) {
            if (stackp >= de_stack + TSIZE) {
                fprintf(stderr, "compress: stack overflow\n");
                exit(1);
            }
            *stackp++ = tab_suffix[code];
            code      = tab_prefix[code];
        }
        finchar   = (int)tab_suffix[code];
        *stackp++ = (unsigned char)finchar;

        /* emit (in reverse) */
        while (stackp > de_stack) {
            --stackp;
            wrbuf[wrcnt++] = *stackp;
            if (wrcnt == BUFSZ) {
                writechk(outfp, wrbuf, BUFSZ);
                wrcnt = 0;
            }
        }

        /* add new entry */
        if (free_ent < maxmaxcode && oldcode != (code_t)(-1)) {
            tab_prefix[free_ent] = oldcode;
            tab_suffix[free_ent] = (unsigned char)finchar;
            free_ent++;
            if (free_ent > maxcode && n_bits < maxbits) {
                n_bits++;
                maxcode     = MAXCODE(n_bits);
                in_buf_bits = 0;
                in_buf_off  = 0;
            }
        }
        oldcode = incode;
    }

    if (wrcnt > 0)
        writechk(outfp, wrbuf, wrcnt);
}

/* ── process one named file ──────────────────────────────────────────── */

static int
process_file(fname)
    char *fname;
{
    struct stat st;
    int         len;
    long        orig_size;

    infp = open(fname, O_RDONLY);
    if (infp < 0) {
        perror(fname);
        return 1;
    }
    if (fstat(infp, &st) < 0) {
        perror(fname);
        close(infp);
        infp = -1;
        return 1;
    }
    orig_size = st.st_size;

    if (decompress_flag) {
        /* strip .Z suffix to get output name */
        len = (int)strlen(fname);
        if (len > 2 && fname[len-2] == '.' && fname[len-1] == 'Z') {
            strncpy(ofname, fname, (unsigned int)(len - 2));
            ofname[len - 2] = '\0';
        } else {
            fprintf(stderr, "compress: %s: does not end in .Z -- no change\n",
                    fname);
            close(infp);
            infp = -1;
            return 1;
        }
    } else {
        /* append .Z suffix */
        len = (int)strlen(fname);
        if (len + 2 >= (int)sizeof(ofname)) {
            fprintf(stderr, "compress: %s: filename too long\n", fname);
            close(infp);
            infp = -1;
            return 1;
        }
        strcpy(ofname, fname);
        ofname[len]   = '.';
        ofname[len+1] = 'Z';
        ofname[len+2] = '\0';
    }

    if (stdout_flag) {
        outfp = 1; /* stdout */
    } else {
        if (!force_flag && stat(ofname, &st) == 0) {
            fprintf(stderr,
                "compress: %s already exists; not overwritten\n", ofname);
            close(infp);
            infp = -1;
            return 1;
        }
        outfp = open(ofname, O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (outfp < 0) {
            perror(ofname);
            close(infp);
            infp = -1;
            return 1;
        }
    }

    bytes_out = 0L;

    if (decompress_flag)
        expand_stream();
    else
        compress_stream();

    close(infp);
    infp = -1;

    if (!stdout_flag) {
        close(outfp);
        outfp = -1;
        /* remove input file */
        unlink(fname);
    }

    if (verbose_flag && !decompress_flag && orig_size > 0L) {
        long pct = ((orig_size - bytes_out) * 100L) / orig_size;
        fprintf(stderr, "%s: %ld%% -- replaced with %s\n",
                fname, pct, ofname);
    }

    return 0;
}

/* ── usage ────────────────────────────────────────────────────────────── */

static void
usage()
{
    fprintf(stderr,
        "usage: compress [-cdfv] [-b bits] [file ...]\n"
        "  -b bits  set max bits (9-%d; default %d)\n"
        "  -c       write to stdout\n"
        "  -d       decompress\n"
        "  -f       force overwrite\n"
        "  -v       verbose\n",
        MAXBITS_DEFAULT, MAXBITS_DEFAULT);
    exit(1);
}

/* ── main ─────────────────────────────────────────────────────────────── */

int
main(argc, argv)
    int   argc;
    char *argv[];
{
    int   ch;
    int   rc;
    char *p;

    /* set defaults */
    maxbits    = MAXBITS_DEFAULT;
    block_mode = 1;

    /* detect if invoked as "uncompress" or "zcat" */
    p = argv[0];
    {
        char *q = strrchr(p, '/');
        if (q) p = q + 1;
    }
    if (strcmp(p, "uncompress") == 0)
        decompress_flag = 1;
    if (strcmp(p, "zcat") == 0) {
        decompress_flag = 1;
        stdout_flag     = 1;
    }

    while ((ch = getopt(argc, argv, "b:cdfv")) != EOF) {
        switch (ch) {
        case 'b':
            maxbits_opt = atoi(optarg);
            if (maxbits_opt < 9 || maxbits_opt > MAXBITS_DEFAULT) {
                fprintf(stderr,
                    "compress: bits must be between 9 and %d\n",
                    MAXBITS_DEFAULT);
                exit(1);
            }
            maxbits = maxbits_opt;
            break;
        case 'c':
            stdout_flag = 1;
            break;
        case 'd':
            decompress_flag = 1;
            break;
        case 'f':
            force_flag = 1;
            break;
        case 'v':
            verbose_flag = 1;
            break;
        default:
            usage();
        }
    }
    argv = argv + optind;
    argc -= optind;

    signal(SIGINT, onintr);

    rc = 0;

    if (argc == 0) {
        /* stdin → stdout */
        infp  = 0;
        outfp = 1;
        stdout_flag = 1;
        bytes_out = 0L;
        if (decompress_flag)
            expand_stream();
        else
            compress_stream();
    } else {
        int i;
        for (i = 0; i < argc; i++)
            rc |= process_file(argv[i]);
    }

    return rc;
}
