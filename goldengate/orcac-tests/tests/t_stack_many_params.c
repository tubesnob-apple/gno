/*
 * t_stack_many_params.c — functions with many parameters
 * EXPECT: compile success
 *
 * Tests that the compiler correctly handles 8+ parameters, all of which
 * live on the stack.  On the 65816 there are no register-passed arguments;
 * every parameter is pushed by the caller and cleaned up by the caller
 * (cdecl-like) or the callee depending on ORCA/C ABI.
 *
 * What to look for in the disassembly:
 *   - Caller: N push instructions before the JSL
 *   - Callee: direct-page accesses at correct offsets for each param
 *   - Stack frame size = sum of param widths + return address (3 bytes for RTL)
 *   - Frame teardown: adc #n cleans up ALL pushed bytes
 *   - No stack residue after return
 */
#pragma optimize 16

/* 8 int params — 16 bytes of args on stack */
int sum8(int a, int b, int c, int d, int e, int f, int g, int h) {
    return a + b + c + d + e + f + g + h;
}

/* 8 long params — 32 bytes of args on stack */
long lsum8(long a, long b, long c, long d,
           long e, long f, long g, long h) {
    return a + b + c + d + e + f + g + h;
}

/* Mixed widths: char, short, int, long, char, short, int, long */
long mixed8(char a, short b, int c, long d,
            char e, short f, int g, long h) {
    return a + b + c + d + e + f + g + h;
}

/* Many params with pointer and non-pointer interleaved */
long interleaved(int a, void *p1, int b, void *p2, int c) {
    (void)p1;
    (void)p2;
    return a + b + c;
}

/* 12 int params */
int sum12(int a, int b, int c, int d,
          int e, int f, int g, int h,
          int i, int j, int k, int l) {
    return a + b + c + d + e + f + g + h + i + j + k + l;
}
