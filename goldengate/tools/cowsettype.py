#!/usr/bin/env python3
"""
cowsettype.py path hex-bytes

Set the ProDOS file-type metadata on a file, cross-platform.

  macOS   — writes com.apple.FinderInfo xattr (32 bytes)
  Linux   — writes user.com.apple.FinderInfo xattr (32 bytes)
  Windows — writes AFP_AfpInfo NTFS alternate data stream (60-byte AFP structure)

Arguments:
  path      path to the file to tag
  hex-bytes 64 hex digits (spaces allowed) representing the 32-byte FinderInfo block

Example:
  python3 cowsettype.py myfile.a \\
    "70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
"""

import platform
import subprocess
import sys

def main():
    if len(sys.argv) != 3:
        print(f'Usage: {sys.argv[0]} <path> <hex-bytes>', file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    data = bytes.fromhex(sys.argv[2].replace(' ', ''))
    if len(data) != 32:
        print(f'error: FinderInfo must be 32 bytes, got {len(data)}', file=sys.stderr)
        sys.exit(1)

    system = platform.system()

    if system == 'Darwin':
        # macOS: space-separated hex string → xattr CLI
        hex_str = ' '.join(f'{b:02X}' for b in data)
        result = subprocess.run(
            ['xattr', '-wx', 'com.apple.FinderInfo', hex_str, path],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f'error: xattr failed: {result.stderr.strip()}', file=sys.stderr)
            sys.exit(1)

    elif system == 'Linux':
        import os
        try:
            os.setxattr(path, 'user.com.apple.FinderInfo', data)
        except OSError as e:
            print(f'error: setxattr failed: {e}', file=sys.stderr)
            sys.exit(1)

    elif system in ('Windows', 'MSYS', 'CYGWIN_NT') or system.startswith('MINGW'):
        # Windows NTFS alternate data stream — AFP_AfpInfo structure (60 bytes)
        # Offset  Size  Field
        #  0       4    magic     = 0x00504641 ('AFP\0')
        #  4       4    version   = 0x00010000
        #  8       4    file_id   = 0
        # 12       4    backup    = 0
        # 16      32    finder_info (same block as macOS/Linux)
        # 48       2    prodos_type  (data[1] LE)
        # 50       4    prodos_aux   (data[3]:data[2] LE)
        # 54       6    reserved
        magic   = bytes.fromhex('41465000')
        version = bytes.fromhex('00000100')
        zeroes4 = b'\x00' * 4
        prodos_type = bytes([data[1], 0x00])
        prodos_aux  = bytes([data[3], data[2], 0x00, 0x00])
        reserved    = b'\x00' * 6
        afp = magic + version + zeroes4 + zeroes4 + data + prodos_type + prodos_aux + reserved
        assert len(afp) == 60
        try:
            with open(f'{path}:AFP_AfpInfo', 'wb') as f:
                f.write(afp)
        except OSError as e:
            print(f'error: AFP_AfpInfo write failed: {e}', file=sys.stderr)
            sys.exit(1)

    else:
        print(f'warning: unknown platform {system!r} — FinderInfo not set', file=sys.stderr)
        # Don't exit 1; allow build to continue on unknown platforms.

if __name__ == '__main__':
    main()
