#!/usr/bin/env python3
"""
phase8c_image.py -- Build a GNO/ME ProDOS disk image

Creates a 32MB .2mg ProDOS disk image containing all GNO/ME files.

Source policy (Phase 9 — Source Completeness):
  - Executables and libraries ($B5, $B3, $B2, $BB) MUST come from gno-obj/.
    Any reference-disk binary not present in gno-obj/ is an error.
    Use --warn-missing to demote these errors to warnings (for gradual porting).
  - A small whitelist of SDK-supplied files (sysfloat) is exempt from this rule.
  - Text, config, and data files use verbatim/ overrides first, then the
    reference extraction as a fallback (these are not built from source).

Usage:
    python3 goldengate/build/phase8c_image.py [--output /path/to/gno.2mg] [--dry-run] [-v]
    python3 goldengate/build/phase8c_image.py --warn-missing   # treat missing binaries as warnings

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
GNO_OBJ   = REPO_ROOT / 'gno_obj'
EXTRACTED = REPO_ROOT / 'diskImages' / 'extracted'
VERBATIM  = REPO_ROOT / 'verbatim'
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

# ProDOS types that MUST come from gno-obj/ (built from source).
# Anything else is a missing-binary error (or warning with --warn-missing).
BINARY_TYPES = {'$B5', '$B3', '$B2', '$BB', '$B1'}

# Files exempt from the "must be built" rule.
# These are built from source but live outside gno-obj/ (e.g. installed to the
# GoldenGate SDK tree).  For each, GG_LOOKUP provides the resolved path.
# If the resolved path doesn't exist either, it falls back to the reference
# extraction so the disk can still be built for testing.
BINARY_EXEMPT = {
    'lib/sysfloat',   # SysFloat floating-point library — GoldenGate SDK
    'lib/orcalib',    # ORCA Runtime Library — byteworksinc-orcalib, installed to GoldenGate
}

def _gg_root() -> Path:
    """Locate the GoldenGate root (mirrors Makefile logic)."""
    for env in ('GOLDEN_GATE', 'ORCA_ROOT'):
        v = os.environ.get(env)
        if v:
            return Path(v)
    return Path.home() / 'Library' / 'GoldenGate'

GG_ROOT = _gg_root()

# Maps metadata local_path → absolute path for exempt binaries in GoldenGate
GG_LOOKUP: dict[str, Path] = {
    'lib/sysfloat': GG_ROOT / 'Libraries' / 'SysFloat',
    'lib/orcalib':  GG_ROOT / 'lib' / 'ORCALib',
}

# ProDOS type → cadius hex suffix (type byte + 4-digit aux type)
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
    'lib/lsaneglue': 'B20000',
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
    """Return resource fork bytes (com.apple.ResourceFork xattr), or b'' if absent."""
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
    except (OSError, Exception):
        pass
    return b''


def read_finder_info(path: Path) -> tuple[int, int] | None:
    """Read ProDOS type+aux from macOS FinderInfo xattr.

    macOS stores GS/OS file types in com.apple.FinderInfo as:
      bytes 0-3  = Mac file type (4 chars)
      bytes 4-7  = Mac creator (4 chars)
    When creator is 'pdos', the type field encodes ProDOS metadata:
      - 'p' + <1 byte prodos-type> + <2 bytes aux type>  (the common case)
      - 'TEXT' / 'PSYS' / etc. for well-known synonyms
    Returns (type, aux) or None if not a GS/OS-tagged file.
    """
    try:
        result = subprocess.run(
            ['xattr', '-px', 'com.apple.FinderInfo', str(path)],
            capture_output=True, text=True
        )
        if result.returncode != 0 or not result.stdout.strip():
            return None
        fi = bytes.fromhex(result.stdout.replace('\n', '').replace(' ', ''))
        if len(fi) < 8:
            return None
        creator = fi[4:8]
        if creator != b'pdos':
            return None
        mac_type = fi[0:4]
        if mac_type[0:1] == b'p':
            # 'p' + prodos-type + 2-byte aux (big-endian in FinderInfo)
            prodos_type = mac_type[1]
            aux = (mac_type[2] << 8) | mac_type[3]
            return (prodos_type, aux)
        if mac_type == b'TEXT':
            return (0x04, 0x0000)
        if mac_type == b'BINA':
            return (0x06, 0x0000)
        if mac_type == b'PSYS':
            return (0xFF, 0x0000)
        return None
    except Exception:
        return None


def goldengate_type_for(path: Path, is_rsrc: bool = False) -> str:
    """Return cadius-style #TTAAAA suffix for a GoldenGate file.

    Resource-forked EXE/S16 files need aux $0100; otherwise use FinderInfo
    if available. Fall back to $04 (TEXT) for files with no metadata.
    """
    fi = read_finder_info(path)
    if fi is not None:
        ptype, aux = fi
        return f'{ptype:02X}{aux:04X}'
    # Fall back: if adjacent _rsrc_ sibling exists, assume EXE
    rsrc = path.parent / (path.name + '_rsrc_')
    if rsrc.exists():
        return 'B50100'
    # Plain text default
    return '040000'


def lf_to_cr(data: bytes) -> bytes:
    """Convert Unix LF line endings to IIgs CR line endings."""
    return data.replace(b'\r\n', b'\r').replace(b'\n', b'\r')


def stage_file(staging: Path, rel_dir: str, name: str, type_sfx: str,
               data_src: Path, rsrc_data: bytes, convert_lf: bool = False) -> Path:
    """Copy data_src to staging/<rel_dir>/<name>#<type_sfx>, with optional resource fork."""
    staged_name = f'{name}#{type_sfx}'
    staged_dir  = staging / rel_dir
    staged_dir.mkdir(parents=True, exist_ok=True)
    staged_file = staged_dir / staged_name

    if convert_lf:
        staged_file.write_bytes(lf_to_cr(data_src.read_bytes()))
    else:
        shutil.copy2(str(data_src), str(staged_file))
    os.chmod(staged_file, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)

    if rsrc_data:
        rsrc_out = staged_dir / f'{staged_name}_ResourceFork.bin'
        rsrc_out.write_bytes(rsrc_data)

    return staged_file


def _verbatim_path(local: str) -> Path:
    """
    Return the verbatim/ override path for a reference local_path, if it exists.

    verbatim/ mirrors the GNO filesystem layout.  verbatim/boot/ is for the
    separate installer disk and is excluded here.
    """
    candidate = VERBATIM / local
    if candidate.exists() and candidate.is_file():
        # Exclude verbatim/boot/ — that's for the installer disk, not the main GNO volume
        if candidate.relative_to(VERBATIM).parts[0] != 'boot':
            return candidate
    return None


def populate_staging(staging: Path, metadata: list,
                     verbose: bool, warn_missing: bool) -> tuple:
    """
    Populate staging directory from metadata entries.

    Binary types ($B5/$B3/$B2/$BB/$B1):
      - Must come from gno-obj/.  Missing = error (or warning with --warn-missing).
      - BINARY_EXEMPT paths fall back to the reference extraction silently.

    Text/data/config types:
      - Use verbatim/ override first (with LF→CR conversion), then reference.

    Returns (placed_dict, covered_gnoobj_set, errors_list)
    """
    placed        = {}
    covered_gnoobj = set()
    errors        = []

    for entry in metadata:
        prodos   = entry['prodos_path']
        local    = entry['local_path']
        rsrc_rel = entry['rsrc_path']
        ftype    = entry['file_type']
        size     = entry['data_fork_bytes']

        gnoobj_rel = GNOOBJ_PATH_REMAP.get(local, local)
        gnoobj_src = GNO_OBJ / gnoobj_rel
        ref_src    = EXTRACTED / local
        is_binary  = ftype in BINARY_TYPES
        is_exempt  = local in BINARY_EXEMPT    # keyed by original local_path, not remapped

        # ── Determine source ───────────────────────────────────────────────
        convert_lf = False

        if gnoobj_src.exists():
            data_src  = gnoobj_src
            type_sfx  = get_type_suffix_for_gnoobj(gnoobj_rel)
            rsrc_data = read_resource_fork_xattr(data_src)
            covered_gnoobj.add(gnoobj_rel)
            src_tag   = 'built'

        elif is_binary and not is_exempt:
            # Binary required from source but not built — flag it
            msg = f'{prodos} ({ftype}, {size}B) — not in gno-obj/{gnoobj_rel}'
            errors.append(msg)
            if warn_missing:
                # Fall back to reference extraction so the image is still bootable
                if ref_src.exists():
                    print(f'  WARN: {msg}')
                    data_src  = ref_src
                    type_sfx  = TYPE_SUFFIX.get(ftype, '000000')
                    rsrc_data = b''
                    if rsrc_rel:
                        rsrc_path = EXTRACTED / rsrc_rel
                        if rsrc_path.exists():
                            rsrc_data = rsrc_path.read_bytes()
                    src_tag = 'ref  '
                else:
                    print(f'  WARN: {msg}  (no reference fallback either)')
                    continue
            else:
                print(f'  [ERROR] MISSING BUILT BINARY: {msg}')
                continue

        elif is_exempt and (gg_path := GG_LOOKUP.get(local)) and gg_path.exists():
            # Exempt binary found in GoldenGate installation
            data_src  = gg_path
            type_sfx  = get_type_suffix_for_gnoobj(gnoobj_rel)
            rsrc_data = read_resource_fork_xattr(data_src)
            covered_gnoobj.add(gnoobj_rel)
            src_tag   = 'goldengate'

        else:
            # Non-binary data file — use verbatim/ first, then reference extraction.
            # Check verbatim even when ref_src doesn't exist (cadius skips empty files).
            verbatim_src = _verbatim_path(local)
            if verbatim_src:
                data_src   = verbatim_src
                convert_lf = True   # verbatim files have Unix LF; IIgs needs CR
                src_tag    = 'verbatim'
            elif ref_src.exists():
                data_src = ref_src
                src_tag  = 'ref  '
            else:
                if verbose:
                    print(f'  [skip ] {prodos}  (no source at all)')
                continue
            type_sfx  = TYPE_SUFFIX.get(ftype, '000000')
            rsrc_data = b''
            if rsrc_rel:
                rsrc_path = EXTRACTED / rsrc_rel
                if rsrc_path.exists():
                    rsrc_data = rsrc_path.read_bytes()

        # ── Stage the file ─────────────────────────────────────────────────
        parts     = prodos.strip('/').split('/')
        rel_dir   = '/'.join(parts[:-1]).lower()
        name      = parts[-1].lower()

        staged_file = stage_file(staging, rel_dir, name, type_sfx,
                                 data_src, rsrc_data, convert_lf)
        placed[prodos] = staged_file

        if verbose:
            rsrc_tag = f' +rsrc({len(rsrc_data)}B)' if rsrc_data else ''
            print(f'  [{src_tag}] {prodos:40s} #{type_sfx}{rsrc_tag}')

    return placed, covered_gnoobj, errors


GOLDENGATE_LANG_MAP = {
    # <GoldenGate subdir>: <prodos path under /lang/orca>
    #
    # Note: /lang/orca/libraries is populated from ~/Library/GoldenGate/lib,
    # not from ~/Library/GoldenGate/Libraries.  The lowercase lib dir is the
    # one GoldenGate's iix tools actively read at link time; it contains the
    # current set of runtime libraries, headers, and include files.
    'Shell':     'lang/orca/shell',
    'Languages': 'lang/orca/languages',
    'Utilities': 'lang/orca/utilities',
    'lib':       'lang/orca/libraries',
}

# Per-subdir whitelists: when present, only top-level entries in the set are
# staged (compared case-insensitively).  Entries may name either files or
# directories; a whitelisted directory is staged recursively in full.  Subdirs
# without an entry here are staged with no restriction.
GOLDENGATE_LANG_WHITELIST = {
    'Languages': {
        'Asm65816', 'BASIC', 'Linker', 'Pascal', 'Rez',
        'cc', 'IBASIC', 'Modula2',
    },
    'Utilities': {
        'CAL', 'Help', 'DISASM', 'MakeLib', 'CHECK', 'DISASM.Data',
        'RemoveRez', 'ResEqual', 'CMP', 'DiskCheck', 'Compact',
        'DumpObj', 'SORT', 'CompileTool', 'STRIPC', 'EnTab', 'STRIPW',
        'Convert', 'Express', 'TCMP', 'Crunch', 'TEE', 'DebugBreak',
        'UNIQ', 'DebugFast', 'linker', 'UPPER', 'DebugNoFast', 'LOWER',
        'WC', 'DeRez', 'MacGen', 'DeToke', 'MakeBin', 'PRIZM',
    },
}

# Staged renames: some GoldenGate files have names that violate ProDOS rules
# (underscores, hyphens, etc).  Rather than drop them, map them to ProDOS-safe
# names here.  Key is the path relative to GG_ROOT, value is the replacement
# basename used in the ProDOS image.  No references in this repo or in the
# GoldenGate tree itself point at these files by name, so renaming is safe.
GOLDENGATE_RENAMES = {
    'lib/ORCACDefs/gno_compat.h': 'gnocompat.h',
}


def is_valid_prodos_name(name: str) -> bool:
    """ProDOS filenames: 1-15 chars, start with letter, letters/digits/dots only."""
    if not name or len(name) > 15:
        return False
    if not (name[0].isalpha()):
        return False
    for c in name:
        if not (c.isalnum() or c == '.'):
            return False
    return True


def populate_goldengate_lang(staging: Path, verbose: bool) -> dict:
    """Stage /lang/orca/{shell,languages,utilities,libraries} from the local
    GoldenGate SDK installation (~/Library/GoldenGate).  Each file's ProDOS
    type is read from its macOS FinderInfo xattr; resource forks stored as
    _rsrc_ sidecar files are staged alongside the data fork.

    Files whose names don't fit ProDOS rules (e.g. .bak backups, files with
    hyphens, overly long names, timestamped tmp files) are skipped with a
    warning so ADDFOLDER doesn't abort on them.
    """
    placed = {}
    skipped = 0
    if not GG_ROOT.exists():
        print(f'  WARN: GoldenGate root not found: {GG_ROOT}; skipping /lang')
        return placed

    for gg_sub, prodos_sub in GOLDENGATE_LANG_MAP.items():
        src_root = GG_ROOT / gg_sub
        if not src_root.exists():
            print(f'  WARN: {src_root} does not exist; skipping')
            continue
        whitelist = GOLDENGATE_LANG_WHITELIST.get(gg_sub)
        whitelist_lower = {n.lower() for n in whitelist} if whitelist else None
        for path in sorted(src_root.rglob('*')):
            if path.is_dir():
                continue
            if path.name.startswith('.'):
                continue
            # Skip resource-fork sidecars; they are paired with their data file
            if path.name.endswith('_rsrc_'):
                continue
            # Skip build-artifact and timestamped backup files
            lower = path.name.lower()
            if lower.endswith('.bak') or '.bak.' in lower or lower.endswith('.new_tmp'):
                skipped += 1
                continue
            # Per-subdir whitelist: if defined, the first path component
            # (file or directory) under <gg_sub> must be in the whitelist.
            # Whitelisted directories are staged recursively in full.
            rel_from_sub = path.relative_to(src_root)
            if whitelist_lower is not None:
                first_comp = rel_from_sub.parts[0].lower()
                if first_comp not in whitelist_lower:
                    skipped += 1
                    continue

            # Apply any explicit GOLDENGATE_RENAMES before ProDOS validation
            # (so renamed entries get validated under their new name).
            rel_from_root = path.relative_to(GG_ROOT).as_posix()
            stage_name    = GOLDENGATE_RENAMES.get(rel_from_root, path.name)

            if not is_valid_prodos_name(stage_name):
                if verbose:
                    print(f'  [skip ] {rel_from_root} (invalid ProDOS name)')
                skipped += 1
                continue

            rel      = path.relative_to(src_root)
            type_sfx = goldengate_type_for(path)
            rsrc_sib = path.parent / (path.name + '_rsrc_')
            rsrc_data = rsrc_sib.read_bytes() if rsrc_sib.exists() else b''

            rel_dir = (prodos_sub + '/' + '/'.join(rel.parent.parts)).rstrip('/')
            rel_dir = rel_dir.lower()
            name    = stage_name.lower()

            staged_file = stage_file(
                staging, rel_dir, name, type_sfx, path, rsrc_data
            )
            prodos_path = '/' + rel_dir.upper() + '/' + name.upper()
            placed[prodos_path] = staged_file
            if verbose:
                rsrc_tag = f' +rsrc({len(rsrc_data)}B)' if rsrc_data else ''
                print(f'  [gg   ] {prodos_path:50s} #{type_sfx}{rsrc_tag}')
    if skipped:
        print(f'  [gg   ] skipped {skipped} files (invalid ProDOS names / backups)')
    return placed


def populate_tmp(staging: Path, verbose: bool) -> dict:
    """Create /tmp with a placeholder text file 'stuff'."""
    tmp_dir = staging / 'tmp'
    tmp_dir.mkdir(parents=True, exist_ok=True)
    staged = tmp_dir / 'stuff#040000'
    staged.write_bytes(
        b'placeholder\rthis file exists so /tmp is a real directory\r'
    )
    os.chmod(staged, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
    if verbose:
        print(f'  [tmp  ] /TMP/STUFF                                         #040000')
    return {'/TMP/STUFF': staged}


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

        if any(rel.endswith(s) for s in GNOOBJ_SKIP_SUFFIXES):
            continue
        if path.name.startswith('.'):
            continue

        top_dir = rel.split('/')[0]
        if top_dir not in GNOOBJ_OUTPUT_DIRS:
            continue

        if rel in covered_gnoobj:
            continue

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


def build_image(output: Path, metadata: list, dry_run: bool,
                verbose: bool, warn_missing: bool):
    print(f'=== Phase 8c: building {output} ===')

    if not dry_run and not CADIUS.exists():
        print(f'ERROR: cadius not found at {CADIUS}', file=sys.stderr)
        print('Build it: cd ~/source/cadius && make', file=sys.stderr)
        sys.exit(1)

    staging = Path(tempfile.mkdtemp(prefix='gno-staging-'))
    print(f'Staging: {staging}')
    try:
        print(f'Populating staging ({len(metadata)} reference entries)...')
        placed, covered_gnoobj, errors = populate_staging(
            staging, metadata, verbose, warn_missing)
        print(f'  {len(placed)} files staged')

        if errors:
            print(f'\n{"WARNING" if warn_missing else "ERROR"}: '
                  f'{len(errors)} reference executable(s)/librar(ies) '
                  f'have no built version in gno-obj/:')
            for e in errors:
                print(f'  {"WARN" if warn_missing else "MISS"}: {e}')
            if not warn_missing:
                print('\nBuild these from source first, or run with --warn-missing.')
                sys.exit(1)

        print('Scanning gno-obj for extra built files...')
        extras = populate_gnoobj_extras(staging, covered_gnoobj, verbose)
        placed.update(extras)
        print(f'  {len(extras)} extra files staged  ({len(placed)} total)')

        print('Staging /lang/orca/* from local GoldenGate installation...')
        gg_placed = populate_goldengate_lang(staging, verbose)
        placed.update(gg_placed)
        print(f'  {len(gg_placed)} GoldenGate files staged')

        print('Creating /tmp with placeholder file...')
        tmp_placed = populate_tmp(staging, verbose)
        placed.update(tmp_placed)

        # ── Create volume ──────────────────────────────────────────────────
        if output.exists():
            output.unlink()
        print(f'Creating volume {VOLUME_NAME} ({VOLUME_SIZE})...')
        if not cadius_run(['CREATEVOLUME', str(output), VOLUME_NAME, VOLUME_SIZE],
                          dry_run, quiet=False):
            sys.exit(1)

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
    ap.add_argument('--warn-missing', action='store_true',
                    help='Treat missing built binaries as warnings instead of errors')
    args = ap.parse_args()

    if not METADATA.exists():
        print(f'ERROR: metadata not found: {METADATA}', file=sys.stderr)
        sys.exit(1)

    with open(METADATA) as f:
        metadata = json.load(f)

    build_image(Path(args.output), metadata, args.dry_run,
                args.verbose, args.warn_missing)


if __name__ == '__main__':
    main()
