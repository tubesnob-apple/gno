/*
 * ktrace.h -- Debug trace via WDM traps (GSplus emulator intercept)
 *
 * Protocol:
 *   1. Write a string into bank $D0 at offset (code * 256).
 *   2. Fire WDM with the corresponding code byte.
 *   3. The emulator intercepts the WDM instruction and logs the string.
 *
 * Bank $D0 is beyond the 8MB address range of real Apple IIgs hardware;
 * the emulator intercepts all writes there and buffers them for logging.
 * No RAM is consumed in the program's address space.
 *
 * WDM code ranges:
 *   $00       -- string only (no registers, no halt)
 *   $01-$0F   -- string + CPU registers, no halt
 *   $10-$7F   -- string + CPU registers + halt (breakpoints)
 *
 * Each code owns a 256-byte slot:
 *   code $00  ->  $D0/0000 .. $D0/00FF
 *   code $01  ->  $D0/0100 .. $D0/01FF
 *   code $7F  ->  $D0/7F00 .. $D0/7FFF
 *
 * Usage (user-space or kernel):
 *   #include <ktrace.h>            (user-space, link with libktrace)
 *   #include "ktrace.h"            (kernel, compile ktrace.c into build)
 *
 *   KTRACE_LOG("checkpoint reached");
 *   KTRACE_LOGF("pid=%d path=%s", pid, path);
 *   KTRACE_TRAP(0x01, "register dump here");
 *   KTRACE_TRAP(0x10, "breakpoint: err=%d", err);
 */

#ifndef _KTRACE_H_
#define _KTRACE_H_

/*
 * ktrace_write -- copy a string into $D0/(code*256), null-terminate.
 * Low-level; prefer KTRACE_LOG / KTRACE_LOGF.
 */
void ktrace_write(unsigned char code, const char *msg);

/*
 * ktrace_format -- printf-style write into $D0/(code*256).
 * Supports: %d %u %x  %ld %lu %lx  %s %c %%
 * Max 255 chars.  Does NOT fire WDM -- caller must do that.
 */
void ktrace_format(unsigned char code, const char *fmt, ...);

/*
 * ktrace_fire -- fire WDM with a dynamic code byte (0x00-0x7F).
 * Uses self-modifying code (safe: user/kernel code is always in RAM).
 */
void ktrace_fire(unsigned char code);

/*
 * ktrace_log -- write msg to $D0/0000 and fire WDM $00 (string only).
 */
void ktrace_log(const char *msg);

/*
 * ktrace_printf -- formatted write to $D0/0000 + fire WDM $00.
 * Supports: %d %u %x  %ld %lu %lx  %s %c %%
 */
void ktrace_printf(const char *fmt, ...);

/*
 * ktrace_trapf -- formatted write + fire for a specific trap code.
 * $01-$0F: string + registers, no halt.
 * $10-$7F: string + registers + halt.
 */
void ktrace_trapf(unsigned char code, const char *fmt, ...);

/*
 * Convenience macros (compile to nothing when KTRACE_DISABLE is defined).
 *
 *   KTRACE_LOG(msg)           -- WDM $00, string only
 *   KTRACE_LOGF(fmt, ...)     -- WDM $00, formatted string only
 *   KTRACE_TRAP(code, fmt, ...)  -- WDM code, formatted string
 */
#ifndef KTRACE_DISABLE

#define KTRACE_LOG(msg)              ktrace_log(msg)
#define KTRACE_LOGF(fmt, ...)        ktrace_printf(fmt, __VA_ARGS__)
#define KTRACE_TRAP(code, fmt, ...)  ktrace_trapf(code, fmt, __VA_ARGS__)

#else

#define KTRACE_LOG(msg)              ((void)0)
#define KTRACE_LOGF(fmt, ...)        ((void)0)
#define KTRACE_TRAP(code, fmt, ...)  ((void)0)

#endif /* KTRACE_DISABLE */

#endif /* _KTRACE_H_ */
