#!/usr/bin/env python3
"""
maccatrez.py -- macOS Rez compiler for Apple IIgs GNO resource forks

Parses .rez source files and writes the resource fork binary as the
com.apple.ResourceFork extended attribute on the target file.

Supported resource types:
    rVersion ($8029)  -- version info block
    rComment ($802A)  -- null-terminated comment string

Binary format verified against GNO 2.0.6 reference disk image (kern.rsrc,
catrez.rsrc) using Apple IIgs Resource Manager header definitions from
ORCA/C 2.2.0 ORCACDefs/resources.h.

Usage:
    python3 maccatrez.py <rezfile> <targetfile>
    python3 maccatrez.py <rezfile> --dry-run
    python3 maccatrez.py <rezfile> --output <rsrcfile>

The target file must already exist.  Use --output to write a standalone
.rsrc binary file instead of setting the xattr.
"""

import sys
import re
import struct
import subprocess
import os
from datetime import date
from pathlib import Path

# ── Resource type IDs ──────────────────────────────────────────────────────────

BUILTIN_RES_TYPES = {
    'rVersion':     0x8029,
    'rComment':     0x802A,
    'rBundle':      0x802B,
    'rFinderPath':  0x802C,
    'rProgramInfo': 0xC004,
}

# ── Stage/country constants ───────────────────────────────────────────────────

# rVersion stage codes (stored in ReverseBytes block)
STAGE_CODES = {
    'development': 0x20,
    'alpha':       0x40,
    'beta':        0x60,
    'final':       0x80,
    'release':     0xA0,
}

# Region/country codes for rVersion
COUNTRY_CODES = {
    'verUS':         0,  'verFrance':   1,  'verBritain':  2,
    'verGermany':    3,  'verItaly':    4,  'verNetherlands': 5,
    'verBelgiumLux': 6,  'verSweden':   7,  'verSpain':    8,
    'verDenmark':    9,  'verPortugal': 10, 'verFrCanada': 11,
    'verNorway':    12,  'verIsrael':   13, 'verJapan':    14,
}

# Attribute qualifiers: these appear in resource(..., purgeable3, nocrossbank)
# and are stored as resAttr flags.  We accept but don't encode them (the
# Resource Manager sets these at load time from the xattr data anyway).
IGNORED_ATTRS = {
    'purgeable', 'purgeable1', 'purgeable2', 'purgeable3',
    'nocrossbank', 'convert', 'fixed', 'locked', 'protected', 'preload',
    'sysHeap', 'purge', 'locked', 'protect',
}

# ── Preprocessor ─────────────────────────────────────────────────────────────

def _strip_comments(text):
    """Remove /* ... */ block comments and // line comments."""
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.DOTALL)
    text = re.sub(r'//[^\n]*', '', text)
    return text


def preprocess(text, source_path, defines=None, _depth=0):
    """
    Preprocess a .rez file:
    - strip comments
    - handle #include (Types.rez built-in, builddate.rez special, others relative)
    - collect #define NAME value into defines dict
    - return (cleaned_text, defines)
    """
    if defines is None:
        defines = {}
    if _depth > 10:
        return text, defines

    text = _strip_comments(text)
    source_dir = os.path.dirname(os.path.abspath(source_path))

    # Handle $$Date before line scanning (it appears in #define values)
    today = date.today().isoformat()
    text = text.replace('$$Date', f'"{today}"')

    lines = text.split('\n')
    keep = []
    for line in lines:
        inc = re.match(r'\s*#include\s+"([^"]+)"', line, re.IGNORECASE)
        if inc:
            fname = inc.group(1)
            if fname.lower() == 'types.rez':
                # Built-in; all relevant constants are hard-coded
                pass
            elif fname.lower() == 'builddate.rez':
                # Inject BUILD_DATE define
                defines['BUILD_DATE'] = f'"Build Date: {today}"'
            else:
                inc_path = Path(source_dir) / fname
                if inc_path.exists():
                    inc_text = inc_path.read_text(encoding='latin-1')
                    inc_text, defines = preprocess(inc_text, str(inc_path),
                                                   defines, _depth + 1)
                    keep.append(inc_text)
            continue

        defn = re.match(r'\s*#define\s+(\w+)\s*(.*)', line)
        if defn:
            name = defn.group(1)
            value = defn.group(2).strip()
            defines[name] = value
            continue

        keep.append(line)

    return '\n'.join(keep), defines


def expand_defines(text, defines, _passes=0):
    """
    Iteratively expand #define names in text.
    Stops when no further substitutions can be made (up to 20 passes).
    """
    if _passes > 20:
        return text
    # Sort longest-name first to avoid partial matches (e.g., BUILD_DATE before BUILD)
    for name in sorted(defines.keys(), key=len, reverse=True):
        value = defines[name]
        # Use a lambda replacement so re.sub does NOT interpret \n, \t etc.
        # in the replacement string (it would convert \n → 0x0A, breaking our
        # escape handling in collect_string which expects \n as two chars).
        new = re.sub(r'\b' + re.escape(name) + r'\b', lambda m, v=value: v, text)
        if new != text:
            return expand_defines(new, defines, _passes + 1)
    return text

# ── Token helpers ─────────────────────────────────────────────────────────────

def resolve_int(token, extra=None):
    """
    Resolve a token to an integer.  Handles:
      $HHHH  0xHHHH  decimal  stage/country/type names
    Returns 0 for unrecognised tokens.
    """
    token = token.strip()
    for table in (STAGE_CODES, COUNTRY_CODES, BUILTIN_RES_TYPES,
                  extra or {}):
        if token in table:
            return table[token]
    if token.startswith('$'):
        try: return int(token[1:], 16)
        except ValueError: pass
    if token.startswith(('0x', '0X')):
        try: return int(token, 16)
        except ValueError: pass
    try:
        return int(token)
    except ValueError:
        return 0


def collect_string(text):
    """
    Consume one or more adjacent C-style string literals from the start
    of *text*, concatenate them, and return (combined_str, remaining_text).

    Escape sequences: \\n → CR (0x0D on Apple IIgs), \\r → CR, \\t → TAB,
                      \\0 → NUL, \\\\ → \\, \\" → "
    """
    result = []
    i = 0
    while i < len(text):
        # Skip whitespace between adjacent literals
        while i < len(text) and text[i] in ' \t\r\n':
            i += 1
        if i >= len(text) or text[i] != '"':
            break
        i += 1  # skip opening quote
        while i < len(text):
            c = text[i]
            if c == '\\' and i + 1 < len(text):
                esc = text[i + 1]
                if   esc == 'n':  result.append('\r')   # \n → CR on IIgs
                elif esc == 'r':  result.append('\r')
                elif esc == 't':  result.append('\t')
                elif esc == '0':  result.append('\x00')
                elif esc == '"':  result.append('"')
                elif esc == '\\': result.append('\\')
                else:             result.append(esc)
                i += 2
            elif c == '"':
                i += 1
                break
            else:
                result.append(c)
                i += 1
    return ''.join(result), text[i:]


def next_word_token(text):
    """Extract the next identifier/number token, return (token, rest)."""
    text = text.lstrip()
    m = re.match(r'([A-Za-z_]\w*|\$[0-9A-Fa-f]+|0[xX][0-9A-Fa-f]+|\d+)', text)
    if m:
        return m.group(1), text[m.end():]
    return '', text

# ── Resource encoders ─────────────────────────────────────────────────────────

def encode_rversion(body):
    """
    Encode an rVersion resource body.

    Expected body (after comment/define expansion):
        { major, minor, bug, stage, nonfinal }, country, "short", "long"

    Binary layout (per Types.rez ReverseBytes definition):
        bytes[0..3]:  ReverseBytes { major, minor|bug, stage, nonfinal }
                      → stored on disk as [nonfinal, stage, minor_bug, major]
        bytes[4..5]:  country code (Word, little-endian)
        byte[6]:      pstring length for short version
        bytes[7..]:   short version text (no null)
        byte[n]:      pstring length for long version
        bytes[n+1..]: long version text (no null)
    """
    body = body.strip()

    # Extract version tuple { a, b, c, d, e }
    m = re.match(r'\{([^}]*)\}', body)
    if not m:
        print(f"  warning: rVersion: could not find version tuple in: {body[:80]!r}")
        return None
    tuple_str = m.group(1)
    rest = body[m.end():].lstrip().lstrip(',').strip()

    parts = [p.strip() for p in tuple_str.split(',')]
    while len(parts) < 5:
        parts.append('0')

    major    = resolve_int(parts[0]) & 0xFF
    minor    = resolve_int(parts[1]) & 0x0F
    bug      = resolve_int(parts[2]) & 0x0F
    stage    = resolve_int(parts[3]) & 0xFF
    nonfinal = resolve_int(parts[4]) & 0xFF

    minor_bug = (minor << 4) | bug  # packed BCD nibbles

    # ReverseBytes: fields listed MSB→LSB but stored LSB→MSB (little-endian 4-byte)
    # Listed order: [major, minor_bug, stage, nonfinal]
    # Stored order: [nonfinal, stage, minor_bug, major]
    rev_bytes = bytes([nonfinal, stage, minor_bug, major])

    # Country
    country_tok, rest = next_word_token(rest)
    country = resolve_int(country_tok) & 0xFFFF
    rest = rest.lstrip().lstrip(',').strip()

    # Short version pstring (Pascal: 1-byte length + chars)
    short_str, rest = collect_string(rest)
    rest = rest.lstrip().lstrip(',').strip()

    # Long version pstring
    long_str, _ = collect_string(rest)

    short_b = short_str.encode('latin-1', errors='replace')[:255]
    long_b  = long_str.encode('latin-1', errors='replace')[:255]

    return (rev_bytes
            + struct.pack('<H', country)
            + bytes([len(short_b)]) + short_b
            + bytes([len(long_b)]) + long_b)


def encode_rcomment(body):
    """
    Encode an rComment resource body.

    Body is one or more adjacent string literals.  The Rez `string;` type
    is a raw (non-null-terminated) string — verified against the GNO 2.0.6
    reference catrez.rsrc which ends exactly at the last character with no
    trailing NUL byte.  \\n → CR (0x0D).
    """
    body = body.strip()
    content, _ = collect_string(body)
    return content.encode('latin-1', errors='replace')

# ── .rez file parser ─────────────────────────────────────────────────────────

def parse_rez(rez_path):
    """
    Parse a .rez file and return a list of encoded resources:
        [ (type_id: int, res_id: int, attrs: int, data: bytes), ... ]
    """
    text = Path(rez_path).read_text(encoding='latin-1')
    text, defines = preprocess(text, rez_path)

    resources = []

    # Match:  resource TypeName (id [, attr, attr, ...]) { body };
    # The body may span multiple lines and contain nested braces.
    pattern = re.compile(
        r'\bresource\s+(\w+)\s*\(([^)]*)\)\s*\{',
        re.DOTALL
    )

    pos = 0
    while True:
        m = pattern.search(text, pos)
        if not m:
            break
        type_name = m.group(1)
        args_str  = m.group(2)
        body_start = m.end()

        # Find matching closing brace + semicolon
        depth = 1
        i = body_start
        while i < len(text) and depth > 0:
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
            i += 1

        body = text[body_start:i - 1]  # content between { }
        pos = i

        # Resolve resource type ID
        type_id = resolve_int(type_name)
        if type_id == 0 and type_name in BUILTIN_RES_TYPES:
            type_id = BUILTIN_RES_TYPES[type_name]
        if type_id == 0:
            continue  # unknown type, skip

        # Parse resource ID from first argument
        arg_parts = [a.strip() for a in args_str.split(',')]
        res_id = resolve_int(arg_parts[0]) if arg_parts else 1

        # Expand defines in body
        body = expand_defines(body, defines)

        # Encode
        if type_id == 0x8029:   # rVersion
            data = encode_rversion(body)
        elif type_id == 0x802A: # rComment
            data = encode_rcomment(body)
        else:
            continue  # unsupported type

        if data is not None:
            resources.append((type_id, res_id, 0, data))

    return resources

# ── Resource fork assembler ───────────────────────────────────────────────────

def build_resource_fork(resources):
    """
    Assemble a complete Apple IIgs resource fork binary.

    File layout (all integers little-endian):

        [0x000]  ResHeaderRec (140 bytes)
                   LongWord rFileVersion  = 0
                   LongWord rFileToMap    = 0x8C  (immediately after header)
                   LongWord rFileMapSize  = MAP_SIZE
                   Byte     rFileMemo[128] = 0

        [0x08C]  ResMap
                   LongWord mapNext       = 0  (runtime handle, NULL on disk)
                   Word     mapFlag       = 0
                   LongWord mapOffset     = 0x8C
                   LongWord mapSize       = MAP_SIZE
                   Word     mapToIndex    = 0x74  (offset within map to index)
                   Word     mapFileNum    = 0
                   Word     mapID         = 0
                   LongWord mapIndexSize  = INDEX_SLOTS
                   LongWord mapIndexUsed  = len(resources)
                   Word     mapFreeListSize = 10
                   Word     mapFreeListUsed = 1
                   FreeBlockRec[10]       (sentinel + 9 zeros)
                   4 bytes padding
                   ResRefRec[INDEX_SLOTS]
                   2 bytes trailing pad

        [DATA]   Resource data blobs (concatenated)

    ResRefRec (20 bytes each):
        Word     resType
        Long     resID     (signed)
        LongWord resOffset (absolute file offset to data)
        Word     resAttr
        LongWord resSize
        LongWord resHandle = 0 (runtime only)
    """
    # Map geometry constants (verified against kern.rsrc / catrez.rsrc)
    NUM_FREE_ENTRIES = 10
    HEADER_FIXED     = 32         # mapNext..mapFreeListUsed
    FREE_LIST_BYTES  = NUM_FREE_ENTRIES * 8   # FreeBlockRec array
    MAP_PADDING      = 4          # gap between free list end and index start
    MAP_TO_INDEX     = HEADER_FIXED + FREE_LIST_BYTES + MAP_PADDING  # = 0x74

    # Allocate enough index slots for all resources (minimum 10)
    INDEX_SLOTS      = max(10, len(resources))
    INDEX_BYTES      = INDEX_SLOTS * 20
    TRAILING_PAD     = 2

    MAP_SIZE         = MAP_TO_INDEX + INDEX_BYTES + TRAILING_PAD
    HEADER_SIZE      = 140        # ResHeaderRec
    MAP_OFFSET       = HEADER_SIZE   # 0x8C
    DATA_OFFSET      = MAP_OFFSET + MAP_SIZE

    # Lay out resource data and record absolute file offsets
    data_blobs = b''.join(d for _, _, _, d in resources)
    ref_offsets = []
    running = DATA_OFFSET
    for _, _, _, d in resources:
        ref_offsets.append(running)
        running += len(d)

    total_size = DATA_OFFSET + len(data_blobs)

    # ── ResHeaderRec (140 bytes) ────────────────────────────────────────
    header = bytearray(HEADER_SIZE)
    struct.pack_into('<LLL', header, 0, 0, MAP_OFFSET, MAP_SIZE)
    # rFileMemo[128] remains zero

    # ── ResMap ──────────────────────────────────────────────────────────
    map_data = bytearray(MAP_SIZE)
    p = 0

    # Fixed fields
    struct.pack_into('<L',  map_data, p, 0);            p += 4   # mapNext
    struct.pack_into('<H',  map_data, p, 0);            p += 2   # mapFlag
    struct.pack_into('<L',  map_data, p, MAP_OFFSET);   p += 4   # mapOffset
    struct.pack_into('<L',  map_data, p, MAP_SIZE);     p += 4   # mapSize
    struct.pack_into('<H',  map_data, p, MAP_TO_INDEX); p += 2   # mapToIndex
    struct.pack_into('<H',  map_data, p, 0);            p += 2   # mapFileNum
    struct.pack_into('<H',  map_data, p, 0);            p += 2   # mapID
    struct.pack_into('<L',  map_data, p, INDEX_SLOTS);  p += 4   # mapIndexSize
    struct.pack_into('<L',  map_data, p, len(resources));p += 4  # mapIndexUsed
    struct.pack_into('<H',  map_data, p, NUM_FREE_ENTRIES); p += 2  # mapFreeListSize
    struct.pack_into('<H',  map_data, p, 1);            p += 2   # mapFreeListUsed

    # Free list: sentinel entry at [0] marks end of data
    # blkOffset = file size (one past last byte), blkSize = -(fileSize+1)
    struct.pack_into('<L',  map_data, p, total_size);          p += 4
    struct.pack_into('<l',  map_data, p, -(total_size + 1));   p += 4
    # Remaining entries are already zero
    p += (NUM_FREE_ENTRIES - 1) * 8

    # Padding gap (4 bytes, already zero)
    p += MAP_PADDING

    assert p == MAP_TO_INDEX, f"Map header size mismatch: {p:#x} != {MAP_TO_INDEX:#x}"

    # Reference records
    for i, (type_id, res_id, attrs, data) in enumerate(resources):
        struct.pack_into('<H', map_data, p, type_id);         p += 2
        struct.pack_into('<l', map_data, p, res_id);          p += 4
        struct.pack_into('<L', map_data, p, ref_offsets[i]);  p += 4
        struct.pack_into('<H', map_data, p, attrs);           p += 2
        struct.pack_into('<L', map_data, p, len(data));       p += 4
        struct.pack_into('<L', map_data, p, 0);               p += 4   # resHandle

    # Remaining index slots and trailing pad are already zero

    return bytes(header) + bytes(map_data) + data_blobs

# ── Verification ──────────────────────────────────────────────────────────────

def verify_fork(rsrc_bytes, expected_resources):
    """
    Quick sanity check: re-parse the generated binary and confirm each
    resource's type, ID, and data match what we put in.
    Returns True on success.
    """
    ok = True
    _, map_off, map_size = struct.unpack_from('<LLL', rsrc_bytes, 0)
    data_start = map_off + map_size

    map_to_index, = struct.unpack_from('<H', rsrc_bytes, map_off + 14)
    _, idx_used  = struct.unpack_from('<LL', rsrc_bytes, map_off + 20)

    idx_off = map_off + map_to_index
    for i in range(idx_used):
        p = idx_off + i * 20
        res_type,              = struct.unpack_from('<H', rsrc_bytes, p)
        res_id,                = struct.unpack_from('<l', rsrc_bytes, p + 2)
        res_offset,            = struct.unpack_from('<L', rsrc_bytes, p + 6)
        res_size,              = struct.unpack_from('<L', rsrc_bytes, p + 12)

        actual_data = rsrc_bytes[res_offset:res_offset + res_size]
        exp_type, exp_id, _, exp_data = expected_resources[i]

        if res_type != exp_type or res_id != exp_id or actual_data != exp_data:
            print(f"  VERIFY FAIL ref[{i}]: type={res_type:#06x} id={res_id} "
                  f"size={res_size} (expected type={exp_type:#06x} id={exp_id} "
                  f"size={len(exp_data)})")
            ok = False

    return ok

# ── xattr writer ─────────────────────────────────────────────────────────────

def write_resource_fork_xattr(target_path, rsrc_bytes):
    """Write rsrc_bytes as com.apple.ResourceFork xattr on target_path."""
    # xattr -wx expects a hex string (space-separated pairs are OK)
    hex_str = rsrc_bytes.hex()
    result = subprocess.run(
        ['xattr', '-wx', 'com.apple.ResourceFork', hex_str, target_path],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"  xattr error: {result.stderr.strip()}", file=sys.stderr)
        return False
    return True

# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    import argparse
    ap = argparse.ArgumentParser(
        description='Compile a GNO .rez file into an Apple IIgs resource fork.')
    ap.add_argument('rezfile',  help='.rez source file to compile')
    ap.add_argument('target',   nargs='?',
                    help='Target file to attach resource fork to (as xattr)')
    ap.add_argument('--dry-run', action='store_true',
                    help='Parse and encode, but do not write anything')
    ap.add_argument('--output', metavar='FILE',
                    help='Write resource fork binary to FILE instead of xattr')
    ap.add_argument('--verify', action='store_true',
                    help='Re-parse generated binary and verify round-trip')
    ap.add_argument('-v', '--verbose', action='store_true')
    args = ap.parse_args()

    if not args.dry_run and not args.output and not args.target:
        ap.error('Either provide a target file or use --dry-run / --output')

    # Parse
    rez_path = args.rezfile
    if not os.path.exists(rez_path):
        print(f"error: {rez_path}: no such file", file=sys.stderr)
        sys.exit(1)

    resources = parse_rez(rez_path)

    if not resources:
        print(f"warning: no supported resources found in {rez_path}")
        sys.exit(0)

    if args.verbose:
        for type_id, res_id, attrs, data in resources:
            type_name = {0x8029:'rVersion', 0x802A:'rComment'}.get(type_id,
                                                                     f'{type_id:#06x}')
            print(f"  {type_name} id={res_id} size={len(data)} bytes")

    # Build fork
    rsrc_bytes = build_resource_fork(resources)

    if args.verbose:
        print(f"  resource fork: {len(rsrc_bytes)} bytes "
              f"({len(resources)} resource(s))")

    if args.verify:
        if verify_fork(rsrc_bytes, resources):
            print("  verify: OK")
        else:
            print("  verify: FAILED", file=sys.stderr)
            sys.exit(1)

    if args.dry_run:
        print(f"dry-run: would write {len(rsrc_bytes)} bytes to resource fork")
        sys.exit(0)

    if args.output:
        Path(args.output).write_bytes(rsrc_bytes)
        print(f"wrote {len(rsrc_bytes)} bytes to {args.output}")
        sys.exit(0)

    # Write xattr
    if not os.path.exists(args.target):
        print(f"error: target file not found: {args.target}", file=sys.stderr)
        sys.exit(1)

    if write_resource_fork_xattr(args.target, rsrc_bytes):
        if args.verbose:
            print(f"  wrote com.apple.ResourceFork to {args.target}")
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
