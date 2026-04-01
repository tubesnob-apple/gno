/*
 * t_stack_recursion.c — recursive functions, per-frame independence
 * EXPECT: compile success
 *
 * Tests that each recursive invocation gets its own independent stack frame
 * and direct-page context.  The ORCA/C frame model (dp = frame base) must
 * create a new dp value at each recursive call; the pld on return restores
 * the caller's dp so its locals are still accessible.
 *
 * What to look for in the disassembly:
 *   - tcd sets dp fresh on each entry (so each frame has unique dp)
 *   - pld on each exit restores the caller's dp
 *   - Recursive JSL does not corrupt the current frame's locals
 *   - Stack depth = O(recursion depth) — each frame is properly sized
 */
#pragma optimize 16

/* Classic recursion — simple depth test */
int factorial(int n) {
    if (n <= 1)
        return 1;
    return n * factorial(n - 1);
}

/* Fibonacci — two recursive calls, tests that first call's return value
   survives the second recursive call without corruption */
long fibonacci(int n) {
    if (n <= 1)
        return (long)n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

/* Mutual recursion — tests that the direct page is correctly restored
   when control passes between two different functions */
static int is_even(int n);
static int is_odd(int n);

static int is_even(int n) {
    if (n == 0) return 1;
    return is_odd(n - 1);
}

static int is_odd(int n) {
    if (n == 0) return 0;
    return is_even(n - 1);
}

int test_mutual(int n) {
    return is_even(n);
}

/* Recursive with non-trivial locals — each frame has 3 longs */
long sum_to(long n) {
    if (n <= 0)
        return 0;
    long sub  = sum_to(n - 1);
    long here = n;
    long res  = sub + here;
    return res;
}
