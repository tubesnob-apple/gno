/*
 * ktrace.c -- Debug trace via WDM traps (GSplus emulator intercept)
 *
 * Provides formatted string output to the emulator's debug log via
 * bank $D0 write + WDM instruction.  Works from both kernel and
 * user-space code.
 *
 * For user-space: compile and link as libktrace.
 * For kernel: compile directly into the kernel build (segment KERN2).
 */

#ifdef KERNEL
#define KERNEL_WAS_DEFINED
#endif

#pragma optimize 78

#include "ktrace.h"
#include <stdarg.h>

/* ------------------------------------------------------------------ */
/* Core write: copy string into $D0/(code*256)                        */
/* ------------------------------------------------------------------ */

void ktrace_write(unsigned char code, const char *msg)
{
    unsigned char *dst =
        (unsigned char *)(0xD00000L | ((unsigned long)code << 8));
    unsigned char *limit = dst + 255;

    while (*msg && dst < limit)
        *dst++ = *msg++;
    *dst = '\0';
}

/* ------------------------------------------------------------------ */
/* WDM fire: execute WDM with a dynamic code byte                     */
/*                                                                    */
/* The WDM operand is a literal byte in the instruction stream.       */
/* To fire a dynamic code, we use self-modifying code: write the      */
/* code byte into the WDM instruction before executing it.            */
/* This is safe because all GNO code runs from RAM.                   */
/* ------------------------------------------------------------------ */

void ktrace_fire(unsigned char code)
{
    asm {
        sep  #0x20          /* 8-bit accumulator */
        lda  code
        sta  _wdm_site+1    /* patch the WDM operand byte */
        rep  #0x20          /* back to 16-bit */
    _wdm_site:
        wdm  0x00           /* operand patched above */
    }
}

/* ------------------------------------------------------------------ */
/* Integer-to-string helpers (no stdlib dependency)                    */
/* ------------------------------------------------------------------ */

static unsigned char *_u16_dec(unsigned char *d, unsigned char *limit,
                               unsigned val)
{
    char tmp[6];
    int i = 0;
    if (val == 0) { if (d < limit) *d++ = '0'; return d; }
    while (val && i < 6) { tmp[i++] = '0' + (val % 10); val /= 10; }
    while (i-- > 0 && d < limit) *d++ = tmp[i];
    return d;
}

static unsigned char *_u32_dec(unsigned char *d, unsigned char *limit,
                               unsigned long val)
{
    char tmp[11];
    int i = 0;
    if (val == 0) { if (d < limit) *d++ = '0'; return d; }
    while (val && i < 11) { tmp[i++] = '0' + (int)(val % 10); val /= 10; }
    while (i-- > 0 && d < limit) *d++ = tmp[i];
    return d;
}

static unsigned char *_u16_hex(unsigned char *d, unsigned char *limit,
                               unsigned val)
{
    static const char hx[] = "0123456789ABCDEF";
    char tmp[4];
    int i = 0;
    if (val == 0) { if (d < limit) *d++ = '0'; return d; }
    while (val && i < 4) { tmp[i++] = hx[val & 0xF]; val >>= 4; }
    while (i-- > 0 && d < limit) *d++ = tmp[i];
    return d;
}

static unsigned char *_u32_hex(unsigned char *d, unsigned char *limit,
                               unsigned long val)
{
    static const char hx[] = "0123456789ABCDEF";
    char tmp[8];
    int i = 0;
    if (val == 0) { if (d < limit) *d++ = '0'; return d; }
    while (val && i < 8) { tmp[i++] = hx[val & 0xF]; val >>= 4; }
    while (i-- > 0 && d < limit) *d++ = tmp[i];
    return d;
}

/* ------------------------------------------------------------------ */
/* Formatted write: printf-style into $D0/(code*256)                  */
/* Supports: %d %u %x  %ld %lu %lx  %s %c %%                        */
/* ------------------------------------------------------------------ */

void ktrace_format(unsigned char code, const char *fmt, ...)
{
    va_list ap;
    unsigned char *d =
        (unsigned char *)(0xD00000L | ((unsigned long)code << 8));
    unsigned char *limit = d + 255;
    const char *s;
    int ival;
    unsigned uval;
    long lval;
    unsigned long ulval;
    int is_long;

    va_start(ap, fmt);

    while (*fmt && d < limit) {
        if (*fmt != '%') { *d++ = *fmt++; continue; }
        fmt++;  /* skip '%' */

        is_long = 0;
        if (*fmt == 'l') { is_long = 1; fmt++; }

        switch (*fmt) {
        case 'd':
            if (is_long) {
                lval = va_arg(ap, long);
                if (lval < 0) { if (d < limit) *d++ = '-'; ulval = (unsigned long)(-lval); }
                else           ulval = (unsigned long)lval;
                d = _u32_dec(d, limit, ulval);
            } else {
                ival = va_arg(ap, int);
                if (ival < 0) { if (d < limit) *d++ = '-'; uval = (unsigned)(-ival); }
                else           uval = (unsigned)ival;
                d = _u16_dec(d, limit, uval);
            }
            break;
        case 'u':
            if (is_long) { ulval = va_arg(ap, unsigned long); d = _u32_dec(d, limit, ulval); }
            else          { uval  = va_arg(ap, unsigned);      d = _u16_dec(d, limit, uval);  }
            break;
        case 'x':
            if (is_long) { ulval = va_arg(ap, unsigned long); d = _u32_hex(d, limit, ulval); }
            else          { uval  = va_arg(ap, unsigned);      d = _u16_hex(d, limit, uval);  }
            break;
        case 's':
            s = va_arg(ap, const char *);
            if (!s) s = "(null)";
            while (*s && d < limit) *d++ = *s++;
            break;
        case 'c':
            ival = va_arg(ap, int);
            if (d < limit) *d++ = (unsigned char)ival;
            break;
        case '%':
            if (d < limit) *d++ = '%';
            break;
        default:
            if (d < limit) *d++ = *fmt;
            break;
        }
        fmt++;
    }

    va_end(ap);
    *d = '\0';
}

/* ------------------------------------------------------------------ */
/* High-level API                                                     */
/* ------------------------------------------------------------------ */

void ktrace_log(const char *msg)
{
    ktrace_write(0x00, msg);
    asm { wdm 0x00 }
}

void ktrace_printf(const char *fmt, ...)
{
    /* Re-implement to avoid double va_list forwarding issues on 65816.
     * ktrace_format uses its own va_list, so we duplicate the call
     * to va_start here and call the low-level write directly. */
    va_list ap;
    unsigned char *d = (unsigned char *)0xD00000L;
    unsigned char *limit = d + 255;
    const char *s;
    int ival;
    unsigned uval;
    long lval;
    unsigned long ulval;
    int is_long;

    va_start(ap, fmt);

    while (*fmt && d < limit) {
        if (*fmt != '%') { *d++ = *fmt++; continue; }
        fmt++;

        is_long = 0;
        if (*fmt == 'l') { is_long = 1; fmt++; }

        switch (*fmt) {
        case 'd':
            if (is_long) {
                lval = va_arg(ap, long);
                if (lval < 0) { if (d < limit) *d++ = '-'; ulval = (unsigned long)(-lval); }
                else           ulval = (unsigned long)lval;
                d = _u32_dec(d, limit, ulval);
            } else {
                ival = va_arg(ap, int);
                if (ival < 0) { if (d < limit) *d++ = '-'; uval = (unsigned)(-ival); }
                else           uval = (unsigned)ival;
                d = _u16_dec(d, limit, uval);
            }
            break;
        case 'u':
            if (is_long) { ulval = va_arg(ap, unsigned long); d = _u32_dec(d, limit, ulval); }
            else          { uval  = va_arg(ap, unsigned);      d = _u16_dec(d, limit, uval);  }
            break;
        case 'x':
            if (is_long) { ulval = va_arg(ap, unsigned long); d = _u32_hex(d, limit, ulval); }
            else          { uval  = va_arg(ap, unsigned);      d = _u16_hex(d, limit, uval);  }
            break;
        case 's':
            s = va_arg(ap, const char *);
            if (!s) s = "(null)";
            while (*s && d < limit) *d++ = *s++;
            break;
        case 'c':
            ival = va_arg(ap, int);
            if (d < limit) *d++ = (unsigned char)ival;
            break;
        case '%':
            if (d < limit) *d++ = '%';
            break;
        default:
            if (d < limit) *d++ = *fmt;
            break;
        }
        fmt++;
    }

    va_end(ap);
    *d = '\0';
    asm { wdm 0x00 }
}

void ktrace_trapf(unsigned char code, const char *fmt, ...)
{
    va_list ap;
    unsigned char *d =
        (unsigned char *)(0xD00000L | ((unsigned long)code << 8));
    unsigned char *limit = d + 255;
    const char *s;
    int ival;
    unsigned uval;
    long lval;
    unsigned long ulval;
    int is_long;

    va_start(ap, fmt);

    while (*fmt && d < limit) {
        if (*fmt != '%') { *d++ = *fmt++; continue; }
        fmt++;

        is_long = 0;
        if (*fmt == 'l') { is_long = 1; fmt++; }

        switch (*fmt) {
        case 'd':
            if (is_long) {
                lval = va_arg(ap, long);
                if (lval < 0) { if (d < limit) *d++ = '-'; ulval = (unsigned long)(-lval); }
                else           ulval = (unsigned long)lval;
                d = _u32_dec(d, limit, ulval);
            } else {
                ival = va_arg(ap, int);
                if (ival < 0) { if (d < limit) *d++ = '-'; uval = (unsigned)(-ival); }
                else           uval = (unsigned)ival;
                d = _u16_dec(d, limit, uval);
            }
            break;
        case 'u':
            if (is_long) { ulval = va_arg(ap, unsigned long); d = _u32_dec(d, limit, ulval); }
            else          { uval  = va_arg(ap, unsigned);      d = _u16_dec(d, limit, uval);  }
            break;
        case 'x':
            if (is_long) { ulval = va_arg(ap, unsigned long); d = _u32_hex(d, limit, ulval); }
            else          { uval  = va_arg(ap, unsigned);      d = _u16_hex(d, limit, uval);  }
            break;
        case 's':
            s = va_arg(ap, const char *);
            if (!s) s = "(null)";
            while (*s && d < limit) *d++ = *s++;
            break;
        case 'c':
            ival = va_arg(ap, int);
            if (d < limit) *d++ = (unsigned char)ival;
            break;
        case '%':
            if (d < limit) *d++ = '%';
            break;
        default:
            if (d < limit) *d++ = *fmt;
            break;
        }
        fmt++;
    }

    va_end(ap);
    *d = '\0';
    ktrace_fire(code);
}
