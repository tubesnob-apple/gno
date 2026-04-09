/*
 * Copyright (c) 1989, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Dave Borman at Cray Research, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.
 *
 * setmode.c -- BSD symbolic mode string parsing for GNO/ME.
 * Derived from 4.4BSD-Lite2 lib/libc/gen/setmode.c
 *
 * ORCA/C (65816) notes:
 *   - int = 16 bits; mode_t = unsigned short (16 bits)
 *   - No C99; K&R declarations used for function parameters
 */

#ifdef __ORCAC__
/* #pragma memorymodel 1 — removed: ABI mismatch with GNO libc */
#endif

#include <sys/types.h>
#include <sys/stat.h>

#include <errno.h>
#include <setjmp.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/*
 * A parsed mode clause.  The opaque buffer returned by setmode()
 * is an array of MODECMD terminated by one with op == 0.
 */
typedef struct {
    mode_t  who;    /* affected bits (the WHO mask) */
    char    op;     /* '+', '-', '=', 'X', or 0 for end */
    char    copy;   /* 0, or 'u','g','o' (copy-from-src) */
    mode_t  perm;   /* permission bits (within who mask) */
} MODECMD;

#define MAXCMDS 32

/* Parse error escape */
static jmp_buf  parse_err;

static void
synerr()
{
    longjmp(parse_err, 1);
}

/*
 * Map a who-character to an rwx mask in all three positions,
 * plus the suid/sgid/sticky bits that belong to it.
 */
static mode_t
who2bits(c)
    int c;
{
    switch (c) {
    case 'u': return S_ISUID | S_IRWXU;
    case 'g': return S_ISGID | S_IRWXG;
    case 'o': return S_IRWXO;
    }
    return 0;
}

/*
 * Map r/w/x/s/t permission character to raw bits (all positions).
 */
static mode_t
perm2bits(c)
    int c;
{
    switch (c) {
    case 'r': return S_IRUSR | S_IRGRP | S_IROTH;
    case 'w': return S_IWUSR | S_IWGRP | S_IWOTH;
    case 'x': return S_IXUSR | S_IXGRP | S_IXOTH;
    case 's': return S_ISUID | S_ISGID;
    case 't': return S_ISTXT;
    }
    return 0;
}

/*
 * setmode --
 *	Parse a symbolic mode string into an opaque array that getmode()
 *	can apply.  Returns malloc'd storage the caller must free(), or
 *	NULL on parse error.
 *
 *	Numeric (octal) mode strings are NOT handled here — chmod.c
 *	calls strtol() for those and only calls setmode() for symbolic.
 */
void *
setmode(mode_str)
    const char *mode_str;
{
    const char *p;
    MODECMD *set, *cur;
    unsigned int umask_val;
    mode_t allwho, who;
    char op;
    mode_t perm, bits;
    int have_x;

    if ((set = (MODECMD *)calloc((size_t)MAXCMDS, sizeof(MODECMD))) == NULL)
        return (NULL);

    if (setjmp(parse_err)) {
        free(set);
        return (NULL);
    }

    /* Get umask (for implicit 'a' with masking) */
    umask_val = (unsigned int)umask(0);
    (void)umask((mode_t)umask_val);

    /* allwho = all mode bits not blocked by umask */
    allwho = (mode_t)(~umask_val &
                      (S_ISUID | S_ISGID | S_ISTXT |
                       S_IRWXU | S_IRWXG | S_IRWXO));

    cur = set;
    p = mode_str;

    for (;;) {
        /* --- parse who --- */
        who = 0;
        for (;;) {
            if (*p == 'a') {
                who = S_ISUID | S_ISGID | S_ISTXT |
                      S_IRWXU | S_IRWXG | S_IRWXO;
                ++p;
            } else if (*p == 'u' || *p == 'g' || *p == 'o') {
                who |= who2bits(*p);
                ++p;
            } else {
                break;
            }
        }

        /* --- parse op --- */
        op = *p++;
        if (op != '+' && op != '-' && op != '=')
            synerr();

        /* If no explicit who, apply to all (modulated by umask for +/-) */
        if (who == 0)
            who = S_ISUID | S_ISGID | S_ISTXT |
                  S_IRWXU | S_IRWXG | S_IRWXO;

        /* --- parse perm(s) --- */
        perm = 0;
        have_x = 0;
        for (;;) {
            char pc = *p;
            if (pc == 'r' || pc == 'w' || pc == 'x' ||
                pc == 's' || pc == 't') {
                perm |= perm2bits(pc) & who;
                ++p;
            } else if (pc == 'X') {
                have_x = 1;
                ++p;
            } else if (pc == 'u' || pc == 'g' || pc == 'o') {
                /* copy-from: e.g. "go=u" */
                if (cur - set + 3 >= MAXCMDS)
                    synerr();
                /* For '=': first clear the who bits */
                if (op == '=') {
                    cur->who  = who;
                    cur->op   = '-';
                    cur->copy = 0;
                    cur->perm = who;
                    cur++;
                }
                cur->who  = who;
                cur->op   = (op == '-') ? '-' : '+';
                cur->copy = pc;   /* source: u, g, or o */
                cur->perm = who;
                cur++;
                ++p;
                goto next_clause;
            } else {
                break;
            }
        }

        /* --- emit BITCMD(s) --- */
        if (cur - set + 4 >= MAXCMDS)
            synerr();

        if (op == '=') {
            /* Clear all who bits, then set perm */
            cur->who  = who;
            cur->op   = '-';
            cur->copy = 0;
            cur->perm = who;  /* clear everything in who */
            cur++;
            if (perm) {
                cur->who  = who;
                cur->op   = '+';
                cur->copy = 0;
                cur->perm = perm & who;
                cur++;
            }
        } else if (perm) {
            /* Apply mask: if no explicit who given, apply umask */
            bits = perm;
            if (/* implicit 'a' */ (who == (mode_t)(S_ISUID|S_ISGID|S_ISTXT|S_IRWXU|S_IRWXG|S_IRWXO)))
                bits &= allwho;
            cur->who  = who;
            cur->op   = op;
            cur->copy = 0;
            cur->perm = bits & who;
            cur++;
        }
        if (have_x) {
            cur->who  = who;
            cur->op   = 'X';
            cur->copy = 0;
            cur->perm = (mode_t)(S_IXUSR | S_IXGRP | S_IXOTH) & who;
            if (op == '-')
                cur->op = 'Y';  /* conditional remove: not standard, skip */
            else
                cur++;
        }

    next_clause:
        if (*p == ',') {
            ++p;
            if (*p == '\0')
                synerr();
        } else if (*p == '\0') {
            break;
        } else {
            synerr();
        }
    }

    /* Terminator */
    cur->op = 0;
    return ((void *)set);
}

/*
 * getmode --
 *	Apply the mode changes encoded by setmode() to omode.
 *	Returns the resulting mode.
 */
mode_t
getmode(bbox, omode)
    const void *bbox;
    mode_t omode;
{
    const MODECMD *set;
    mode_t newmode;
    mode_t copybits;

    set = (const MODECMD *)bbox;
    newmode = omode;

    for (; set->op != 0; ++set) {
        switch (set->op) {
        case '+':
            if (set->copy == 0) {
                newmode |= set->perm;
            } else {
                copybits = 0;
                switch (set->copy) {
                case 'u':
                    if (omode & S_IRUSR) copybits |= S_IRGRP | S_IROTH;
                    if (omode & S_IWUSR) copybits |= S_IWGRP | S_IWOTH;
                    if (omode & S_IXUSR) copybits |= S_IXGRP | S_IXOTH;
                    break;
                case 'g':
                    if (omode & S_IRGRP) copybits |= S_IRUSR | S_IROTH;
                    if (omode & S_IWGRP) copybits |= S_IWUSR | S_IWOTH;
                    if (omode & S_IXGRP) copybits |= S_IXUSR | S_IXOTH;
                    break;
                case 'o':
                    if (omode & S_IROTH) copybits |= S_IRUSR | S_IRGRP;
                    if (omode & S_IWOTH) copybits |= S_IWUSR | S_IWGRP;
                    if (omode & S_IXOTH) copybits |= S_IXUSR | S_IXGRP;
                    break;
                }
                newmode |= copybits & set->perm;
            }
            break;
        case '-':
            newmode &= ~set->perm;
            break;
        case 'X':
            /* Conditional execute: only if already executable or dir */
            if ((omode & (S_IXUSR | S_IXGRP | S_IXOTH)) ||
                S_ISDIR(omode))
                newmode |= set->perm;
            break;
        }
    }
    return (newmode);
}
