/*
 * t_stack_nested.c — nested function calls, frame restoration
 * EXPECT: compile success
 *
 * Tests that deep call chains correctly save and restore the direct-page
 * register at each frame level.  On the 65816 ORCA/C ABI, each function
 * uses the direct page as its frame pointer; every callee must save/restore
 * it so callers still see their own frame after the call returns.
 *
 * What to look for in the disassembly:
 *   - Every function: phd near entry, pld near every exit path
 *   - No function uses direct page without first doing tcd to set it
 *   - After deeply nested call, caller's dp is intact (pld restored it)
 *   - Stack pointer is balanced: each frame's adc #n matches its locals
 */
#pragma optimize 16

static int leaf(int x) {
    return x * 2;
}

static int level2(int x) {
    return leaf(x + 1) + leaf(x - 1);
}

static int level3(int x) {
    return level2(x + 1) + level2(x - 1);
}

int deep_call(int x) {
    return level3(x) + level3(x + 100);
}

/* Nested calls with locals at each level — stresses dp save/restore */
static long leaf_with_locals(long x) {
    long tmp = x * x;
    return tmp + 1;
}

static long mid_with_locals(long x) {
    long a = leaf_with_locals(x);
    long b = leaf_with_locals(x + 1);
    return a + b;
}

long deep_with_locals(long x) {
    long r1 = mid_with_locals(x);
    long r2 = mid_with_locals(x * 2);
    long r3 = mid_with_locals(x * 3);
    return r1 + r2 + r3;
}

/* Nested calls across mixed types */
static short narrow(int a, int b) { return (short)(a - b); }
static int   medium(long a)       { return (int)(a & 0xFFFF); }

long cross_type_chain(long input) {
    int   mid = medium(input);
    short low = narrow(mid, 100);
    return (long)low * mid;
}
