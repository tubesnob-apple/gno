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
    word walkIndex;                                /* current read position (1-based, 0=before-first) */
    word nVols;                                    /* volumes captured at open time */
    char names[VROOT_MAX_VOLS][VROOT_NAME_LEN];    /* null-terminated vol name */
    longword sizes[VROOT_MAX_VOLS];                /* totalBlocks * blockSize (bytes) */
    longword blocks[VROOT_MAX_VOLS];               /* totalBlocks */
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

        /* Volume: get mounted volume name + size metadata.  pCount=6
         * gets us through blockSize, which we need alongside
         * totalBlocks to compute the volume's byte size. */
        vol.pCount = 6;
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

        /* Capture volume size: totalBlocks * blockSize (bytes).
         * For any real volume this fits comfortably in a 32-bit
         * longword (2^32 bytes = 4 GB of addressable volume). */
        buf->blocks[buf->nVols] = vol.totalBlocks;
        buf->sizes[buf->nVols] =
            (longword) vol.totalBlocks * (longword) vol.blockSize;

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
 * Write a GS/OS-format length-prefix string into a ResultBuf255 pointed
 * to by resBuf.  Used to fill the `name` output of a DirEntryRecGS.
 */
static void vroot_write_name(ResultBuf255Ptr resBuf, const char *name)
{
    word maxText;
    word len;
    word i;

    if (resBuf == NULL) return;
    maxText = resBuf->bufSize;
    len = strlen(name);
    if (maxText < 2) {
        resBuf->bufString.length = 0;
        return;
    }
    if (len > maxText - 2) len = maxText - 2;
    resBuf->bufString.length = len;
    for (i = 0; i < len; i++)
        resBuf->bufString.text[i] = name[i];
}

/*
 * Fill a GS/OS DirEntryRecGS parameter block for a virtual-root read.
 * The asm intercept in GNORefCommon passes the raw pBlock pointer; we
 * cast it to DirEntryRecGS* so field writes land exactly where ls and
 * libc expect them, regardless of how ORCA/C lays out longwords
 * relative to word-indexed math.
 *
 * GetDirEntry semantics honored:
 *   base=0, displacement=0  → "info" probe.  Return total entry count
 *                             in entryNum, put directory name ("") in
 *                             the name result buffer.  Do not advance.
 *   base=1, displacement=N  → advance forward by N from current position
 *                             and read the new current entry.
 *   base=2, displacement=N  → back up by N (clamped to 0) and read.
 *   base=3, displacement=N  → seek to absolute entry N (1-indexed) and
 *                             read.
 *
 * Position model: `walkIndex` is the 1-based index of the entry just
 * returned.  Initially 0, meaning "no entry has been read yet".
 *
 * Return: 0 on success, $43 (bad refnum) if the slot is stale,
 * $46 (file not found) when the walk runs past the end of the volume list.
 */

/* Clear all optional output fields we don't synthesize.  Called after
 * the base-specific logic has decided which entry to emit.  eof and
 * blockCount are set by the caller (to the real volume totals) before
 * this function runs and must not be overwritten — we only zero them
 * for the info-probe case where no specific volume is being emitted. */
static void vroot_clear_optional(DirEntryRecGS *de)
{
    word pc = de->pCount;

    /* eof (pc>=8) and blockCount (pc>=9) are caller's responsibility. */
    if (pc >= 10) {
        de->createDateTime.second = 0;
        de->createDateTime.minute = 0;
        de->createDateTime.hour = 0;
        de->createDateTime.year = 0;
        de->createDateTime.day = 0;
        de->createDateTime.month = 0;
        de->createDateTime.extra = 0;
        de->createDateTime.weekDay = 0;
    }
    if (pc >= 11) {
        de->modDateTime.second = 0;
        de->modDateTime.minute = 0;
        de->modDateTime.hour = 0;
        de->modDateTime.year = 0;
        de->modDateTime.day = 0;
        de->modDateTime.month = 0;
        de->modDateTime.extra = 0;
        de->modDateTime.weekDay = 0;
    }
    if (pc >= 12) de->access = 0x00C3;
    if (pc >= 13) de->auxType = 0;
    if (pc >= 14) de->fileSysID = 0;
    /* optionList (pc>=15) is caller-provided input; don't touch. */
    if (pc >= 16) de->resourceEOF = 0;
    if (pc >= 17) de->resourceBlocks = 0;
}

word vroot_dirent(void *pBlockV)
{
    DirEntryRecGS *de = (DirEntryRecGS *) pBlockV;
    word refNum;
    word slot;
    vroot_buf *buf;
    word emitIndex;

    refNum = de->refNum;

    if (refNum < VROOT_FAKE_BASE) return 0x43;
    slot = refNum - VROOT_FAKE_BASE;
    if (slot >= VROOT_SLOT_COUNT) return 0x43;
    buf = vroot_slots[slot];
    if (buf == 0) return 0x43;

    /* base=0 disp=0 is an info probe: return total entry count and the
     * directory name, without advancing. */
    if (de->base == 0 && de->displacement == 0) {
        if (de->pCount >= 5) vroot_write_name(de->name, "");
        if (de->pCount >= 6) de->entryNum = buf->nVols;
        if (de->pCount >= 7) de->fileType = 0x000F;
        if (de->pCount >= 8) de->eof = 0;
        if (de->pCount >= 9) de->blockCount = 0;
        vroot_clear_optional(de);
        return 0;
    }

    /* Advance walkIndex per base/displacement, then emit the entry at
     * the new position. */
    if (de->base == 1) {
        buf->walkIndex += de->displacement;
    } else if (de->base == 2) {
        if (de->displacement >= buf->walkIndex) buf->walkIndex = 0;
        else buf->walkIndex -= de->displacement;
    } else if (de->base == 3) {
        buf->walkIndex = (de->displacement > 0) ? de->displacement : 1;
    } else {
        return 0x40;   /* invalid base */
    }

    if (buf->walkIndex == 0 || buf->walkIndex > buf->nVols) return 0x46;
    emitIndex = buf->walkIndex - 1;

    if (de->pCount >= 5) vroot_write_name(de->name, buf->names[emitIndex]);
    if (de->pCount >= 6) de->entryNum = buf->walkIndex;
    if (de->pCount >= 7) de->fileType = 0x000F;
    if (de->pCount >= 8) de->eof = buf->sizes[emitIndex];
    if (de->pCount >= 9) de->blockCount = buf->blocks[emitIndex];
    vroot_clear_optional(de);
    return 0;
}
