/*
 * ktrace.c — Kernel-side ktrace (minimal: ktrace_log only)
 *
 * The kernel only uses KTRACE_LOG().  ktrace_printf/ktrace_trapf/ktrace_fire
 * are stubbed out to satisfy the linker.  Full implementations are in
 * lib/ktrace/ktrace.c for user-space programs.
 */

#pragma optimize 78

#include "ktrace.h"

void ktrace_write(unsigned char code, const char *msg)
{
    unsigned char *dst =
        (unsigned char *)(0xD00000L | ((unsigned long)code << 8));
    unsigned char *limit = dst + 255;
    while (*msg && dst < limit)
        *dst++ = *msg++;
    *dst = '\0';
}

void ktrace_log(const char *msg)
{
    ktrace_write(0x00, msg);
    asm { wdm 0x00 }
}

/* Stubs — not used by the kernel but declared in ktrace.h */
void ktrace_format(unsigned char code, const char *fmt, ...) { (void)code; (void)fmt; }
void ktrace_fire(unsigned char code) { (void)code; }
void ktrace_printf(const char *fmt, ...) { (void)fmt; }
void ktrace_trapf(unsigned char code, const char *fmt, ...) { (void)code; (void)fmt; }
