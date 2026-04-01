#!/usr/bin/env python3
"""
omf_check.py — Validate ORCA/M OMF .ROOT output against expected hex bytes.

Parses every segment in the OMF file, concatenates the code bytes from
CONST / LCONST / DS records, then compares against an expected hex string.

Usage:
    omf_check.py <file.ROOT> <file.expected>   # verify
    omf_check.py --record <file.ROOT> <file.expected>  # write actual → expected

Exit: 0 on match (or successful record), 1 on mismatch or error.

OMF v2 record types handled:
    0x00        END        — end of records for this segment
    0x01–0xDF   CONST(N)   — N bytes of code data follow (N = record type byte)
    0xF1        DS         — 4-byte count of zero-fill bytes (no data in record)
    0xF2        LCONST     — 4-byte count, then that many bytes of code data

Record types skipped (sizes known):
    0xE2  RELOC      — 11 bytes total (type+size+shift+offset+segment+offset)
    0xE3  INTERSEG   — 11 bytes total
    0xE4  USING      — 4 bytes total
    0xE5  STRONG     — 5 bytes total
    0xE6  GLOBAL     — variable: type(1)+numlen(1)+name(numlen)+count(4)+type(1)
    0xE7  GEQU       — variable (same as GLOBAL)
    0xE8  MEM        — 9 bytes total
    0xEB  LOCALSYM   — variable (same as GLOBAL)
    0xF3  cINTERSEG  — 8 bytes total
    0xF5  RELOC2     — 7 bytes total

Unknown record types cause the parser to stop collecting bytes for that segment.
"""

import sys
import struct


# ---------------------------------------------------------------------------
# OMF parsing
# ---------------------------------------------------------------------------

def _skip_global(data, pos, seg_end):
    """Return position after a GLOBAL / LOCALSYM / GEQU record."""
    pos += 1  # skip type byte
    if pos >= seg_end:
        return seg_end
    numlen = data[pos]
    pos += 1 + numlen  # skip length byte + name bytes
    pos += 4 + 1       # skip count (4) + type (1)
    return pos


FIXED_SKIP = {
    0xE2: 11,   # RELOC
    0xE3: 11,   # INTERSEG
    0xE4:  4,   # USING
    0xE5:  5,   # STRONG
    0xE8:  9,   # MEM
    0xF3:  8,   # cINTERSEG
    0xF5:  7,   # RELOC2
}

VARIABLE_SKIP = {0xE6, 0xE7, 0xEB}  # GLOBAL, GEQU, LOCALSYM


def parse_omf_bytes(filename):
    """
    Read an OMF file and return the concatenated code bytes from all segments.
    Returns (bytes, warnings) where warnings is a list of string messages.
    """
    with open(filename, 'rb') as f:
        data = f.read()

    result  = bytearray()
    warnings = []
    pos     = 0

    while pos < len(data):
        if pos + 4 > len(data):
            break
        blk_len = struct.unpack_from('<I', data, pos)[0]
        if blk_len == 0:
            break
        if pos + blk_len > len(data):
            warnings.append(f'segment at {pos:#x}: blk_len {blk_len} exceeds file')
            break

        # disp_data is at offset 0x2A within the segment header
        if pos + 0x2C > pos + blk_len:
            warnings.append(f'segment at {pos:#x}: header too short for disp_data')
            pos += blk_len
            continue
        disp_data = struct.unpack_from('<H', data, pos + 0x2A)[0]

        rec_pos  = pos + disp_data
        seg_end  = pos + blk_len

        while rec_pos < seg_end:
            rec_type = data[rec_pos]

            if rec_type == 0x00:            # END
                break

            elif 0x01 <= rec_type <= 0xDF:  # CONST(N) — N = rec_type
                count = rec_type
                rec_pos += 1
                if rec_pos + count > seg_end:
                    warnings.append(f'CONST overruns segment at rec_pos={rec_pos:#x}')
                    break
                result.extend(data[rec_pos : rec_pos + count])
                rec_pos += count

            elif rec_type == 0xF2:          # LCONST — 4-byte count
                if rec_pos + 5 > seg_end:
                    break
                count = struct.unpack_from('<I', data, rec_pos + 1)[0]
                rec_pos += 5
                if rec_pos + count > seg_end:
                    warnings.append(f'LCONST overruns segment at rec_pos={rec_pos:#x}')
                    break
                result.extend(data[rec_pos : rec_pos + count])
                rec_pos += count

            elif rec_type == 0xF1:          # DS — 4-byte zero-fill count
                if rec_pos + 5 > seg_end:
                    break
                count = struct.unpack_from('<I', data, rec_pos + 1)[0]
                result.extend(bytes(count))
                rec_pos += 5

            elif rec_type in FIXED_SKIP:
                rec_pos += FIXED_SKIP[rec_type]

            elif rec_type in VARIABLE_SKIP:
                rec_pos = _skip_global(data, rec_pos, seg_end)

            else:
                warnings.append(
                    f'unknown record type {rec_type:#04x} at {rec_pos:#x}; '
                    f'stopping byte collection for this segment'
                )
                break

        pos += blk_len

    return bytes(result), warnings


# ---------------------------------------------------------------------------
# Expected-file helpers
# ---------------------------------------------------------------------------

def read_expected(path):
    with open(path) as f:
        text = f.read().strip()
    if not text:
        return bytes()
    return bytes(int(h, 16) for h in text.split())


def write_expected(path, data):
    hex_str = ' '.join(f'{b:02X}' for b in data)
    with open(path, 'w') as f:
        f.write(hex_str + '\n')


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    args = sys.argv[1:]
    record_mode = False

    if args and args[0] == '--record':
        record_mode = True
        args = args[1:]

    if len(args) != 2:
        print(f'Usage: {sys.argv[0]} [--record] <file.ROOT> <file.expected>')
        sys.exit(1)

    root_file, expected_file = args

    actual, warnings = parse_omf_bytes(root_file)
    for w in warnings:
        print(f'  WARNING: {w}')

    if record_mode:
        write_expected(expected_file, actual)
        print(f'  RECORDED: {len(actual)} bytes → {expected_file}')
        print(f'    {" ".join(f"{b:02X}" for b in actual)}')
        sys.exit(0)

    expected = read_expected(expected_file)

    if actual == expected:
        print(f'  OK  {len(actual)} bytes match')
        sys.exit(0)
    else:
        print(f'  MISMATCH')
        print(f'    expected ({len(expected)}): {" ".join(f"{b:02X}" for b in expected)}')
        print(f'    actual   ({len(actual)}): {" ".join(f"{b:02X}" for b in actual)}')
        for i, (a, e) in enumerate(zip(actual, expected)):
            if a != e:
                print(f'    first diff at byte {i}: got {a:02X}, want {e:02X}')
                break
        else:
            if len(actual) != len(expected):
                print(f'    length differs: got {len(actual)}, want {len(expected)}')
        sys.exit(1)


if __name__ == '__main__':
    main()
