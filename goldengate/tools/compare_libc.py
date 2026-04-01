#!/usr/bin/env python3
"""Compare symbols/segments in two ORCA OMF v2 library files."""

import struct
import sys

def parse_omf_segments(filepath):
    """Parse an OMF file and return a list of segment info dicts."""
    with open(filepath, 'rb') as f:
        data = f.read()

    segments = []
    offset = 0
    while offset < len(data):
        if offset + 44 > len(data):
            break

        bytecnt = struct.unpack_from('<I', data, offset)[0]
        if bytecnt == 0:
            break

        lablen = data[offset + 13]
        version = data[offset + 15]
        kind = struct.unpack_from('<H', data, offset + 20)[0]
        segnum = struct.unpack_from('<H', data, offset + 34)[0]
        dispname = struct.unpack_from('<H', data, offset + 40)[0]
        dispdata = struct.unpack_from('<H', data, offset + 42)[0]

        name_pos = offset + dispname

        # OMF v2: DISPNAME points to LOADNAME (10 bytes, space-padded)
        # followed by SEGNAME (Pascal string: 1 byte len + chars)
        if lablen > 0:
            # Fixed-length labels
            loadname = data[name_pos:name_pos + lablen].rstrip(b'\x00 ').decode('ascii', errors='replace')
            segname_pos = name_pos + lablen
            segname = data[segname_pos:segname_pos + lablen].rstrip(b'\x00 ').decode('ascii', errors='replace')
        else:
            # LOADNAME is always 10 bytes
            loadname = data[name_pos:name_pos + 10].rstrip(b'\x00 ').decode('ascii', errors='replace')
            segname_pos = name_pos + 10
            segname_len = data[segname_pos]
            segname = data[segname_pos + 1:segname_pos + 1 + segname_len].decode('ascii', errors='replace')

        segments.append({
            'segname': segname,
            'loadname': loadname,
            'kind': kind,
            'segnum': segnum,
            'bytecnt': bytecnt,
            'version': version,
        })

        offset += bytecnt

    return segments


def kind_str(kind):
    """Return human-readable kind string."""
    base = kind & 0x001F
    dynamic = (kind & 0x4000) != 0
    names = {
        0x00: "Code",
        0x01: "Data",
        0x02: "JumpTable",
        0x04: "Pathname",
        0x08: "LibDict",
        0x12: "Data(priv)",
    }
    s = names.get(base, f"0x{kind:04X}")
    if dynamic:
        s = "Dyn+" + s
    return s


def main():
    our_file = "/Users/smentzer/source/iigs-official-repos/ksherlock-gno/gno-obj/lib/libc"
    ref_file = "/Users/smentzer/source/iigs-official-repos/ksherlock-gno/gno/diskImages/extracted/lib/libc"

    print("=" * 70)
    print("ORCA OMF Library Comparison")
    print("=" * 70)
    print(f"\nOur build:  {our_file}")
    print(f"Reference:  {ref_file}")
    print()

    our_segs = parse_omf_segments(our_file)
    ref_segs = parse_omf_segments(ref_file)

    print(f"Our build:  {len(our_segs)} total segments")
    print(f"Reference:  {len(ref_segs)} total segments")
    print()

    # Show kind breakdown
    for label, segs in [("Our build", our_segs), ("Reference", ref_segs)]:
        kinds = {}
        for s in segs:
            k = s['kind']
            kinds[k] = kinds.get(k, 0) + 1
        print(f"  {label} segment kinds:")
        for k in sorted(kinds.keys()):
            print(f"    KIND=0x{k:04X} ({kind_str(k)}): {kinds[k]}")
        print()

    # Filter out library dictionary segments (kind base == 0x08)
    def is_dict_segment(kind):
        return (kind & 0x001F) == 0x08

    our_non_dict = [s for s in our_segs if not is_dict_segment(s['kind'])]
    ref_non_dict = [s for s in ref_segs if not is_dict_segment(s['kind'])]

    our_names = set(s['segname'] for s in our_non_dict)
    ref_names = set(s['segname'] for s in ref_non_dict)

    print(f"Our build:  {len(our_non_dict)} non-dictionary segments ({len(our_names)} unique names)")
    print(f"Reference:  {len(ref_non_dict)} non-dictionary segments ({len(ref_names)} unique names)")
    print()

    only_ref = sorted(ref_names - our_names, key=str.lower)
    only_ours = sorted(our_names - ref_names, key=str.lower)
    both = sorted(our_names & ref_names, key=str.lower)

    print("=" * 70)
    print(f"MISSING from our build (in reference only): {len(only_ref)}")
    print("=" * 70)
    for name in only_ref:
        seg = next(s for s in ref_non_dict if s['segname'] == name)
        print(f"  {name:<30s}  [{kind_str(seg['kind']):<12s} {seg['bytecnt']:5d} bytes  load={seg['loadname']!r}]")

    print()
    print("=" * 70)
    print(f"EXTRA in our build (not in reference): {len(only_ours)}")
    print("=" * 70)
    for name in only_ours:
        seg = next(s for s in our_non_dict if s['segname'] == name)
        print(f"  {name:<30s}  [{kind_str(seg['kind']):<12s} {seg['bytecnt']:5d} bytes  load={seg['loadname']!r}]")

    print()
    print("=" * 70)
    print(f"MATCHING (in both): {len(both)}")
    print("=" * 70)
    for name in both:
        our_seg = next(s for s in our_non_dict if s['segname'] == name)
        ref_seg = next(s for s in ref_non_dict if s['segname'] == name)
        size_diff = our_seg['bytecnt'] - ref_seg['bytecnt']
        diff_str = ""
        if size_diff != 0:
            diff_str = f"  (delta {size_diff:+d})"
        print(f"  {name:<30s}  [ours: {our_seg['bytecnt']:5d}  ref: {ref_seg['bytecnt']:5d}]{diff_str}")

    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"  Total segments (our build):     {len(our_segs)}")
    print(f"  Total segments (reference):     {len(ref_segs)}")
    print(f"  Exported symbols (our build):   {len(our_names)}")
    print(f"  Exported symbols (reference):   {len(ref_names)}")
    print(f"  Matching:                       {len(both)}")
    print(f"  Missing from our build:         {len(only_ref)}")
    print(f"  Extra in our build:             {len(only_ours)}")
    pct = len(both) / len(ref_names) * 100 if ref_names else 0
    print(f"  Coverage:                       {pct:.1f}%")


if __name__ == '__main__':
    main()
