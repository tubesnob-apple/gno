/*
 * t_stack_struct.c — struct pass-by-value and return
 * EXPECT: compile success
 *
 * Tests struct layout and calling convention for struct-valued parameters
 * and return values.  Key questions:
 *   - Small structs (<=4 bytes): returned in registers?
 *   - Large structs: caller allocates hidden return-value slot, passes pointer
 *   - Struct pass-by-value: entire struct is copied onto the stack
 *
 * What to look for in the disassembly:
 *   - Small struct return: value loaded directly into A (and X for 4-byte)
 *   - Large struct return: look for hidden pointer param at fixed dp offset
 *   - Struct param: look for block-copy sequence (MVN/MVP or loop)
 *   - Padding: verify struct layout matches sizeof() assertions
 */
#pragma optimize 16

/* ── 2-byte struct ──────────────────────────────────────────────────── */
typedef struct { short x; } S2;

S2 make_s2(short v)         { S2 s; s.x = v; return s; }
short use_s2(S2 s)          { return s.x; }

/* ── 4-byte struct ──────────────────────────────────────────────────── */
typedef struct { short x; short y; } S4;

S4 make_s4(short x, short y){ S4 s; s.x = x; s.y = y; return s; }
short use_s4(S4 s)           { return s.x + s.y; }

/* ── 8-byte struct ──────────────────────────────────────────────────── */
typedef struct { long x; long y; } S8;

S8 make_s8(long x, long y)  { S8 s; s.x = x; s.y = y; return s; }
long use_s8(S8 s)            { return s.x + s.y; }

/* ── larger struct (16 bytes) ───────────────────────────────────────── */
typedef struct {
    long   a;
    long   b;
    short  c;
    short  d;
    long   e;
} S16;

S16 make_s16(long a, long b, short c, short d, long e) {
    S16 s;
    s.a = a; s.b = b; s.c = c; s.d = d; s.e = e;
    return s;
}
long use_s16(S16 s) { return s.a + s.b + s.c + s.d + s.e; }

/* ── nested struct ──────────────────────────────────────────────────── */
typedef struct {
    S4 inner;
    long outer;
} SN;

long use_nested(SN s) { return s.inner.x + s.inner.y + s.outer; }

/* ── static size assertions ─────────────────────────────────────────── */
_Static_assert(sizeof(S2)  == 2,  "S2 size");
_Static_assert(sizeof(S4)  == 4,  "S4 size");
_Static_assert(sizeof(S8)  == 8,  "S8 size");
_Static_assert(sizeof(S16) == 16, "S16 size");
