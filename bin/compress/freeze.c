/*
 * freeze.c -- LZH freeze/melt compressor
 *
 * Implements the "freeze" format (magic 0x1F 0x9E), a Lempel-Ziv +
 * static Huffman (LZH) compressor.  "melt" is the decompressor; this
 * binary serves both roles, selecting by argv[0].
 *
 * Algorithm:
 *   Compression : LZSS with a 4096-byte (12-bit) sliding window +
 *                 per-block static Huffman coding of symbols and positions.
 *   Decompression: reverse of the above.
 *
 * Huffman coding is LHarc-style: each block carries a header with the
 * C-table (literal/length symbols 0..NC-1) and P-table (window positions).
 * The C-table lengths are themselves encoded with a T-table.
 *
 * 65816 (ORCA/C 2.2.2) constraints:
 *   - int  = 16 bits  (INT_MAX = 32767)
 *   - long = 32 bits
 *   - All globals fit in OMF data segment
 *   - No signed-int index past 32767
 *   - (1 << N) for N >= 16 is UB — all shifts cast to long first
 *   - K&R / C89 style; all variable declarations at top of each block
 *   - No mixed declarations; no VLAs
 *
 * Array size summary (all global):
 *   text_buf      4114 bytes    LZSS window + lookahead
 *   lson / dad    4096 ints     8 KB each (tree children/parent)
 *   rson          4353 ints     ~8.7 KB (window nodes + 257 root slots)
 *   c_len / c_code 272 each     272 bytes + 544 bytes
 *   p_len / p_code  13 each     13 bytes + 26 bytes
 *   freq[]        544 uint16    1088 bytes (Huffman build)
 *   c_table[]     512 uint16    1024 bytes (9-bit decoder table)
 *   p_table[]     256 uint16    512 bytes  (8-bit decoder table)
 *   blk_code/pos  512 uint16 each  2 KB each
 *
 * Total global: ~50 KB — fits comfortably in an Apple IIgs data segment.
 *
 * Ported to GNO/ME (Apple IIgs, ORCA/C 2.2.2) by the GNO project.
 */

#include <stdio.h>
#include <unistd.h>

#ifdef __ORCAC__
#pragma optimize 78
#endif
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>

/* ── constants ────────────────────────────────────────────────────────── */

#define FREEZE_MAGIC_1  ((unsigned char)0x1F)
#define FREEZE_MAGIC_2  ((unsigned char)0x9E)
#define FREEZE_VERSION  ((unsigned char)0x01)

/* LZSS sliding-window parameters.
 * Use long casts for shifts to avoid 16-bit UB on 65816.
 */
#define WBITS    12
#define WSIZE    ((int)((long)1 << WBITS))   /* 4096 */
#define WMASK    (WSIZE - 1)                  /* 0x0FFF */
#define MAXMATCH 18                            /* max match length */
#define THRESHOLD 3                            /* min match to encode */

/* Huffman alphabet sizes */
#define NC      (256 + MAXMATCH - THRESHOLD + 1)  /* 272: literal + length codes */
#define NP      (WBITS + 1)                        /* 13: position codes */
#define NT      19                                  /* code-length codes */
#define TBIT    5                                   /* bits to represent NT */
#define CBIT    9                                   /* bits to represent NC */
#define PBIT    4                                   /* bits to represent NP */

/* Block size: number of symbols per encoded block */
#define BLOCKSIZE  512

/* I/O buffers */
#define IBUFSZ  1024
#define OBUFSZ  1024

/* ── integer types ───────────────────────────────────────────────────── */
typedef unsigned int  u16;  /* 16-bit on 65816 */
typedef unsigned long u32;  /* 32-bit on 65816 */

/* ── globals: I/O ─────────────────────────────────────────────────────── */
static int infp  = -1;
static int outfp = -1;
static int g_in_eof;

/* All large arrays are heap-allocated to avoid a 45KB static ~ARRAYS
 * segment that pushes the linked binary past the 64KB code bank limit.
 * freeze_alloc_tables() in main allocates them all in one pass. */

static unsigned char *ibuf;          /* IBUFSZ bytes */
static int           ibuf_pos;
static int           ibuf_len;

static unsigned char *obuf;          /* OBUFSZ bytes */
static int           obuf_len;

/* Bit output state */
static int  bitcount;
static int  subbitbuf;

/* Bit input state */
static u32  bitbuf;
static int  bitsin;

/* ── globals: LZSS tree ───────────────────────────────────────────────── */

static unsigned char *text_buf;      /* WSIZE + MAXMATCH bytes */
static int           match_pos;
static int           match_len;

static int *lson;                    /* WSIZE ints */
static int *rson;                    /* WSIZE + 257 ints */
static int *dad;                     /* WSIZE ints */

/* ── globals: Huffman tables ──────────────────────────────────────────── */

static unsigned char *c_len;         /* NC bytes */
static u16           *c_code;        /* NC u16s */
static unsigned char *p_len;         /* NP bytes */
static u16           *p_code;        /* NP u16s */
static unsigned char *t_len;         /* NT bytes */
static u16           *t_code;        /* NT u16s */
static u16  *c_table;               /* 512 u16s */
static u16  *p_table;               /* 256 u16s */

#define TMAX (NC * 2)
static u16  *freq;                   /* TMAX u16s */
static int  *t_table;               /* 256 ints */
static u16  *blk_code;              /* BLOCKSIZE u16s */
static u16  *blk_pos;               /* BLOCKSIZE u16s */
static int  blk_cnt;

/* ── option flags ─────────────────────────────────────────────────────── */
static int verbose_flag;
static int force_flag;
static int stdout_flag;
static int decompress_flag;
static char ofname[512];

/* ── forward declarations ────────────────────────────────────────────── */
static void   init_io          (void);
static int    read_byte        (void);
static void   write_byte       (unsigned char);
static void   flush_obuf       (void);
static void   putbits          (int, u16);
static void   flushbits        (void);
static u16    getbits          (int);
static void   fill32           (int);

static void   init_tree        (void);
static void   insert_node      (int);
static void   delete_node      (int);

static void   make_codes_from_lens (unsigned char *, u16 *, int);
static void   build_tree       (unsigned char *, u16 *, int);
static void   init_p_table     (void);
static void   make_c_table     (void);
static void   make_p_table     (void);

static void   count_t_freq     (void);
static void   write_pt_len     (unsigned char *, int, int, int);
static void   write_c_len      (void);
static void   encode_c         (int);
static void   encode_p         (u16);
static void   send_block       (void);

static u16    decode_c         (void);
static u16    decode_p         (void);
static void   read_pt_len      (unsigned char *, u16 *, int, int, int);
static void   read_c_len       (void);

static void   do_freeze        (void);
static void   do_melt          (void);
static int    process_file     (char *);
static void   usage            (void);
static void   onintr           (int);

/* ── I/O helpers ─────────────────────────────────────────────────────── */

static void
init_io()
{
    ibuf_pos     = 0;
    ibuf_len     = 0;
    obuf_len     = 0;
    bitcount     = 0;
    subbitbuf    = 0;
    bitbuf       = 0;
    bitsin       = 0;
    g_in_eof     = 0;
}

static int
read_byte()
{
    if (ibuf_pos >= ibuf_len) {
        ibuf_len = read(infp, (char *)ibuf, IBUFSZ);
        if (ibuf_len <= 0) {
            g_in_eof = 1;
            return -1;
        }
        ibuf_pos = 0;
    }
    return (unsigned char)ibuf[ibuf_pos++];
}

static void
flush_obuf()
{
    if (obuf_len > 0) {
        if (write(outfp, (char *)obuf, obuf_len) != obuf_len) {
            perror("freeze: write");
            exit(1);
        }
        obuf_len = 0;
    }
}

static void
write_byte(c)
    unsigned char c;
{
    obuf[obuf_len++] = c;
    if (obuf_len == OBUFSZ)
        flush_obuf();
}

/* ── bit output ──────────────────────────────────────────────────────── */

/* putbits: write n bits (MSB first) from val */
static void
putbits(n, val)
    int n;
    u16 val;
{
    /* shift val to top of 16 bits */
    val = (u16)(val << (16 - n));
    while (n-- > 0) {
        subbitbuf = (subbitbuf << 1) | ((val & 0x8000u) ? 1 : 0);
        val = (u16)(val << 1);
        bitcount++;
        if (bitcount == 8) {
            write_byte((unsigned char)subbitbuf);
            subbitbuf = 0;
            bitcount  = 0;
        }
    }
}

/* flushbits: pad output to byte boundary */
static void
flushbits()
{
    /* pad remaining bits in subbitbuf with zeros */
    if (bitcount > 0) {
        subbitbuf <<= (8 - bitcount);
        write_byte((unsigned char)subbitbuf);
        subbitbuf = 0;
        bitcount  = 0;
    }
}

/* ── bit input ───────────────────────────────────────────────────────── */

/* fill32: ensure at least n bits are in bitbuf (refill from input) */
static void
fill32(n)
    int n;
{
    while (bitsin < n) {
        int c = read_byte();
        if (c < 0) c = 0;
        bitbuf  = (bitbuf << 8) | (unsigned char)c;
        bitsin += 8;
    }
}

/* getbits: return top n bits of bitbuf, then consume them */
static u16
getbits(n)
    int n;
{
    u16 val;
    fill32(n);
    val    = (u16)(bitbuf >> (bitsin - n));
    bitsin -= n;
    bitbuf &= (u32)(((u32)1 << bitsin) - 1u);
    return val;
}

/* peek: look at top 16 bits without consuming */
#define PEEK16() ((u16)(bitbuf >> (bitsin - 16)))

/* skip n bits */
#define SKIPBITS(n) do { bitsin -= (n); bitbuf &= (u32)(((u32)1 << bitsin) - 1u); } while (0)

/* ── LZSS binary tree ────────────────────────────────────────────────── */

static void
init_tree()
{
    int i;
    for (i = WSIZE + 1; i <= WSIZE + 256; i++)
        rson[i] = WSIZE;        /* null sentinel */
    for (i = 0; i < WSIZE; i++)
        dad[i]  = WSIZE;        /* unparented */
    match_pos = 0;
    match_len = 0;
}

static void
insert_node(r)
    int r;
{
    int            i, p, cmp;
    unsigned char *key;
    unsigned char *keyp;

    cmp = 1;
    key = text_buf + r;
    p   = WSIZE + 1 + (int)(unsigned char)key[0];
    rson[r] = lson[r] = WSIZE;
    match_len = 0;

    for (;;) {
        if (cmp >= 0) {
            if (rson[p] != WSIZE)  { p = rson[p]; }
            else { rson[p] = r; dad[r] = p; return; }
        } else {
            if (lson[p] != WSIZE)  { p = lson[p]; }
            else { lson[p] = r; dad[r] = p; return; }
        }
        keyp = text_buf + p;
        for (i = 1; i < MAXMATCH; i++) {
            cmp = (int)(unsigned char)key[i] - (int)(unsigned char)keyp[i];
            if (cmp != 0) break;
        }
        if (i > match_len) {
            match_pos = p;
            match_len = i;
            if (match_len >= MAXMATCH) break;
        }
    }
    dad[r]       = dad[p];
    lson[r]      = lson[p];
    rson[r]      = rson[p];
    dad[lson[p]] = r;
    dad[rson[p]] = r;
    if (rson[dad[p]] == p) rson[dad[p]] = r;
    else                   lson[dad[p]] = r;
    dad[p] = WSIZE;   /* detach p */
}

static void
delete_node(p)
    int p;
{
    int q;
    if (dad[p] == WSIZE) return;   /* not in tree */
    if      (rson[p] == WSIZE)  q = lson[p];
    else if (lson[p] == WSIZE)  q = rson[p];
    else {
        q = lson[p];
        if (rson[q] != WSIZE) {
            do { q = rson[q]; } while (rson[q] != WSIZE);
            rson[dad[q]] = lson[q];
            dad[lson[q]] = dad[q];
            lson[q]      = lson[p];
            dad[lson[p]] = q;
        }
        rson[q]      = rson[p];
        dad[rson[p]] = q;
    }
    dad[q] = dad[p];
    if (rson[dad[p]] == p) rson[dad[p]] = q;
    else                   lson[dad[p]] = q;
    dad[p] = WSIZE;
}

/* ── Huffman tree construction ───────────────────────────────────────── */

/*
 * make_codes_from_lens: given already-computed code lengths in len[0..n-1],
 * assign canonical Huffman codes into code[0..n-1].  Does NOT use freq[].
 * Used by the decoder after reading code lengths from the bitstream.
 */
static void
make_codes_from_lens(len, code, n)
    unsigned char *len;
    u16           *code;
    int            n;
{
    int bl_count[17];
    int next_code[17];
    int k, i, c2;

    for (k = 0; k <= 16; k++) bl_count[k] = 0;
    for (i = 0; i < n; i++) bl_count[(int)len[i]]++;

    c2 = 0;
    for (k = 1; k <= 16; k++) {
        c2 = (c2 + bl_count[k - 1]) << 1;
        next_code[k] = c2;
    }

    for (i = 0; i < n; i++) {
        if (len[i] == 0) { code[i] = 0; continue; }
        code[i] = (u16)next_code[(int)len[i]]++;
    }
}

/*
 * build_tree: given freq[] (0..n-1), produce canonical Huffman codes
 * in len[] and code[].
 *
 * Uses O(n^2) algorithm safe for n ≤ NC = 272.
 */
static void
build_tree(len, code, n)
    unsigned char *len;
    u16           *code;
    int            n;
{
    /* parent[i] = parent in Huffman tree; -1 = root/unassigned */
    static int   parent[TMAX];   /* TMAX = NC*2 = 544; 544*2 = 1088 B */
    static u32   nf[TMAX];       /* node frequencies (long for safety) */
    int          avail;
    int          i, j, k;
    int          n1, n2;
    u32          fmin;
    int          bl_count[17];
    int          next_code[17];
    int          c2, bits;
    u16          rev;

    /* seed with leaf frequencies (treat zero as 1 to avoid empty codes) */
    for (i = 0; i < n; i++) {
        nf[i]     = (freq[i] == 0) ? 1u : (u32)freq[i];
        parent[i] = -1;
    }
    avail = n;

    /* Huffman merge loop */
    for (;;) {
        /* find two lightest unmerged nodes */
        n1 = -1; fmin = 0xFFFFFFFFUL;
        for (i = 0; i < avail; i++)
            if (parent[i] < 0 && nf[i] <= fmin) { fmin = nf[i]; n1 = i; }
        n2 = -1; fmin = 0xFFFFFFFFUL;
        for (i = 0; i < avail; i++)
            if (parent[i] < 0 && i != n1 && nf[i] <= fmin) { fmin = nf[i]; n2 = i; }
        if (n2 < 0) break;

        nf[avail]     = nf[n1] + nf[n2];
        parent[avail] = -1;
        parent[n1]    = avail;
        parent[n2]    = avail;
        avail++;
        if (avail >= TMAX) break;
    }

    /* assign code lengths */
    for (i = 0; i < n; i++) {
        int depth = 0;
        j = i;
        while (parent[j] >= 0) { j = parent[j]; depth++; }
        if (depth > 16) depth = 16;
        len[i] = (unsigned char)depth;
    }

    /* canonical codes: count lengths */
    for (k = 0; k <= 16; k++) bl_count[k] = 0;
    for (i = 0; i < n; i++) bl_count[(int)len[i]]++;

    /* first code for each length */
    c2 = 0;
    for (k = 1; k <= 16; k++) {
        c2 = (c2 + bl_count[k - 1]) << 1;
        next_code[k] = c2;
    }

    /* assign and bit-reverse for LSB-first output */
    for (i = 0; i < n; i++) {
        if (len[i] == 0) { code[i] = 0; continue; }
        code[i] = (u16)next_code[(int)len[i]]++;
        /* reverse bits (we write MSB first, so no reversal needed;
         * however the table-decode path expects MSB-first indexing,
         * so we keep the canonical (MSB-first) codes as-is).
         */
    }
}

/* ── P-table initialisation ──────────────────────────────────────────── */

static void
init_p_table()
{
    int i;
    for (i = 0; i < NP; i++)
        freq[i] = (u16)((long)1 << i);
    if (freq[NP - 1] == 0) freq[NP - 1] = 1;
    build_tree(p_len, p_code, NP);
}

/* ── decoder table construction ──────────────────────────────────────── */

/* make_c_table: build a 512-entry (2^CBIT) direct-lookup table for C */
static void
make_c_table()
{
    int    i, j, k;
    int    tblsz = (1 << CBIT);   /* 512 */

    memset(c_table, 0xFF, 512 * sizeof(u16));   /* 0xFFFF = invalid */
    for (i = 0; i < NC; i++) {
        int l = (int)c_len[i];
        if (l == 0 || l > CBIT) continue;
        k = (int)c_code[i] << (CBIT - l);
        j = 1 << (CBIT - l);
        while (j-- > 0)
            c_table[k++] = (u16)i;
    }
}

/* make_p_table: build a 256-entry (2^8) direct-lookup table for P */
static void
make_p_table()
{
    int i, j, k;

    memset(p_table, 0xFF, 256 * sizeof(u16));
    for (i = 0; i < NP; i++) {
        int l = (int)p_len[i];
        if (l == 0 || l > 8) continue;
        k = (int)p_code[i] << (8 - l);
        j = 1 << (8 - l);
        while (j-- > 0)
            p_table[k++] = (u16)i;
    }
}

/* ── block encoder ───────────────────────────────────────────────────── */

static void
count_t_freq()
{
    int i, n, k, cnt;

    for (i = 0; i < NT; i++) freq[i] = 0;
    n = NC;
    while (n > 0 && c_len[n - 1] == 0) n--;

    i = 0;
    while (i < n) {
        k = (int)c_len[i++];
        if (k == 0) {
            cnt = 1;
            while (i < n && c_len[i] == 0) { cnt++; i++; }
            if (cnt <= 2)        freq[0] += (u16)cnt;
            else if (cnt <= 18)  freq[1]++;
            else                 freq[2]++;
        } else {
            k += 2;
            if (k < NT) freq[k]++;
        }
    }
}

/* write_pt_len: write n code-lengths to the bitstream */
static void
write_pt_len(la, n, nbit, special)
    unsigned char *la;
    int            n;
    int            nbit;
    int            special;
{
    int i, k, cnt;
    while (n > 0 && la[n - 1] == 0) n--;
    putbits(nbit, (u16)n);
    for (i = 0; i < n; i++) {
        k = (int)la[i];
        if (k <= 6)
            putbits(3, (u16)k);
        else {
            /* write (k-3) ones followed by a zero */
            putbits(k - 3, (u16)((((long)1 << (k - 3)) - 1L) << 1));
        }
        if (i == special) {
            /* write one 2-bit count of consecutive zeros that follow;
             * read_pt_len reads this as a count (0..3) to skip. */
            cnt = 0;
            while (cnt < 3 && i + 1 + cnt < n && la[i + 1 + cnt] == 0)
                cnt++;
            putbits(2, (u16)cnt);
            i += cnt;
        }
    }
}

/* write_c_len: write C code-length table using T codes */
static void
write_c_len()
{
    int i, n, k, cnt;

    n = NC;
    while (n > 0 && c_len[n - 1] == 0) n--;
    putbits(CBIT, (u16)n);

    i = 0;
    while (i < n) {
        k = (int)c_len[i++];
        if (k == 0) {
            cnt = 1;
            while (i < n && c_len[i] == 0) { cnt++; i++; }
            if (cnt <= 2) {
                int r;
                for (r = 0; r < cnt; r++)
                    putbits((int)t_len[0], t_code[0]);
            } else if (cnt <= 18) {
                putbits((int)t_len[1], t_code[1]);
                putbits(4, (u16)(cnt - 3));
            } else {
                putbits((int)t_len[2], t_code[2]);
                putbits(CBIT, (u16)(cnt - 20));
            }
        } else {
            k += 2;
            if (k < NT)
                putbits((int)t_len[k], t_code[k]);
        }
    }
}

static void
encode_c(sym)
    int sym;
{
    if (c_len[sym] > 0)
        putbits((int)c_len[sym], c_code[sym]);
}

/* encode_p: encode a match position.
 * Position is represented as a P-code index (floor(log2(pos+1))) plus
 * the remaining bits of the position.
 */
static void
encode_p(pos)
    u16 pos;
{
    int    idx;
    u16    tmp;

    /* find floor(log2(pos+1)) = index into P alphabet */
    idx = 0;
    tmp = pos;
    while (tmp > 0) { tmp >>= 1; idx++; }
    if (idx >= NP) idx = NP - 1;

    putbits((int)p_len[idx], p_code[idx]);
    if (idx >= 2) {
        /* send remaining idx-1 LSBs of pos (the bit below the leading 1) */
        putbits(idx - 1, (u16)(pos & (u16)(((u16)1 << (idx - 1)) - 1)));
    }
}

/* send_block: encode and transmit one buffered block */
static void
send_block()
{
    int i;

    if (blk_cnt == 0) return;

    /* tally C-symbol frequencies */
    for (i = 0; i < NC; i++) freq[i] = 0;
    for (i = 0; i < blk_cnt; i++)
        freq[blk_code[i]]++;

    /* build C Huffman tree */
    build_tree(c_len, c_code, NC);

    /* build T tree (encodes C lengths) */
    count_t_freq();
    build_tree(t_len, t_code, NT);

    /* write block header */
    putbits(16, (u16)blk_cnt);

    /* T-table header */
    write_pt_len(t_len, NT, TBIT, 3);

    /* C-table (encoded with T) */
    write_c_len();

    /* P-table header */
    write_pt_len(p_len, NP, PBIT, -1);

    /* encode symbols */
    for (i = 0; i < blk_cnt; i++) {
        u16 code = blk_code[i];
        encode_c((int)code);
        if (code >= 256)
            encode_p(blk_pos[i]);
    }

    blk_cnt = 0;
}

/* ── decoder ─────────────────────────────────────────────────────────── */

/* read_pt_len: read n code-length entries from the bitstream */
static void
read_pt_len(la, ca, n, nbit, special)
    unsigned char *la;
    u16           *ca;
    int            n;
    int            nbit;
    int            special;
{
    int i, k, m;

    m = (int)getbits(nbit);
    if (m == 0) {
        /* single value — fill everything */
        u16 c = getbits(nbit);
        for (i = 0; i < n; i++) { la[i] = 0; ca[i] = c; }
        return;
    }
    i = 0;
    while (i < m) {
        /* read 3 bits; if 7, read extra to find the actual value */
        k = (int)getbits(3);
        if (k == 7) {
            /* additional 1-bits extend the value */
            fill32(16);
            while ((bitbuf >> (bitsin - 1)) & 1u) {
                SKIPBITS(1);
                k++;
                if (k > 20) break;
            }
            SKIPBITS(1);   /* consume the terminating 0 */
        }
        la[i++] = (unsigned char)k;
        if (i == special + 1) {
            /* run of zeros */
            k = (int)getbits(2);
            while (--k >= 0) la[i++] = 0;
        }
    }
    while (i < n) la[i++] = 0;
    make_codes_from_lens(la, ca, n);
}

static void
read_c_len()
{
    int i, n, k, cnt;

    n = (int)getbits(CBIT);
    if (n == 0) {
        u16 c = getbits(CBIT);
        for (i = 0; i < NC; i++) c_len[i] = 0;
        for (i = 0; i < 512; i++) c_table[i] = c;
        return;
    }

    /* use t_table (256-byte int array) for T-code decode */
    /* first, build a simple lookup from t_len / t_code */
    {
        int j, l;
        for (j = 0; j < 256; j++) t_table[j] = -1;
        for (j = 0; j < NT; j++) {
            l = (int)t_len[j];
            if (l > 0 && l <= 8) {
                int base = (int)t_code[j] << (8 - l);
                int cnt2 = 1 << (8 - l);
                while (cnt2-- > 0) t_table[base++] = j;
            }
        }
    }

    i = 0;
    while (i < n) {
        /* decode one T symbol */
        u16  top8;
        int  tsym;

        fill32(16);
        top8 = (u16)(bitbuf >> (bitsin - 8));
        tsym = t_table[(int)top8];
        if (tsym < 0) {
            /* not found in 8-bit table — try longer */
            int bit;
            tsym = 0;
            for (bit = 0; bit < NT; bit++) {
                if (t_len[bit] == 0) continue;
                if ((u16)(bitbuf >> (bitsin - (int)t_len[bit])) == t_code[bit]) {
                    tsym = bit;
                    break;
                }
            }
        }
        SKIPBITS((int)t_len[tsym]);

        if (tsym <= 2) {
            if (tsym == 0)
                cnt = 1;
            else if (tsym == 1)
                cnt = (int)getbits(4) + 3;
            else
                cnt = (int)getbits(CBIT) + 20;
            while (--cnt >= 0) c_len[i++] = 0;
        } else {
            c_len[i++] = (unsigned char)(tsym - 2);
        }
    }
    while (i < NC) c_len[i++] = 0;
    make_codes_from_lens(c_len, c_code, NC);
    make_c_table();
}

/* decode_c: read one C symbol from the bitstream */
static u16
decode_c()
{
    u16 j;
    u16 top9;

    fill32(16);
    top9 = (u16)(bitbuf >> (bitsin - CBIT));
    j    = c_table[(int)top9];

    if (j == (u16)0xFFFF) {
        /* linear scan fallback */
        int b;
        j = 0;
        for (b = 0; b < NC; b++) {
            int l = (int)c_len[b];
            if (l == 0) continue;
            if ((u16)(bitbuf >> (bitsin - l)) == c_code[b]) { j = (u16)b; break; }
        }
    }
    SKIPBITS((int)c_len[j]);
    return j;
}

/* decode_p: read one P symbol from the bitstream */
static u16
decode_p()
{
    u16  j;
    int  extra;
    u16  top8;

    fill32(16);
    top8 = (u16)(bitbuf >> (bitsin - 8));
    j    = p_table[(int)top8];

    if (j == (u16)0xFFFF) {
        /* linear scan fallback */
        int b;
        j = 0;
        for (b = 0; b < NP; b++) {
            int l = (int)p_len[b];
            if (l == 0) continue;
            if ((u16)(bitbuf >> (bitsin - l)) == p_code[b]) { j = (u16)b; break; }
        }
    }
    SKIPBITS((int)p_len[j]);

    if (j >= 2) {
        extra = (int)getbits((int)j - 1);
        j     = (u16)(((u16)1 << ((int)j - 1)) + (u16)extra);
    }
    return j;
}

/* ── freeze (compress) ───────────────────────────────────────────────── */

static void
do_freeze()
{
    int   i, r, s, lastlen, len;
    int   c;

    init_tree();
    init_p_table();
    blk_cnt = 0;

    /* prime window with spaces */
    memset(text_buf, ' ', (unsigned int)(WSIZE - MAXMATCH));
    r = WSIZE - MAXMATCH;
    s = 0;

    /* fill lookahead buffer (exactly MAXMATCH bytes).
     * The advance loop's text_buf[s+WSIZE] duplication extends the
     * lookahead one byte at a time.  Pre-filling 2*MAXMATCH corrupts
     * the extended region when s < MAXMATCH-1. */
    for (len = 0; len < MAXMATCH; len++) {
        c = read_byte();
        if (c < 0) break;
        text_buf[r + len] = (unsigned char)c;
    }
    /* insert initial tree nodes */
    for (i = 1; i <= MAXMATCH; i++)
        insert_node(r - i);
    insert_node(r);

    while (len > 0) {
        if (match_len > len) match_len = len;

        if (match_len < THRESHOLD) {
            match_len = 1;
            blk_code[blk_cnt]  = (u16)(unsigned char)text_buf[r];
            blk_pos[blk_cnt]   = 0;
        } else {
            int wpos = (r - match_pos - 1) & WMASK;
            blk_code[blk_cnt] = (u16)(256 + match_len - THRESHOLD);
            blk_pos[blk_cnt]  = (u16)wpos;
        }
        blk_cnt++;
        if (blk_cnt == BLOCKSIZE)
            send_block();

        lastlen = match_len;
        for (i = 0; i < lastlen; i++) {
            c = read_byte();
            delete_node(s);
            text_buf[s] = (c < 0) ? (unsigned char)' ' : (unsigned char)c;
            if (s < MAXMATCH - 1)
                text_buf[s + WSIZE] = text_buf[s];
            s = (s + 1) & WMASK;
            r = (r + 1) & WMASK;
            insert_node(r);
            if (c >= 0) len++;
            len--;
        }
    }

    send_block();
    flushbits();
    flush_obuf();
}

/* ── melt (decompress) ───────────────────────────────────────────────── */

static void
do_melt()
{
    static unsigned char  outwin[WSIZE];   /* 4096-byte ring buffer */
    int            r;
    int            blksize;
    int            count;
    u16            c;

    memset(outwin, ' ', WSIZE);
    r = 0;

    /* prime the 32-bit input shift register */
    {
        int k;
        for (k = 0; k < 4; k++) {
            int byte = read_byte();
            if (byte < 0) byte = 0;
            bitbuf = (bitbuf << 8) | (unsigned char)byte;
            bitsin += 8;
        }
    }

    for (;;) {
        /* read block size */
        blksize = (int)getbits(16);
        if (g_in_eof || blksize == 0) break;

        /* read T-table */
        read_pt_len(t_len, t_code, NT, TBIT, 3);

        /* read C-table (uses T) */
        read_c_len();

        /* read P-table */
        read_pt_len(p_len, p_code, NP, PBIT, -1);
        make_p_table();

        /* decode blksize symbols */
        count = 0;
        while (count < blksize) {
            c = decode_c();
            count++;
            if (c < 256) {
                outwin[r] = (unsigned char)c;
                r = (r + 1) & WMASK;
                write_byte((unsigned char)c);
            } else {
                int matchlen = (int)c - 256 + THRESHOLD;
                int dp = (int)decode_p();
                int matchpos = (r - dp - 1) & WMASK;
                int m;
                for (m = 0; m < matchlen; m++) {
                    unsigned char ch = outwin[(matchpos + m) & WMASK];
                    outwin[r] = ch;
                    r = (r + 1) & WMASK;
                    write_byte(ch);
                }
            }
        }
    }

    flush_obuf();
}

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

/* ── process one named file ──────────────────────────────────────────── */

static int
process_file(fname)
    char *fname;
{
    struct stat st;
    int         len;

    infp = open(fname, O_RDONLY);
    if (infp < 0) { perror(fname); return 1; }

    init_io();

    if (decompress_flag) {
        unsigned char hdr[3];
        int nr = read(infp, (char *)hdr, 3);
        if (nr < 3 || hdr[0] != FREEZE_MAGIC_1 || hdr[1] != FREEZE_MAGIC_2) {
            fprintf(stderr, "freeze: %s: not in freeze format\n", fname);
            close(infp); infp = -1; return 1;
        }
        /* hdr[2] = version, tolerate any value */
        len = (int)strlen(fname);
        if (len > 2 && fname[len-2] == '.' && fname[len-1] == 'F') {
            strncpy(ofname, fname, (unsigned int)(len - 2));
            ofname[len - 2] = '\0';
        } else if (len > 7 && strcmp(fname + len - 7, ".freeze") == 0) {
            strncpy(ofname, fname, (unsigned int)(len - 7));
            ofname[len - 7] = '\0';
        } else {
            fprintf(stderr, "freeze: %s: unknown frozen suffix\n", fname);
            close(infp); infp = -1; return 1;
        }
    } else {
        len = (int)strlen(fname);
        if (len + 2 >= (int)sizeof(ofname)) {
            fprintf(stderr, "freeze: %s: filename too long\n", fname);
            close(infp); infp = -1; return 1;
        }
        strcpy(ofname, fname);
        ofname[len]   = '.';
        ofname[len+1] = 'F';
        ofname[len+2] = '\0';
    }

    if (stdout_flag) {
        outfp = 1;
    } else {
        if (!force_flag && stat(ofname, &st) == 0) {
            fprintf(stderr, "freeze: %s already exists; not overwritten\n", ofname);
            close(infp); infp = -1; return 1;
        }
        outfp = open(ofname, O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (outfp < 0) {
            perror(ofname); close(infp); infp = -1; return 1;
        }
    }

    if (!decompress_flag) {
        unsigned char hdr[3];
        hdr[0] = FREEZE_MAGIC_1;
        hdr[1] = FREEZE_MAGIC_2;
        hdr[2] = FREEZE_VERSION;
        if (write(outfp, (char *)hdr, 3) != 3) {
            perror("freeze: write"); close(infp); close(outfp);
            infp = outfp = -1; return 1;
        }
    }

    if (decompress_flag) {
        /* re-init after reading 3 header bytes */
        init_io();
        do_melt();
    } else {
        do_freeze();
    }

    close(infp); infp = -1;
    if (!stdout_flag) { close(outfp); outfp = -1; }
    if (!stdout_flag) unlink(fname);

    return 0;
}

/* ── usage ────────────────────────────────────────────────────────────── */

static void
usage()
{
    fprintf(stderr,
        "usage: freeze [-cfv] [file ...]\n"
        "       melt   [-cfv] [file ...]\n"
        "  -c   write to stdout\n"
        "  -f   force overwrite\n"
        "  -v   verbose\n");
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

    /* Allocate all large tables on the heap. */
    ibuf     = (unsigned char *)malloc((unsigned long)IBUFSZ);
    obuf     = (unsigned char *)malloc((unsigned long)OBUFSZ);
    text_buf = (unsigned char *)malloc((unsigned long)(WSIZE + MAXMATCH));
    lson     = (int *)malloc((unsigned long)WSIZE * sizeof(int));
    rson     = (int *)malloc((unsigned long)(WSIZE + 257) * sizeof(int));
    dad      = (int *)malloc((unsigned long)WSIZE * sizeof(int));
    c_len    = (unsigned char *)malloc((unsigned long)NC);
    c_code   = (u16 *)malloc((unsigned long)NC * sizeof(u16));
    p_len    = (unsigned char *)malloc((unsigned long)NP);
    p_code   = (u16 *)malloc((unsigned long)NP * sizeof(u16));
    t_len    = (unsigned char *)malloc((unsigned long)NT);
    t_code   = (u16 *)malloc((unsigned long)NT * sizeof(u16));
    c_table  = (u16 *)malloc(512UL * sizeof(u16));
    p_table  = (u16 *)malloc(256UL * sizeof(u16));
    freq     = (u16 *)malloc((unsigned long)TMAX * sizeof(u16));
    t_table  = (int *)malloc(256UL * sizeof(int));
    blk_code = (u16 *)malloc((unsigned long)BLOCKSIZE * sizeof(u16));
    blk_pos  = (u16 *)malloc((unsigned long)BLOCKSIZE * sizeof(u16));
    if (!ibuf || !obuf || !text_buf || !lson || !rson || !dad ||
        !c_len || !c_code || !p_len || !p_code || !t_len || !t_code ||
        !c_table || !p_table || !freq || !t_table || !blk_code || !blk_pos) {
        fprintf(stderr, "freeze: out of memory\n");
        exit(1);
    }

    p = argv[0];
    { char *q = strrchr(p, '/'); if (q) p = q + 1; }
    if (strcmp(p, "melt") == 0) decompress_flag = 1;

    while ((ch = getopt(argc, argv, "cfv")) != EOF) {
        switch (ch) {
        case 'c': stdout_flag  = 1; break;
        case 'f': force_flag   = 1; break;
        case 'v': verbose_flag = 1; break;
        default:  usage();
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
        init_io();
        if (decompress_flag) {
            unsigned char hdr[3];
            int nr = read(infp, (char *)hdr, 3);
            if (nr < 3 || hdr[0] != FREEZE_MAGIC_1 || hdr[1] != FREEZE_MAGIC_2) {
                fprintf(stderr, "freeze: stdin: not in freeze format\n");
                exit(1);
            }
            init_io();
            do_melt();
        } else {
            unsigned char hdr[3];
            hdr[0] = FREEZE_MAGIC_1;
            hdr[1] = FREEZE_MAGIC_2;
            hdr[2] = FREEZE_VERSION;
            write(outfp, (char *)hdr, 3);
            do_freeze();
        }
    } else {
        int i;
        for (i = 0; i < argc; i++)
            rc |= process_file(argv[i]);
    }

    free(ibuf); free(obuf); free(text_buf);
    free(lson); free(rson); free(dad);
    free(c_len); free(c_code); free(p_len); free(p_code);
    free(t_len); free(t_code);
    free(c_table); free(p_table); free(freq);
    free(t_table); free(blk_code); free(blk_pos);
    return rc;
}
