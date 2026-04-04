#!/usr/bin/env python3
"""
phase8c_image.py -- Build a GNO/ME ProDOS disk image

Creates a 32MB .2mg ProDOS disk image containing all GNO/ME files by:
  1. Preferring built files from gno-obj/ over reference extractions
  2. Falling back to diskImages/extracted/ for files we didn't build
  3. Including resource forks (from com.apple.ResourceFork xattr or .rsrc sidecars)
  4. Encoding ProDOS file types in cadius #TTAAAA filename suffixes
  5. Including gno-obj extras (ksherlock fork additions not in 2.0.6 reference)

Usage:
    python3 goldengate/build/phase8c_image.py [--output /path/to/gno.2mg] [--dry-run] [-v]

cadius must be built and accessible (see CLAUDE.md: ~/source/cadius/cadius).
"""

import argparse
import json
import os
import platform
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


# ── Configuration ─────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GNO_OBJ   = REPO_ROOT.parent / 'gno-obj'
EXTRACTED = REPO_ROOT / 'diskImages' / 'extracted'
METADATA  = EXTRACTED / 'metadata.json'


def _find_cadius() -> Path:
    """Locate cadius: $CADIUS env var → PATH → ~/source/cadius/cadius."""
    env = os.environ.get('CADIUS')
    if env:
        return Path(env)
    which = shutil.which('cadius')
    if which:
        return Path(which)
    return Path.home() / 'source' / 'cadius' / 'cadius'

CADIUS = _find_cadius()
VOLUME_NAME  = 'GNO'
VOLUME_SIZE  = '32MB'

# ProDOS type → cadius hex suffix (type byte + 4-digit aux type)
# Based on GNO 2.0.6 reference disk catalog analysis
TYPE_SUFFIX = {
    '$B5': 'B50100',   # GS/OS application (EXE)
    '$B3': 'B30000',   # System file (kernel, S16)
    '$B2': 'B20000',   # OMF library (LIB)
    '$BB': 'BB7E01',   # Device driver (DVR)
    '$B0': 'B00000',   # Source file (SRC)
    '$B1': 'B10000',   # Object module (OBJ)
    '$B6': 'B60000',   # NDA
    '$B8': 'B80000',   # CDA
    '$B9': 'B90000',   # Tool
    '$BA': 'BA0000',   # Init
    '$BD': 'BD0000',   # Font
    '$BE': 'BE0000',   # Photo Album
    '$BF': 'BF0000',   # Packed
    '$C9': 'C90000',   # Finder data (FND)
    '$04': '040000',   # Text (TXT)
    '$06': '060000',   # Binary (BIN)
    '$F9': 'F90000',
    '$00': '000000',
}

# Override map: gno-obj relative path → ProDOS type suffix
GNOOBJ_TYPE = {
    'kern':          'B30000',
    'dev/null':      'BB7E01',
    'dev/zero':      'BB7E01',
    'dev/full':      'BB7E01',
    'dev/console':   'BB7E01',
    'lib/lsaneglue': 'B20000',   # OMF library
}
# Directories whose contents are executables
EXE_DIRS = {
    'bin', 'sbin',
    'usr/bin', 'usr/sbin', 'usr/orca/bin',
}
# Directories whose contents are libraries
LIB_DIRS = {
    'lib', 'usr/lib',
}

# Remap: metadata local_path → actual gno-obj relative path
# For files where our built version lives at a different path than the reference
GNOOBJ_PATH_REMAP = {
    'lib/orcalib': 'orcalib',   # ORCALib build places output at gno-obj/orcalib
}

# Top-level directories in gno-obj containing installable output files
GNOOBJ_OUTPUT_DIRS = {'bin', 'sbin', 'usr', 'dev', 'lib'}

# Skip these suffixes in gno-obj (build artifacts / sentinel files)
GNOOBJ_SKIP_SUFFIXES = {'.done', '.root', '.sym', '.a', '.A'}


def get_type_suffix_for_gnoobj(rel_path: str) -> str:
    """Return cadius #TTAAAA suffix for a file in gno-obj/."""
    rel = rel_path.strip('/')
    if rel in GNOOBJ_TYPE:
        return GNOOBJ_TYPE[rel]
    top_dir = '/'.join(rel.split('/')[:2]) if '/' in rel else rel.split('/')[0]
    one_dir = rel.split('/')[0]
    if top_dir in EXE_DIRS or one_dir in {'bin', 'sbin'}:
        return 'B50100'
    if top_dir in LIB_DIRS or one_dir in {'lib'}:
        return 'B20000'
    return 'B50100'  # fallback: executable


def read_resource_fork_xattr(path: Path) -> bytes:
    """Return resource fork bytes (com.apple.ResourceFork xattr), or b'' if absent.

    macOS: reads com.apple.ResourceFork via xattr CLI
    Linux: reads user.com.apple.ResourceFork via os.getxattr()
    Windows: resource fork xattrs are not supported; always returns b''
    """
    system = platform.system()
    try:
        if system == 'Darwin':
            result = subprocess.run(
                ['xattr', '-px', 'com.apple.ResourceFork', str(path)],
                capture_output=True, text=True
            )
            if result.returncode == 0 and result.stdout.strip():
                return bytes.fromhex(result.stdout.replace('\n', '').replace(' ', ''))
        elif system == 'Linux':
            data = os.getxattr(str(path), 'user.com.apple.ResourceFork')
            return data if data else b''
        # Windows: no xattr support; resource forks not preserved — return empty
    except (OSError, Exception):
        pass
    return b''


def stage_file(staging: Path, rel_dir: str, name: str, type_sfx: str,
               data_src: Path, rsrc_data: bytes) -> Path:
    """Copy data_src to staging/<rel_dir>/<name>#<type_sfx>, with optional resource fork."""
    staged_name = f'{name}#{type_sfx}'
    staged_dir  = staging / rel_dir
    staged_dir.mkdir(parents=True, exist_ok=True)
    staged_file = staged_dir / staged_name

    shutil.copy2(str(data_src), str(staged_file))
    os.chmod(staged_file, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)

    if rsrc_data:
        rsrc_out = staged_dir / f'{staged_name}_ResourceFork.bin'
        rsrc_out.write_bytes(rsrc_data)

    return staged_file


def populate_staging(staging: Path, metadata: list, verbose: bool) -> tuple:
    """
    Populate staging directory from metadata entries.

    For each entry:
    - Pick source: gno-obj/ (preferred, with path remap) or extracted/
    - Determine ProDOS type suffix
    - Copy file + optional resource fork to staging area

    Returns (placed_dict, covered_gnoobj_set)
      placed_dict: prodos_path → staging_file_path
      covered_gnoobj_set: gno-obj relative paths already staged
    """
    placed = {}
    covered_gnoobj = set()

    for entry in metadata:
        prodos   = entry['prodos_path']       # e.g. /BIN/CAT
        local    = entry['local_path']        # e.g. bin/cat
        rsrc_rel = entry['rsrc_path']         # e.g. bin/cat.rsrc or None
        ftype    = entry['file_type']         # e.g. $B5

        # Allow path remap (e.g., lib/orcalib → orcalib at top of gno-obj)
        gnoobj_rel = GNOOBJ_PATH_REMAP.get(local, local)
        gnoobj_src = GNO_OBJ / gnoobj_rel
        ref_src    = EXTRACTED / local

        if gnoobj_src.exists():
            data_src  = gnoobj_src
            type_sfx  = get_type_suffix_for_gnoobj(gnoobj_rel)
            rsrc_data = read_resource_fork_xattr(data_src)
            covered_gnoobj.add(gnoobj_rel)
        elif ref_src.exists():
            data_src  = ref_src
            type_sfx  = TYPE_SUFFIX.get(ftype, '000000')
            rsrc_data = b''
            if rsrc_rel:
                rsrc_path = EXTRACTED / rsrc_rel
                if rsrc_path.exists():
                    rsrc_data = rsrc_path.read_bytes()
        else:
            if verbose:
                print(f'  SKIP (no source): {prodos}')
            continue

        parts     = prodos.strip('/').split('/')
        rel_dir   = '/'.join(parts[:-1]).lower()
        name      = parts[-1].lower()

        staged_file = stage_file(staging, rel_dir, name, type_sfx, data_src, rsrc_data)
        placed[prodos] = staged_file

        if verbose:
            src_tag  = 'built' if gnoobj_src.exists() else 'ref  '
            rsrc_tag = f' +rsrc({len(rsrc_data)}B)' if rsrc_data else ''
            print(f'  [{src_tag}] {prodos:40s} #{type_sfx}{rsrc_tag}')

    return placed, covered_gnoobj


def populate_gnoobj_extras(staging: Path, covered_gnoobj: set, verbose: bool) -> dict:
    """
    Stage gno-obj files not covered by the reference metadata pass.

    These are ksherlock fork additions: new utilities, extra drivers, etc.
    Returns dict: prodos_path → staging_file_path
    """
    extras = {}

    for path in sorted(GNO_OBJ.rglob('*')):
        if path.is_dir():
            continue

        rel = str(path.relative_to(GNO_OBJ))

        # Skip build artifacts and sentinel files
        if any(rel.endswith(s) for s in GNOOBJ_SKIP_SUFFIXES):
            continue
        if path.name.startswith('.'):
            continue

        # Only include files from installable output directories
        top_dir = rel.split('/')[0]
        if top_dir not in GNOOBJ_OUTPUT_DIRS:
            continue

        # Skip files already handled by the metadata pass
        if rel in covered_gnoobj:
            continue

        # Derive ProDOS path by uppercasing each component
        parts  = rel.split('/')
        prodos = '/' + '/'.join(p.upper() for p in parts)

        type_sfx  = get_type_suffix_for_gnoobj(rel)
        rsrc_data = read_resource_fork_xattr(path)

        rel_dir = '/'.join(parts[:-1]).lower()
        name    = parts[-1].lower()

        staged_file = stage_file(staging, rel_dir, name, type_sfx, path, rsrc_data)
        extras[prodos] = staged_file

        if verbose:
            rsrc_tag = f' +rsrc({len(rsrc_data)}B)' if rsrc_data else ''
            print(f'  [extra] {prodos:40s} #{type_sfx}{rsrc_tag}')

    return extras


def cadius_run(args: list, dry_run: bool, quiet: bool = True) -> bool:
    """Run cadius with given args. Returns True on success."""
    cmd = [str(CADIUS)] + args
    if quiet:
        cmd.append('--quiet')
    if dry_run:
        print(f'  [dry-run] {" ".join(cmd)}')
        return True
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f'  cadius ERROR: {result.stdout.strip()} {result.stderr.strip()}')
        return False
    return True


def build_image(output: Path, metadata: list, dry_run: bool, verbose: bool):
    print(f'=== Phase 8c: building {output} ===')

    if not dry_run and not CADIUS.exists():
        print(f'ERROR: cadius not found at {CADIUS}', file=sys.stderr)
        print('Build it: cd ~/source/cadius && make', file=sys.stderr)
        sys.exit(1)

    # ── Staging directory ──────────────────────────────────────────────────
    staging = Path(tempfile.mkdtemp(prefix='gno-staging-'))
    print(f'Staging: {staging}')
    try:
        print(f'Populating staging ({len(metadata)} reference entries)...')
        placed, covered_gnoobj = populate_staging(staging, metadata, verbose)
        print(f'  {len(placed)} files staged from reference/built')

        print('Scanning gno-obj for extra built files...')
        extras = populate_gnoobj_extras(staging, covered_gnoobj, verbose)
        placed.update(extras)
        print(f'  {len(extras)} extra files staged  ({len(placed)} total)')

        # ── Create volume ──────────────────────────────────────────────────
        if output.exists():
            output.unlink()
        print(f'Creating volume {VOLUME_NAME} ({VOLUME_SIZE})...')
        if not cadius_run(['CREATEVOLUME', str(output), VOLUME_NAME, VOLUME_SIZE],
                          dry_run, quiet=False):
            sys.exit(1)

        # ── Add all files in one recursive ADDFOLDER call ─────────────────
        # cadius ADDFOLDER is recursive: it traverses the staging tree and
        # creates subdirectories automatically.  A single call from the root
        # is simpler and avoids the "file already exists" error that occurs
        # when mixing per-directory ADDFOLDER calls with their parent.
        n_data = sum(1 for f in staging.rglob('*')
                     if f.is_file() and not f.name.endswith('_ResourceFork.bin'))
        print(f'Adding {n_data} files via ADDFOLDER (recursive from root)...')
        if not cadius_run(['ADDFOLDER', str(output), f'/{VOLUME_NAME}', str(staging)],
                          dry_run, quiet=False):
            print('ERROR: ADDFOLDER failed', file=sys.stderr)
            sys.exit(1)

        print('=== Done ===')
        if not dry_run:
            size_mb = output.stat().st_size / (1024 * 1024)
            print(f'Output: {output}  ({size_mb:.1f} MB)')

    finally:
        shutil.rmtree(staging, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description='Build GNO/ME ProDOS disk image')
    ap.add_argument('--output', default=str(REPO_ROOT / 'diskImages' / 'gno-built.2mg'),
                    help='Output .2mg path (default: diskImages/gno-built.2mg)')
    ap.add_argument('--dry-run', action='store_true',
                    help='Show what would be done without writing')
    ap.add_argument('-v', '--verbose', action='store_true',
                    help='Show each file being staged')
    args = ap.parse_args()

    if not METADATA.exists():
        print(f'ERROR: metadata not found: {METADATA}', file=sys.stderr)
        sys.exit(1)

    with open(METADATA) as f:
        metadata = json.load(f)

    build_image(Path(args.output), metadata, args.dry_run, args.verbose)


if __name__ == '__main__':
    main()
