/*
 * t_stack_int_widths.c — ABI parameter and return value widths
 * EXPECT: compile success
 *
 * Tests that ORCA/C correctly handles 8/16/32-bit integer parameters and
 * return values.  On the 65816, all stack slots are 2 bytes wide; char and
 * short params are promoted to 16-bit before being pushed.  long is 4 bytes
 * (two stack slots).  long long is 8 bytes (four stack slots).
 *
 * What to look for in the disassembly:
 *   - char/short params: function body accesses them as 16-bit (no sign-
 *     extension dance at the call site)
 *   - long params: loaded with LDA dp,X (2 bytes) + LDA dp+2,X (2 bytes)
 *   - Return values: char/short in A (16-bit), long in A:X (32-bit)
 *   - Frame setup: pha; tsc; phd; tcd  at function entry
 *   - Frame teardown: pld; tsc; clc; adc #n; tcs before every rtl/rts
 */
#pragma optimize 16      /* enable C99 mixed declarations */

/* ── 8-bit (char) ──────────────────────────────────────────────────── */
char cadd(char a, char b)      { return a + b; }
unsigned char ucadd(unsigned char a, unsigned char b) { return a + b; }

/* ── 16-bit (short / int) ───────────────────────────────────────────── */
short sadd(short a, short b)   { return a + b; }
int   iadd(int a, int b)       { return a + b; }

/* ── 32-bit (long) ──────────────────────────────────────────────────── */
long  ladd(long a, long b)     { return a + b; }
unsigned long uladd(unsigned long a, unsigned long b) { return a + b; }

/* ── 64-bit (long long) ─────────────────────────────────────────────── */
long long lladd(long long a, long long b) { return a + b; }

/* ── mixed widths ───────────────────────────────────────────────────── */
long mixed(char c, short s, int i, long l) {
    return c + s + i + l;
}

/* ── return value widths ────────────────────────────────────────────── */
char    ret_char(void)      { return 42; }
short   ret_short(void)     { return 1000; }
int     ret_int(void)       { return 32767; }
long    ret_long(void)      { return 100000L; }
long long ret_longlong(void){ return 0x123456789ABCLL; }

/* ── pointer-sized (same as long on IIgs — 32-bit) ─────────────────── */
void *ret_ptr(void *p)      { return p; }
