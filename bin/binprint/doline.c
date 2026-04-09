/*
 * doline.c -- pure-C replacement for doline.asm
 *
 * Formats one hex-dump line into dest (the hex section) and modifies
 * source in-place with the printable-ASCII section + trailing CR.
 *
 * dest and source are adjacent regions of the same caller-allocated
 * buffer:  dest = buffer2,  source = buffer2 + cols*3.
 *
 * Call convention (matches binprint.c's doline() call):
 *   doline(dest, source, cols, actual)
 *   -- cols:   number of columns (bytes per line) for formatting
 *   -- actual: number of bytes actually present in source this line
 *
 * Returns total bytes to write starting at dest:
 *   cols*3  (hex section: 2 hex digits + space per column)
 * + actual  (ASCII chars written back into source[0..actual-1])
 * + 1       (CR written into source[actual])
 */

unsigned int
doline(char *dest, char *source, unsigned int cols, unsigned int actual)
{
    static const char hexdigits[] = "0123456789ABCDEF";
    unsigned int i;
    char *p = dest;
    unsigned char *src = (unsigned char *)source;

    /* Hex section: 2 hex digits + space per byte, padded to cols */
    for (i = 0; i < actual; i++) {
        *p++ = hexdigits[(src[i] >> 4) & 0xf];
        *p++ = hexdigits[src[i] & 0xf];
        *p++ = ' ';
    }
    for (i = actual; i < cols; i++) {
        *p++ = ' ';
        *p++ = ' ';
        *p++ = ' ';
    }

    /* ASCII section: replace non-printable bytes with '.', write CR */
    for (i = 0; i < actual; i++) {
        unsigned char c = src[i];
        src[i] = (c >= 0x20 && c < 0x7f) ? c : '.';
    }
    src[actual] = '\r';

    return cols * 3 + actual + 1;
}
