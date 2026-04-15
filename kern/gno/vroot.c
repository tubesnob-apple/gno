/*
 * vroot.c — Virtual filesystem root helper for phase B.
 *
 * Supports the `cd /; ls /` use case by presenting the set of mounted
 * block-device volumes as a synthetic directory at the path "/".  This
 * file is called from kern/gno/gsos.asm's GNOOpen / PGClose /
 * GNORefCommon intercepts when they detect a request against "/" or
 * a refNum in the reserved fake-refNum range ($FE00..$FE03).
 *
 * State is heap-allocated only while a reader has "/" open; the fixed
 * cost in the kernel BSS is a 4-entry pointer table (16 bytes).  Up to
 * 4 concurrent readers are supported, which is far more than any
 * realistic gsh session will ever need.
 *
 * Entry points (all called via jsl from gsos.asm):
 *
 *   word vroot_open(void)
 *       Allocate a slot + heap buffer, snapshot the current volume
 *       list via DInfo/Volume.  Returns $FE00+slot on success,
 *       0 on failure (no free slot or out of memory).
 *
 *   void vroot_close(word refNum)
 *       Free the slot's heap buffer.  No-op if refNum is outside the
 *       fake range or already closed.
 *
 *   word vroot_is_fake(word refNum)
 *       Returns nonzero if refNum is in the fake range AND the slot
 *       is currently allocated.  Used by the asm intercepts to decide
 *       whether to handle a call locally or pass through.
 *
 *   word vroot_dirent(word refNum, char *nameBuf, word nameBufSize)
 *       Emit the next volume as a GetDirEntry response.  Copies a
 *       null-terminated volume name into nameBuf (up to nameBufSize-1
 *       bytes, always null-terminated).  Returns 0 on success,
 *       $43 (bad refnum) if refNum is stale, $46 (file not found =
 *       end-of-directory sentinel) when there are no more volumes.
 */

#define KERNEL
#pragma optimize 79
segment "KERN2     ";

#include "proc.h"
#include "sys.h"
#include <stdlib.h>
#include <string.h>
#include <gsos.h>

extern int OldGSOSSt(word callnum, void *pBlock);

/* Reserved refNum range for virtual-root slots.  Must be a positive
 * value when interpreted as int16_t so libc fd checks like `fd <= 0`
 * in ls.c don't mistake it for an error return.  $7F00 is well above
 * any real GS/OS refNum (rarely more than a few hundred) and still
 * positive. */
#define VROOT_FAKE_BASE  0x7F00
#define VROOT_SLOT_COUNT 4
#define VROOT_MAX_VOLS   16
#define VROOT_NAME_LEN   32

typedef struct {
    word walkIndex;   /* next entry GetDirEntry will emit */
    word nVols;       /* volumes captured at open time */
    char names[VROOT_MAX_VOLS][VROOT_NAME_LEN];
} vroot_buf;

static vroot_buf *vroot_slots[VROOT_SLOT_COUNT] = { 0, 0, 0, 0 };

/*
 * Build the list of mounted volumes by iterating DInfo for every
 * available device number and calling Volume on each block device
 * with media present.  Stores up to VROOT_MAX_VOLS names.
 */
static void vroot_enum(vroot_buf *buf)
{
    DInfoRecGS dinfo;
    VolumeRecGS vol;
    ResultBuf32 devNameBuf;
    ResultBuf255 volNameBuf;
    GSString32 devNameCopy;
    word devNum;
    word nameLen;
    word terr;

    buf->nVols = 0;
    buf->walkIndex = 0;

    for (devNum = 1; devNum <= 32 && buf->nVols < VROOT_MAX_VOLS; devNum++) {
        /* DInfo: get device name by device number.  OldGSOSSt returns
         * the error code as its int return value. */
        dinfo.pCount = 3;
        dinfo.devNum = devNum;
        devNameBuf.bufSize = sizeof(devNameBuf);
        dinfo.devName = (ResultBuf32Ptr) &devNameBuf;
        terr = OldGSOSSt(0x202C, &dinfo);
        if (terr != 0) break;   /* ran past end of device table */

        /* Copy the devName into a plain GSString32 input for Volume */
        {
            word len = devNameBuf.bufString.length;
            word i;
            if (len > 31) len = 31;
            devNameCopy.length = len;
            for (i = 0; i < len; i++)
                devNameCopy.text[i] = devNameBuf.bufString.text[i];
        }

        /* Volume: get mounted volume name by device name.  If the
         * device has no media or isn't a filesystem volume, Volume
         * returns an error and we skip it. */
        vol.pCount = 2;
        vol.devName = &devNameCopy;
        volNameBuf.bufSize = sizeof(volNameBuf);
        vol.volName = (ResultBuf255Ptr) &volNameBuf;
        terr = OldGSOSSt(0x2008, &vol);
        if (terr != 0) continue;  /* no media or not a mounted volume */

        /* Copy the volume name as a null-terminated C string.  Volume
         * returns the name prefixed with ':' (e.g. ":GNO"); strip it. */
        {
            word srcLen = volNameBuf.bufString.length;
            char *src = volNameBuf.bufString.text;
            word i;
            if (srcLen > 0 && src[0] == ':') {
                src++;
                srcLen--;
            }
            if (srcLen >= VROOT_NAME_LEN) srcLen = VROOT_NAME_LEN - 1;
            for (i = 0; i < srcLen; i++)
                buf->names[buf->nVols][i] = src[i];
            buf->names[buf->nVols][srcLen] = 0;
        }
        buf->nVols++;
    }
}

word vroot_open(void)
{
    word slot;
    vroot_buf *buf;

    for (slot = 0; slot < VROOT_SLOT_COUNT; slot++) {
        if (vroot_slots[slot] == 0) break;
    }
    if (slot == VROOT_SLOT_COUNT) return 0;      /* table full */

    buf = (vroot_buf *) malloc((long) sizeof(vroot_buf));
    if (buf == 0) return 0;                       /* out of memory */

    vroot_enum(buf);
    vroot_slots[slot] = buf;
    return VROOT_FAKE_BASE + slot;
}

void vroot_close(word refNum)
{
    word slot;

    if (refNum < VROOT_FAKE_BASE) return;
    slot = refNum - VROOT_FAKE_BASE;
    if (slot >= VROOT_SLOT_COUNT) return;
    if (vroot_slots[slot] == 0) return;

    free(vroot_slots[slot]);
    vroot_slots[slot] = 0;
}

/*
 * Write a GS/OS-format length-prefix string into the ResultBuf255 that
 * lives at *nameResPtr.  nameResPtr itself is the word[5,6] pair from
 * the caller's DirEntryRecGS PB — so we need to reconstruct it from
 * its low and high halves, then poke bufString.length and bufString.text
 * via plain byte arithmetic (ORCA/C's pointer-from-longword cast is
 * reliable enough for this).
 */
static void vroot_write_name(word loAddr, word hiAddr, const char *name)
{
    longword addr = ((longword) hiAddr << 16) | (longword) loAddr;
    char *buf;
    word maxText;
    word *lenField;
    char *textField;
    word len;
    word i;

    if (addr == 0) return;
    buf = (char *) addr;
    maxText = *((word *) buf);      /* bufSize at offset 0 */
    lenField = (word *)(buf + 2);   /* bufString.length at offset 2 */
    textField = buf + 4;            /* bufString.text at offset 4 */

    len = strlen(name);
    if (maxText < 2) { *lenField = 0; return; }
    if (len > maxText - 2) len = maxText - 2;
    *lenField = len;
    for (i = 0; i < len; i++)
        textField[i] = name[i];
}

/*
 * Fill a GS/OS DirEntryRecGS parameter block for a virtual-root read.
 * The asm intercept in GNORefCommon passes the raw pBlock pointer; we
 * read refNum/base/displacement from it and synthesize entryNum,
 * fileType, access, and the name.  Optional metadata fields (dates,
 * aux type, resource fork info) are zeroed.
 *
 * GetDirEntry semantics honored:
 *   base=0, displacement=0  → "info" probe.  Return total entry count
 *                             in entryNum, put directory name ("/") in
 *                             the name result buffer.  Do not advance.
 *   base=1, displacement=N  → advance forward by N from current position
 *                             and read the new current entry.
 *   base=2, displacement=N  → back up by N (clamped to 0) and read.
 *   base=3, displacement=N  → seek to absolute entry N (1-indexed) and
 *                             read.
 *
 * Position model: `walkIndex` is the 0-based index of the NEXT entry to
 * emit.  For base=1 disp=1 (ls's sequential read), we emit names[walkIndex]
 * and post-increment.
 *
 * Return: 0 on success, $43 (bad refnum) if the slot is stale,
 * $46 (file not found) when the walk runs past the end of the volume list.
 */
word vroot_dirent(void *pBlockV)
{
    word *pb = (word *) pBlockV;
    word pCount;
    word refNum;
    word base;
    word displacement;
    word slot;
    vroot_buf *buf;
    word emitIndex;

    pCount = pb[0];
    refNum = pb[1];
    base = (pCount >= 3) ? pb[3] : 0;
    displacement = (pCount >= 4) ? pb[4] : 0;

    if (refNum < VROOT_FAKE_BASE) return 0x43;
    slot = refNum - VROOT_FAKE_BASE;
    if (slot >= VROOT_SLOT_COUNT) return 0x43;
    buf = vroot_slots[slot];
    if (buf == 0) return 0x43;

    /* base=0 disp=0 is an info probe: return total entry count and the
     * directory name itself, without advancing. */
    if (base == 0 && displacement == 0) {
        if (pCount >= 5)
            vroot_write_name(pb[5], pb[6], "");   /* dir name = empty for / */
        if (pCount >= 6) pb[7] = buf->nVols;       /* total entries */
        if (pCount >= 7) pb[8] = 0x000F;           /* fileType = directory */
        if (pCount >= 8) { pb[9] = 0; pb[10] = 0; }
        if (pCount >= 9) { pb[11] = 0; pb[12] = 0; }
        if (pCount >= 10) { pb[13] = 0; pb[14] = 0; pb[15] = 0; pb[16] = 0; }
        if (pCount >= 11) { pb[17] = 0; pb[18] = 0; pb[19] = 0; pb[20] = 0; }
        if (pCount >= 12) pb[21] = 0x00C3;
        if (pCount >= 13) { pb[22] = 0; pb[23] = 0; }
        if (pCount >= 14) pb[24] = 0;
        return 0;
    }

    /* Compute which entry we should emit, then advance walkIndex past it. */
    if (base == 1) {                    /* forward from current */
        buf->walkIndex += displacement;
    } else if (base == 2) {             /* backward from current */
        if (displacement >= buf->walkIndex) buf->walkIndex = 0;
        else buf->walkIndex -= displacement;
    } else if (base == 3) {             /* absolute seek */
        buf->walkIndex = (displacement > 0) ? displacement : 1;
    } else {
        return 0x40;                    /* invalid base */
    }

    if (buf->walkIndex == 0 || buf->walkIndex > buf->nVols) return 0x46;
    emitIndex = buf->walkIndex - 1;

    if (pCount >= 5)
        vroot_write_name(pb[5], pb[6], buf->names[emitIndex]);
    if (pCount >= 6) pb[7] = buf->walkIndex;   /* 1-based entry index */
    if (pCount >= 7) pb[8] = 0x000F;           /* fileType = directory */
    if (pCount >= 8) { pb[9] = 0; pb[10] = 0; }
    if (pCount >= 9) { pb[11] = 0; pb[12] = 0; }
    if (pCount >= 10) { pb[13] = 0; pb[14] = 0; pb[15] = 0; pb[16] = 0; }
    if (pCount >= 11) { pb[17] = 0; pb[18] = 0; pb[19] = 0; pb[20] = 0; }
    if (pCount >= 12) pb[21] = 0x00C3;
    if (pCount >= 13) { pb[22] = 0; pb[23] = 0; }
    if (pCount >= 14) pb[24] = 0;

    return 0;
}
