/*
 * setvers -- attach rVersion resource to a file
 *
 * Usage: setvers file 'ProgName^ProgInfo' [country] vXX.Y.Z
 *
 * ProgName = short version string; ProgInfo = long version string
 * (^ separates the two; _ in ProgInfo becomes CR)
 * country  = optional country name (default: UnitedStates)
 * vXX.Y.Z  = version number (XX=major 00-99, Y=minor 0-9, Z=bug 0-9)
 *
 * rVersion ($8029) binary layout:
 *   bytes[0..3]: [nonfinal, stage, (minor<<4)|bug, major]  (ReverseBytes)
 *   bytes[4..5]: country code (Word, little-endian)
 *   byte[6]:     length of short Pascal string
 *   bytes[7..]:  short string text
 *   byte[n]:     length of long Pascal string
 *   bytes[n+1..]:long string text
 *
 * GNO/ME 2.0.6 — written from scratch based on setvers.1 and rVersion spec.
 */

#ifndef lint
static const char sccsid[] = "@(#)setvers.c  GNO/ME 2.0.6";
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <types.h>
#include <orca.h>
#include <resources.h>
#include <memory.h>
#include <gsos.h>

#ifdef __ORCAC__
/* #pragma memorymodel 1 — removed: ABI mismatch with GNO libc */
#endif

#define noPreload   0x8000

/* rVersion stage: always 'final' for setvers */
#define STAGE_FINAL  0x80

/* Country code lookup table (matches setvers.1 list) */
static struct {
    const char *name;
    int         code;
} countries[] = {
    { "UnitedStates",        0  },
    { "France",              1  },
    { "Britain",             2  },
    { "Germany",             3  },
    { "Italy",               4  },
    { "Netherlands",         5  },
    { "Belgium/Luxembourg",  6  },
    { "Sweden",              7  },
    { "Spain",               8  },
    { "Denmark",             9  },
    { "Portugal",            10 },
    { "FrenchCanadian",      11 },
    { "Norway",              12 },
    { "Israel",              13 },
    { "Japan",               14 },
    { "Australia",           15 },
    { "Arabia",              16 },
    { "Finland",             17 },
    { "FrenchSwiss",         18 },
    { "GermanSwiss",         19 },
    { "Greece",              20 },
    { "Iceland",             21 },
    { "Malta",               22 },
    { "Cyprus",              23 },
    { "Turkey",              24 },
    { "Bosnia/Herzegovina",  25 },
    { "Ireland",             26 },
    { "Korea",               27 },
    { "China",               28 },
    { "Taiwan",              29 },
    { "Thailand",            30 },
    { NULL, 0 }
};

static void
usage()
{
    fprintf(stderr,
        "usage: setvers file 'ProgName^ProgInfo' [country] vXX.Y.Z\n");
    exit(1);
}

static GSString255Ptr
make_gsstring(const char *s)
{
    GSString255Ptr  gs;
    int             len;

    len = (int)strlen(s);
    if (len > 255)
        len = 255;
    gs = (GSString255Ptr)malloc(len + 4);
    if (gs == NULL) {
        perror("malloc");
        exit(2);
    }
    gs->length = (unsigned short)len;
    memcpy(gs->text, s, (size_t)len);
    gs->text[len] = '\0';
    return gs;
}

static int
lookup_country(const char *name)
{
    int i;

    for (i = 0; countries[i].name != NULL; i++) {
        if (strcmp(countries[i].name, name) == 0)
            return countries[i].code;
    }
    return -1;
}

int
main(argc, argv)
    int   argc;
    char *argv[];
{
    char          *filename;
    char          *nameinfo;
    char          *version_str;
    char          *country_str;
    int            country_code;
    int            major, minor, bug;
    char           short_str[256];
    char           long_str[256];
    char          *sep;
    char          *p;
    unsigned char  res_buf[600];
    int            res_len;
    unsigned char  minor_bug;
    GSString255Ptr gs_filename;
    Word           file_id;
    Handle         res_handle;
    int            err;
    int            slen;
    int            llen;

    if (argc < 4 || argc > 5)
        usage();

    filename  = argv[1];
    nameinfo  = argv[2];

    /* argv[3]: either country or version string */
    if (argc == 5) {
        country_str = argv[3];
        version_str = argv[4];
    } else {
        country_str = NULL;
        version_str = argv[3];
    }

    /* Version string must start with 'v' */
    if (version_str[0] != 'v' && version_str[0] != 'V') {
        fprintf(stderr, "setvers: version must start with 'v': %s\n",
                version_str);
        exit(1);
    }
    if (sscanf(version_str + 1, "%d.%d.%d", &major, &minor, &bug) != 3) {
        fprintf(stderr, "setvers: bad version format '%s' (want vXX.Y.Z)\n",
                version_str);
        exit(1);
    }
    if (major < 0 || major > 99 || minor < 0 || minor > 9 ||
        bug < 0 || bug > 9) {
        fprintf(stderr, "setvers: version out of range (XX=00-99, Y=0-9, Z=0-9)\n");
        exit(1);
    }

    /* Country */
    country_code = 0;       /* default: UnitedStates */
    if (country_str != NULL) {
        country_code = lookup_country(country_str);
        if (country_code < 0) {
            fprintf(stderr, "setvers: unknown country '%s'\n", country_str);
            exit(1);
        }
    }

    /* Split 'ProgName^ProgInfo' */
    sep = strchr(nameinfo, '^');
    if (sep == NULL) {
        strncpy(short_str, nameinfo, 255);
        short_str[255] = '\0';
        long_str[0] = '\0';
    } else {
        slen = (int)(sep - nameinfo);
        if (slen > 255)
            slen = 255;
        memcpy(short_str, nameinfo, (size_t)slen);
        short_str[slen] = '\0';
        strncpy(long_str, sep + 1, 255);
        long_str[255] = '\0';
    }

    /* Replace '_' with CR in long string */
    for (p = long_str; *p; p++) {
        if (*p == '_')
            *p = '\r';
    }

    /* Build rVersion resource:
     *   bytes[0..3]: [nonfinal=0, stage=0x80, minor_bug, major]
     *   bytes[4..5]: country (little-endian word)
     *   byte[6]:     short pstring length; bytes[7..]: short text
     *   byte[n]:     long pstring length;  bytes[n+1..]: long text
     */
    minor_bug = (unsigned char)(((minor & 0x0F) << 4) | (bug & 0x0F));

    res_buf[0] = 0;                                     /* nonfinal */
    res_buf[1] = STAGE_FINAL;                           /* stage    */
    res_buf[2] = minor_bug;                             /* minor+bug BCD */
    res_buf[3] = (unsigned char)(major & 0xFF);         /* major BCD    */
    res_buf[4] = (unsigned char)(country_code & 0xFF);  /* country lo   */
    res_buf[5] = (unsigned char)((country_code >> 8) & 0xFF); /* country hi */
    res_len = 6;

    slen = (int)strlen(short_str);
    if (slen > 255) slen = 255;
    res_buf[res_len++] = (unsigned char)slen;
    memcpy(res_buf + res_len, short_str, (size_t)slen);
    res_len += slen;

    llen = (int)strlen(long_str);
    if (llen > 255) llen = 255;
    res_buf[res_len++] = (unsigned char)llen;
    memcpy(res_buf + res_len, long_str, (size_t)llen);
    res_len += llen;

    /* Start the Resource Manager */
    ResourceStartUp((Word)userid());
    err = toolerror();
    if (err) {
        fprintf(stderr, "setvers: ResourceStartUp error $%04x\n", err);
        exit(2);
    }

    gs_filename = make_gsstring(filename);

    /* Create resource fork if it doesn't already exist */
    CreateResourceFile(0L, 0, (Word)(readWriteEnable | renameEnable | destroyEnable),
                       (Pointer)gs_filename);
    /* Ignore resForkUsed — fork may already exist */

    /* Open the resource fork */
    file_id = OpenResourceFile((Word)(noPreload | readWriteEnable),
                               NULL, (Pointer)gs_filename);
    err = toolerror();
    if (err) {
        fprintf(stderr, "setvers: can't open resource fork of '%s': error $%04x\n",
                filename, err);
        ResourceShutDown();
        exit(2);
    }

    SetCurResourceFile(file_id);
    SetResourceFileDepth(1);

    /* Remove any existing rVersion resource with ID 1 */
    RemoveResource((Word)rVersion, 1L);
    /* Ignore error — resource may not exist yet */

    /* Allocate a handle for the resource data */
    res_handle = NewHandle((LongWord)res_len, (Word)userid(), 0, NULL);
    err = toolerror();
    if (err || res_handle == NULL) {
        fprintf(stderr, "setvers: NewHandle error $%04x\n", err);
        CloseResourceFile(file_id);
        ResourceShutDown();
        exit(2);
    }

    HLock(res_handle);
    BlockMove((Pointer)res_buf, (Pointer)*res_handle, (LongWord)res_len);
    HUnlock(res_handle);

    /* Add the new rVersion resource */
    AddResource(res_handle, 0, (Word)rVersion, 1L);
    err = toolerror();
    if (err) {
        fprintf(stderr, "setvers: AddResource error $%04x\n", err);
        CloseResourceFile(file_id);
        ResourceShutDown();
        exit(2);
    }

    CloseResourceFile(file_id);
    ResourceShutDown();
    free(gs_filename);
    return 0;
}
