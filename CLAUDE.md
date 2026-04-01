# GNO/ME — Build Project Guide

## What This Is

GNO/ME (GNO Multitasking Environment) is a complete Unix-like operating system for the Apple IIgs (65816 processor). This repository is the **ksherlock fork** of Devin Reade's original v2.0.6 work (~1997–1999). It contains:

- A 65816 kernel (GS/OS-hosted microkernel: processes, signals, TTY, pipes, sockets, ptys)
- A complete POSIX libc (~20 subdirectories)
- ~100 utilities across `bin/`, `usr.bin/`, `sbin/`, `usr.sbin/`
- 10+ libraries (libcurses, libtermcap, libcrypt, netdb, libutil, etc.)
- The ORCA/C runtime library (ORCALib) in 65816 assembly

## Project Goal

**Build GNO/ME from source on macOS using the GoldenGate/iix toolchain, producing a distributable archive (`.shk` or ProDOS disk image) that can be loaded onto real Apple IIgs hardware.**

The build does NOT need to run on the IIgs itself. GoldenGate acts as a cross-compiler host.

---

## Toolchain Reference

### iix — GoldenGate CLI wrapper

**Location:** `/usr/local/bin/iix`
**GoldenGate root:** `~/Library/GoldenGate/`

#### iix compile (ORCA/C 2.2.0)

```bash
iix compile foo.c            # standard ORCA SDK (no __GNO__)
iix --gno compile foo.c      # GNO SDK (__GNO__ defined via defaults.h)
```

**CLI flags** use ORCA `+`/`-` prefix, NOT POSIX style:
| Flag | Meaning |
|------|---------|
| `+O` | Enable optimizations (generic on/off — NOT a bitmask) |
| `+T` | Treat all errors as terminal |
| `-P` | Suppress "Compiling..." progress line |
| `+D` | Generate debug code |
| `+L` | Generate source listing |
| `-I` | Ignore/do not generate .sym file |
| `-R` | Rebuild .sym file |

**NOT supported by iix CLI** (must use `#pragma` in source):
- `-O78` → use `#pragma optimize 78` in source
- `-S segname` → use `#pragma segment segname` in source (`segment "name";` after `#ifdef __ORCAC__`)
- `-D MACRO` → no command-line define; add `#define` in source
- `-include file` → no prefix header support

**Output behavior:**
- `iix compile foo.c` → `foo.a` + `foo.root` + `foo.sym` in **CWD** (named from source basename)
- With `-o stem`: writes `stem.a` + `stem.root` (appends `.a` to the `-o` value — avoid using `-o`)
- Best Makefile pattern: `cd $(OBJ_DIR) && iix --gno compile $(SRC_DIR)/foo.c`
- If source has `#include "local.h"`, compile from SRC_DIR instead: `cd $(SRC_DIR) && iix compile foo.c && mv foo.a $(OBJ_DIR)/`

**File type:** iix compile sets FinderInfo to `$B1` (OBJ) automatically. No xattr patching needed.

**CRITICAL — GNO SDK:** Must use `iix --gno compile` for all GNO code. Without `--gno`, `__GNO__` is not defined and GNO-specific code paths (guarded by `#ifdef __GNO__`) are excluded. This causes missing types (`GSStringPtr`, `ResultBufPtr`) and missing errno values.

**Known compiler bugs:**
- `vfprintf.c` SPLIT_FILE_2 section: ORCA/C 2.2.0 hits internal "compiler error" (same bug as 2.1.1b2). Workaround: preprocess with macOS `clang -E`, strip `#` line directives, compile the flattened result.

#### iix assemble (ORCA/M Asm65816 2.1.0)

```bash
iix assemble +T foo.asm      # +T = terminal on first error
```

**Output:** `foo.A` + `foo.ROOT` in **CWD** (uppercase `.A` extension!)
**File type:** Sets `$B0` outside `/tmp` — **must patch to `$B1`:**
```bash
xattr -wx com.apple.FinderInfo "70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" file.a
```

**KEEP directive:** Assembler writes output named by `keep` directive in CWD. If no `keep`, uses source filename.
**MCOPY directive:** Resolves `.mac` files relative to CWD. Must `cd` to source directory before assembling.
**COPY directive:** Also resolves relative to CWD. For ORCA equate files (e.g., `E16.SANE`), symlink from `~/Library/GoldenGate/Libraries/AINClude/` into the build directory.

**ORCA/M macro rules** (see memory for complete list):
- `&variable` is expanded even in `*` comment lines → never use `&name` in comments
- `AIF` requires full boolean expression: `AIF &FLAG<>0,.LABEL` (not bare `AIF &FLAG,.LABEL`)
- Backward `AGO` (to label above) ALWAYS fails with "ACTR Count Exceeded" in GoldenGate → use recursive macros instead
- Branch target label lines are consumed but NOT executed → labels must stand alone on their own line
- `GBLA` re-declaration causes "Duplicate Label" → declare only once
- `&SYSCNT` labels: use `SKIP&SYSCNT` (no `@` prefix — `@SKIP&SYSCNT` causes "Operand Syntax")
- MCOPY files must have CR (0x0D) line endings, not LF

#### iix makelib (MakeLib 2.0)

```bash
iix makelib output_lib +file1.a +file2.a ...
```

- Accepts full paths: `+/path/to/file.a`
- **Command line length limit:** ~256 chars. For large libraries (>20 files), build in batches.
- Adding to an existing library works — call makelib multiple times with the same output file.
- Cannot combine libraries — only accepts individual `.a` object modules.
- Requires input files to have ProDOS type `$B1`. Assembly objects need xattr patching (see above).

#### iix link (Linker 2.1.0)

```bash
iix link -o output_binary input_module
iix --gno link -o output_binary input_module   # GNO SDK libraries
```

#### iix prefix — volume mapping

| Mode | Prefix 2/13 | Effect |
|------|-------------|--------|
| Standard (`iix`) | `Libraries/` | ORCA SDK headers in `Libraries/ORCACDefs/` |
| GNO (`iix --gno`) | `lib/` | GNO headers in `lib/ORCACDefs/` |

**Header shadowing fix (CRITICAL):**
ORCA toolbox headers (gsos.h, quickdraw.h, etc.) were copied from `Libraries/ORCACDefs/` into `lib/ORCACDefs/` so `--gno` mode can find them. But 15 standard C headers that exist in BOTH locations must be REMOVED from `lib/ORCACDefs/` to avoid shadowing the GNO versions in `usr/include/`:
Removed: `ctype.h errno.h fcntl.h limits.h locale.h math.h sane.h setjmp.h signal.h stddef.h stdio.h stdlib.h string.h time.h types.h`

The GNO `types.h` (from `usr/include/`) is a superset of the ORCA version — it has `#ifdef __GNO__` blocks that define `GSStringPtr`, `ResultBufPtr`, etc.

#### macgen (MacGen 2.0.3)

```bash
iix macgen -p source.asm output.mac macro_lib1 macro_lib2 ...
```
Generates `.mac` files containing only macros used by the source. Pre-generated `.mac` files exist in `lib/libc/gno/` so macgen invocation is usually not needed.

ORCA macro libraries: `~/Library/GoldenGate/Libraries/ORCAInclude/m16.Tools`, `m16.ORCA`, etc.

### Disk Image / Validation Tools

| Tool | Location | Notes |
|------|----------|-------|
| AppleCommander | `~/Library/Mobile Documents/com~apple~CloudDocs/NotesAndStuff/IIgs/Apple Commander/AppleCommander-macosx-1.4.0.jar` | Java required; cannot extract ProDOS extended files ($05) |
| Java | `/opt/homebrew/opt/openjdk/bin/java` | brew-installed; not in default PATH |
| nulib2 | `/Users/smentzer/source/iigs-official-repos/nulib2/nulib2/` | Source only; `./configure && make` |

**Reference disk images:** `diskImages/gno_206/gno.po` (ProDOS, 32MB, 804 entries)
**Extracted files:** `diskImages/extracted/` — all files from gno.po with `metadata.json`
**Key reference sizes:**
| File | Bytes | Phase |
|------|-------|-------|
| `extracted/lib/libc` | 482,317 | Phase 3 |
| `extracted/lib/orcalib` | 27,910 | Phase 2 |
| `extracted/lib/sysfloat` | 28,175 | Phase 3 prereq |
| `extracted/kern` | 140,754 | Phase 7 |
| `extracted/usr/lib/libtermcap` | 40,386 | Phase 5 |
| `extracted/usr/lib/libcurses` | 80,535 | Phase 5 |

### What is NOT Available
- **dmake** — GNO's native build driver; replaced by GNU make
- **catrez** — resource fork tool; source in `usr.orca.bin/catrez/`; must be bootstrapped
- **gsh** — GNO shell; fails with version error in GoldenGate
- **GNO namespace** — `/src`, `/obj`, `/lang/orca` paths don't resolve in iix

---

## Current Status

### Completed

#### Phase 2 — ORCALib ✓
- `goldengate/build/orcalib.mk` — all 13 `.asm` modules → `orcalib` (61,277 bytes)
- Installed to `~/Library/GoldenGate/lib/ORCALib`

#### Phase 3 — libc ✓
- **9 subdirectories built:** gen, gno, locale, regex, stdio, stdlib, stdtime, string, sys
- **140 object modules** (6 asm + 134 C) → `gno-obj/lib/libc` (396,596 bytes)
- **99.6% symbol coverage** vs reference 2.0.6 (444/446 symbols match)
- 2 missing symbols (`_fnmatch_map`, `_getUserID`) — no source exists in GNO tree
- 36 extra symbols — ksherlock fork additions (strlcpy, strlcat, pread, pwrite, etc.)
- Makefiles: `goldengate/build/libc.mk` (top-level) + `libc_{gen,gno,locale,regex,stdio,stdlib,stdtime,string,sys}.mk`

**Source fixes applied during libc build:**
- `lib/libc/gno/stack.asm`: changed `mcopy :obj:gno:lib:libc:gno:stack.mac` → `mcopy stack.mac`
- `lib/libc/stdlib/fpspecnum.asm`: changed `copy :lang:orca:...:e16.sane` → `copy E16.SANE` (symlinked)
- `lib/libc/sys/syscall.c`: fixed 6 missing semicolons in `pread`/`pwrite`
- `lib/libc/regex/regcomp.c`: added `#define POSIX_MISTAKE`
- `lib/libc/regex/regex2.h`: cast shift operands to `(sop)` — `int<<27` overflows 16-bit
- `lib/libc/stdio/vfprintf1.c` + `vfprintf2.c`: wrapper files for SPLIT_FILE defines
- `lib/libc/stdio/vfprintf2`: macOS `clang -E` preprocessing workaround

#### Test Suites ✓
- **ORCA/C C99/C11**: 27 positive + 4 negative compile tests — all pass
- **Stack/ABI**: 6 tests — all pass
- **Standard library**: 11 compile + 6 runtime — all pass
- **ORCA/M macros**: 11 positive + 1 negative — all 12 pass
- Run: `make -f goldengate/orcac-tests/Makefile` and `make -f goldengate/orca-m-tests/Makefile`

#### ORCA/M Build from Source ✓
- `goldengate/orca-m/Makefile` — builds Asm65816 2.1.0 (54,297 bytes)

### Next Steps (in order)
- [ ] **Bootstrap catrez**: compile `usr.orca.bin/catrez/` — needed to attach resource forks
- [ ] **Phase 5 — Support libraries**: lsaneglue → libcrypt → libutil → libtermcap → libcurses → liby → netdb → libcontrib
- [ ] **Phase 6 — Utilities**: bin/, usr.bin/, usr.orca.bin/, sbin/, usr.sbin/
- [ ] **Phase 7 — Kernel**: kern/gno/, kern/drivers/
- [ ] **Phase 8 — Distribution**: nulib2 .shk or cadius disk image

### Known Skips
- `libedit` / `libsim` — not building in original
- `fudgeinstall` / `mkboot` / `mkdisk1` / `mkdisk2` — replaced by macOS packaging

---

## Build Quick Reference

```bash
# Build ORCALib
make -f goldengate/build/orcalib.mk
make -f goldengate/build/orcalib.mk install

# Build libc (all subdirs + combine)
make -f goldengate/build/libc.mk

# Build individual libc subdir
make -f goldengate/build/libc_gen.mk

# Validate libc against 2.0.6 reference
make -f goldengate/build/libc.mk validate

# Compare libc symbols
python3 goldengate/tools/compare_libc.py

# Run ORCA/C test suite
make -f goldengate/orcac-tests/Makefile all-stdlib

# Run ORCA/M macro test suite
make -f goldengate/orca-m-tests/Makefile

# Disassemble an OMF object
python3 goldengate/orcac-tests/tools/omf_dis.py path/to/file.a
```

---

## Reference Materials

See `goldengate/index.html` for a full browsable index.

### On-disk Archive: `/Volumes/Storage/IIgs/`

| Path | Contents |
|------|---------|
| `Development/ORCA/Documentation/GS-06 ORCA:C 2.0.pdf` | ORCA/C compiler manual |
| `Development/ORCA/Documentation/GS-04 ORCA:M 2.0.pdf` | ORCA/M assembler manual |
| `Development/ORCA/Software/ORCAC.220B3.shk` | ORCA/C 2.2.0 beta 3 |
| `Development/Opus ][/Extracted/Source/Source/ORCA/` | ORCA/M 2.1.0, MacGen, Linker source |
| `Documentation/*.pdf` | Apple IIgs hardware/firmware references |

### Local Canonical Repo Clones — `/Users/smentzer/source/iigs-official-repos/`

| Directory | Contents |
|-----------|---------|
| `byteworks-orca-c` | ByteWorks ORCA/C compiler source |
| `byteworks-orcalib` | ByteWorks ORCALib (SysFloat, SysFPEFloat, runtime) |
| `gno-original` | Original Devin Reade GNO/ME v2.0.6 source |
| `goldengate` | GoldenGate iix emulator source |
| `ksherlock-gno` | ksherlock fork of GNO/ME (this repo's parent) |
| `ksherlock-orca-c` | ksherlock fork of ORCA/C |
| `nulib2` | nulib2 — ShrinkIt archive tool source |

---

## Key File Locations

| File | Purpose |
|------|---------|
| `NOTES/devel/doing.builds` | **Authoritative build sequence** |
| `goldengate/build/*.mk` | GNU Makefiles for each build target |
| `goldengate/tools/compare_libc.py` | Symbol comparison between built and reference libc |
| `goldengate/orcac-tests/tools/omf_dis.py` | OMF v2 parser + 65816 disassembler |
| `diskImages/extracted/` | All files from GNO 2.0.6 reference disk image |
| `diskImages/extracted/metadata.json` | File types, sizes, dates for all extracted files |

### goldengate/build/ Makefiles

| Makefile | Source | Output |
|----------|--------|--------|
| `orcalib.mk` | `lib/ORCALib/*.asm` (13 files) | `gno-obj/orcalib` |
| `libc.mk` | Top-level: invokes all libc_*.mk | `gno-obj/lib/libc` |
| `libc_gen.mk` | `lib/libc/gen/` (27 C + 1 asm) | `gno-obj/libc_gen.a` |
| `libc_gno.mk` | `lib/libc/gno/` (5 C + 3 asm) | `gno-obj/libc_gno.a` |
| `libc_locale.mk` | `lib/libc/locale/` (1 C) | `gno-obj/libc_locale.a` |
| `libc_regex.mk` | `lib/libc/regex/` (4 C) | `gno-obj/libc_regex.a` |
| `libc_stdio.mk` | `lib/libc/stdio/` (64 C) | `gno-obj/libc_stdio.a` |
| `libc_stdlib.mk` | `lib/libc/stdlib/` (4 C + 1 asm) | `gno-obj/libc_stdlib.a` |
| `libc_stdtime.mk` | `lib/libc/stdtime/` (1 C) | `gno-obj/libc_stdtime.a` |
| `libc_string.mk` | `lib/libc/string/` (23 C) | `gno-obj/libc_string.a` |
| `libc_sys.mk` | `lib/libc/sys/` (2 C + 1 asm) | `gno-obj/libc_sys.a` |
