# GNO/ME — Build Project Guide

## What This Is

GNO/ME (GNO Multitasking Environment) is a complete Unix-like operating system for the Apple IIgs (65816 processor). This repository is **smentzer's own fork** of the ksherlock/gno repository, created from ksherlock's master at commit `30344bf`. The ksherlock fork is no longer maintained. The first commit (`f76e43f`) adds all the GoldenGate cross-build infrastructure. It contains:

- A 65816 kernel (GS/OS-hosted microkernel: processes, signals, TTY, pipes, sockets, ptys)
- A complete POSIX libc (~20 subdirectories)
- ~100 utilities across `bin/`, `usr.bin/`, `sbin/`, `usr.sbin/`
- 10+ libraries (libcurses, libtermcap, libcrypt, netdb, libutil, etc.)
- The ORCA/C runtime library (ORCALib) in 65816 assembly

## Project Goal

**Build GNO/ME from source on macOS, Linux, or Windows using the GoldenGate/iix toolchain, producing a distributable archive (`.shk` or ProDOS disk image) that can be loaded onto real Apple IIgs hardware.**

The build does NOT need to run on the IIgs itself. GoldenGate acts as a cross-compiler host.

---

## Cross-Platform Build Support

All Makefiles and Python tools support macOS, Linux, and Windows (MSYS2/Git Bash).

### GoldenGate root — `$GOLDEN_GATE` env var

All Makefiles resolve GoldenGate via:
```makefile
GG_ROOT ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
```

| Platform | Default path | Override |
|----------|-------------|---------|
| macOS | `~/Library/GoldenGate` | `export GOLDEN_GATE=/path` |
| Linux | `/usr/local/share/GoldenGate` | `export GOLDEN_GATE=/path` |
| Windows (MSYS2) | (none — must set) | `export GOLDEN_GATE=/c/path` |

### ProDOS FinderInfo metadata — `goldengate/tools/set-finder-info.py`

Assembly object files must be tagged with ProDOS type `$B1` after `iix assemble`. All Makefiles call `set-finder-info.py` which handles all platforms:
- **macOS**: `xattr -wx com.apple.FinderInfo` (32-byte block)
- **Linux**: `os.setxattr('user.com.apple.FinderInfo', ...)` (same 32-byte block)
- **Windows**: writes `filename:AFP_AfpInfo` NTFS alternate data stream (60-byte AFP structure)

`.c`, `.asm`, `.pas` source files do NOT need explicit metadata — GoldenGate extension fallback handles them on all platforms.

### Resource fork xattrs — `cowrez.py` and `phase8c_image.py`

- `cowrez.py`: already cross-platform (macOS `xattr`, Linux `os.setxattr`, Windows unsupported → use `--output`)
- `phase8c_image.py`: reads `com.apple.ResourceFork` (macOS) or `user.com.apple.ResourceFork` (Linux)

### First-time setup

```bash
bash goldengate/setup.sh    # verifies iix, GG_ROOT, python3; creates output dirs
```

---

## Toolchain Reference

### iix — GoldenGate CLI wrapper

**Location:** `/usr/local/bin/iix`
**GoldenGate root:** `~/Library/GoldenGate/` (macOS default; set `$GOLDEN_GATE` on Linux/Windows)

#### iix compile (ORCA/C 2.2.2)

Installed from source at `/Users/smentzer/source/iigs-official-repos/byteworksinc-orca-c/` to `~/Library/GoldenGate/Languages/cc`. A 2.2.1 backup is at `cc.bak`.

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
- **OPEN — inline asm `sep`/`rep` + absolute-long LDA**: After `sep #0x30` (or `sep #0x20`) in an `asm {}` block, ORCA/C 2.2.2 inserts an extra `$00` byte before any `$AF` opcode (LDA absolute long). Result: the code emits `00 AF addr` (BRK #$AF) instead of `AF addr` (LDA $addr), crashing on hardware.
  - **Affected files in this repo**: `kern/gno/main.c:334` and `kern/gno/sys.c:615` — both contain the exact same pattern:
    ```c
    asm { lda 0xE0C035; sta state; sep #0x30; lda 0xE0C02D; sta slot; ... rep #0x30; }
    ```
  - **Root cause**: ORCA/C's inline asm emitter tracks M/X mode from raw `sep`/`rep` instructions and incorrectly emits a prefix byte for absolute-long loads when M=1. The 4-byte encoding `AF addr` is always correct regardless of M — no prefix needed.
  - **Fix location**: ORCA/C source at `/Users/smentzer/source/iigs-official-repos/byteworksinc-orca-c/` — find the inline-asm code generator path that fires when emitting `LDA` with a 24-bit operand while M=1.
  - **Do NOT work around in kernel source** — fix the compiler and rebuild.

#### iix assemble (ORCA/M Asm65816 2.1.0)

```bash
iix assemble +T foo.asm      # +T = terminal on first error
```

**Output:** `foo.A` + `foo.ROOT` in **CWD** (uppercase `.A` extension!)
**File type:** Sets `$B0` outside `/tmp` — **must patch to `$B1`** using the cross-platform helper:
```bash
python3 goldengate/tools/set-finder-info.py file.a \
  "70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
```
Why: GoldenGate only sets `$B1` for files in `/tmp` (prefix 3:). All other directories get `$B0`, which makelib silently rejects ("not an object module").
The helper handles macOS (xattr), Linux (os.setxattr), and Windows (AFP_AfpInfo NTFS stream).

**KEEP directive:** Assembler writes output named by `keep` directive in CWD. If no `keep`, uses source filename.
**MCOPY directive:** Resolves `.mac` files relative to CWD. Must `cd` to source directory before assembling.
**COPY directive:** Also resolves relative to CWD. For ORCA equate files (e.g., `E16.SANE`), symlink from `~/Library/GoldenGate/Libraries/AINClude/` into the build directory.

**ORCA/M macro rules** (determined by testing + reading ORCA/M source: FSntx.asm, FMcro.asm, Asm.asm):
- `&variable` is expanded even in `*` comment lines → never use `&name` in comments
- `AIF` requires full boolean expression: `AIF &FLAG<>0,.LABEL` (not bare `AIF &FLAG,.LABEL`)
- Backward `AGO` (to label above) ALWAYS fails with "ACTR Count Exceeded" in GoldenGate → use recursive macros instead:
  ```
           MACRO
           NOPS_N  &N
           AIF    &N=0,.DONE
           NOP
           NOPS_N  &N-1
  .DONE    ANOP
           MEND
  ```
- Forward `AGO` works correctly in all tested cases
- Branch target label lines are consumed but NOT executed → labels must stand alone on their own line:
  ```
  .TRYX              ← ALONE on this line
           AIF ...   ← this executes after branch to .TRYX
  ```
  NOT: `.TRYX    AIF ...` (AIF would NOT execute when branched to)
- `GBLA` re-declaration causes "Duplicate Label" → declare only once (in the initializing macro)
- `&SYSCNT` labels: use `SKIP&SYSCNT` (no `@` prefix — `@SKIP&SYSCNT` causes "Operand Syntax")
- MCOPY files must have CR (0x0D) line endings, not LF

#### iix makelib (MakeLib 2.2.4)

Source: `~/source/orca-makelib/`. Two bugs fixed from original 2.0:
- **2.2.3:** Multi-arg single invocation (fixed — now works with relative paths via `cd $(OBJ_DIR)` first)
- **2.2.4:** `Read4()` 16-bit sign-extension corrupted sSeg on incremental builds (linker "Out of memory")

```bash
iix makelib output_lib +file1.a +file2.a ...
```

- Accepts full paths: `+/path/to/file.a`
- **Command line length limit:** ~256 chars. For large libraries (>20 files), build in batches.
- Adding to an existing library works — call makelib multiple times with the same output file.
- Cannot combine libraries — only accepts individual `.a` object modules.
- Requires input files to have ProDOS type `$B1`. Assembly objects need xattr patching (see above).
- **CRITICAL:** Always `cd $(OBJ_DIR)` first and use relative filenames. Absolute paths still cause issues in multi-arg calls.
- **Batch pattern for large libraries:**
  ```bash
  cd $(OBJ_DIR) && ls *.a | sort | while read f; do echo "+$f"; done | \
      xargs -n 20 sh -c 'iix makelib /path/to/output "$@"' _
  ```

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

**Header setup for `--gno` mode:**
`lib/ORCACDefs/` is managed by `goldengate/install-gno-headers.mk` in this repo. Run it after any change to `include/` or after a fresh GoldenGate install:
```bash
make -f goldengate/install-gno-headers.mk
```
This copies ORCA toolbox headers from `Libraries/ORCACDefs/` as a base layer, then copies all GNO headers from `include/` on top (GNO wins for all overlapping files), and installs `orcacdefs/defaults.h`. No symlinks. No `usr/include/` dependency — all headers are regular files directly in `lib/ORCACDefs/`.

**Diagnostic:** If a GNO compilation fails with "undeclared identifier" for a GNO-specific type (e.g., `GSStringPtr`, `ResultBufPtr`), verify `lib/ORCACDefs/` contains the GNO versions of the headers by running `make -f goldengate/install-gno-headers.mk status`.

**GNO defaults.h** — located at `~/Library/GoldenGate/lib/ORCACDefs/defaults.h`:
```c
#define __appleiigs__
#define __GNO__
#pragma path "/usr/include"
#pragma path "/HFSinclude"
#pragma path "/lang/orca/libraries/orcacdefs"
```
This is what makes `iix --gno compile` define `__GNO__` and set up include paths.

#### macgen (MacGen 2.0.3)

```bash
iix macgen -p source.asm output.mac macro_lib1 macro_lib2 ...
```
Generates `.mac` files containing only macros used by the source. Pre-generated `.mac` files exist in `lib/libc/gno/` so macgen invocation is usually not needed.

ORCA macro libraries: `~/Library/GoldenGate/Libraries/ORCAInclude/m16.Tools`, `m16.ORCA`, etc.

### cowdiff — Canonical Disk Image Comparison Tool

**`goldengate/tools/cowdiff.py`** is the definitive tool for comparing GNO disk image content. Use it any time you need to understand how a built image differs from the reference, or to extract and inspect any ProDOS disk image.

**Inputs** (for both `reference` and `source`): `.po`/`.2mg`/`.hdv` disk image, an extracted directory, or a `metadata.json` file directly. Disk images are extracted automatically and cached in `~/.cache/cowdiff/<sha256>/` — re-running on the same image is instant.

**Comparison categories:**
- `IDENTICAL` — same path, type, auxtype, data SHA-256, rsrc SHA-256
- `CONTENT DIFFERS` — same path+type, different binary content (shows size delta)
- `TYPE/AUXTYPE DIFFERS` — same path, different ProDOS type or auxtype
- `RESOURCE FORK CHANGED` — data identical, rsrc added/removed/changed
- `PATH MISMATCH` — same filename + identical SHA-256, found at wrong path (basename + SHA-256 must both match)
- `MISSING` — in reference, not in source
- `EXTRA` — in source, not in reference
- `EXEMPT` — known GoldenGate SDK entries (`/lib/ORCALib`, `/lib/SysFloat`)

**Key flags:** `--types B5,B3,B2,BB` (binary types only), `-q` (summary), `--missing`, `--different`, `--json`, `--no-omf` (suppress OMF segment diff), `extract <image> [--out dir]`, `cache --list/--clear`

**cadius** (`~/source/cadius/cadius`) is the underlying extraction engine. Build from source if missing:
```bash
git clone https://github.com/mach-kernel/cadius.git ~/source/cadius && cd ~/source/cadius && make
```

### Disk Image / Archive Tools

| Format | Tool | Command | Notes |
|--------|------|---------|-------|
| `.2mg`, `.po`, `.hdv` (ProDOS) | **cowdiff** / **cadius** | `cowdiff extract image.po` or `cadius EXTRACTVOLUME image.po /out/` | cowdiff wraps cadius with caching + metadata |
| `.iso` (hybrid Apple/ISO 9660) | **7z** | `7z x image.iso -o/output/` | Only tool that works on macOS 26.x for hybrid Apple/ISO 9660 images |
| `.shk` (ShrinkIt) | **nulib2** | `nulib2 -xe archive.shk` | Extracts in CWD; `cd` to destination first |
| `.zip` | **unzip** | `unzip archive.zip -d /output/` | Standard |

| Tool | Location |
|------|----------|
| **cowdiff** | `goldengate/tools/cowdiff.py` |
| cadius | `~/source/cadius/cadius` |
| 7z (p7zip) | `/opt/homebrew/bin/7z` |
| nulib2 | `/Users/smentzer/source/nulib2/nulib2/nulib2` |

**IMPORTANT — AppleCommander:** listing only; fails on extended/forked files (type $05); cannot read ISO 9660.
**IMPORTANT — ISO 9660 hybrid images:** `hdiutil attach` and `bsdtar` both fail on macOS 26.x. Use `7z x` (each file appears twice — data+rsrc fork).

**Canonical reference disk image:** `/Volumes/Storage/IIgs/DocTemple/gno/2.0.6/dist/gno_206/gno.po` (ProDOS .po, 32MB)
**Reference cache** (auto-populated by cowdiff on first use): `~/.cache/cowdiff/<sha256>/metadata.json`

**Key reference sizes (from metadata.json):**
| File | Bytes | Phase |
|------|-------|-------|
| `/lib/libc` | 482,317 | Phase 3 |
| `/lib/ORCALib` | 27,910 | Phase 2 (exempt) |
| `/lib/SysFloat` | 28,175 | Phase 3 prereq (exempt) |
| `/kern` | 140,754 | Phase 7 |
| `/usr/lib/libtermcap` | 40,386 | Phase 5 |
| `/usr/lib/libcurses` | 80,535 | Phase 5 |
| `/usr/lib/libnetdb` | 80,506 | Phase 5 |
| `/usr/lib/libcrypt` | 7,180 | Phase 5 |
| `/usr/lib/libutil` | 2,146 | Phase 5 |
| `/usr/lib/liby` | 660 | Phase 5 |
| `/usr/lib/libcontrib` | 19,889 | Phase 5 |

### GNO Namespace Paths — DO NOT WORK in iix

Original GNO source files contain ProDOS namespace paths like:
- `mcopy :obj:gno:lib:libc:gno:stack.mac`
- `copy :lang:orca:libraries:ainclude:e16.sane`

These paths are resolved through the GNO namespace file (`/etc/namespace`) which maps volume prefixes like `:lang:` and `:obj:` to filesystem locations. GoldenGate does NOT support this namespace.

**Fix:** Change all namespace paths to relative paths (`stack.mac`, `E16.SANE`) and ensure the files are available in the working directory (via symlink or copy).

ORCA equate files (E16.SANE, E16.GSOS, etc.) are at: `~/Library/GoldenGate/Libraries/AINClude/`

### 65816 / ORCA/C Type System

| Type | Size on 65816 | Notes |
|------|---------------|-------|
| `char` | 8 bits | Params masked with `AND #$00FF` on every use |
| `int` | **16 bits** | This is the critical one — not 32 bits! |
| `unsigned` | 16 bits | Same as `unsigned int` |
| `long` | 32 bits | |
| `unsigned long` | 32 bits | |
| `extended` | 80 bits | ORCA/C extension: 80-bit SANE float |
| pointer | 32 bits | 24-bit address + 8-bit bank byte |

**Critical: Integer Overflow in Shift Expressions**
`int << 27` is undefined behavior on 65816 (16-bit int, shift width > bit width). Causes duplicate case labels and other silent corruption.
**Fix:** Cast the left operand: `(unsigned long)9 << 27` or `((sop)9 << OPSHIFT)`

**ORCA/C Extensions:**
- `segment "name";` — sets the OMF segment name for the following code
- `pascal` keyword — Pascal calling convention (callee cleans stack)
- `inline(toolnum, dispatch)` — inline toolbox call
- `#pragma optimize N` — bitmask: bit 1=const fold, bit 2=dead code, bit 3=?, bit 6=register opt
- `#pragma databank 1` — used in signal handlers and callbacks
- `#pragma debug N` — debug level

### What is NOT Available
- **dmake** — GNO's native build driver; replaced by GNU make
- **catrez** — resource fork tool; replaced by `goldengate/tools/cowrez.py`
- **gsh** — GNO shell; fails with version error in GoldenGate
- **GNO namespace** — `/src`, `/obj`, `/lang/orca` paths don't resolve in iix (see above)

### Common Source Patterns (when porting new source)

- **GNO namespace paths**: change `mcopy :obj:gno:...` → `mcopy file.mac`; symlink ORCA equate files from `Libraries/AINClude/`
- **`#pragma lint -1`**: ENABLES all lint (= 0xFFFF) — opposite of expectation; remove these pragmas
- **`-D MACRO` not supported**: add `#define` in a shared header included by all .c files
- **Code bank overflow** ("Code exceeds code bank size"): add `#pragma memorymodel 1` to a shared header; generates JSL instead of JSR, allowing code to span multiple 64KB banks
- **16-bit int overflow in shifts**: `int << N` where N≥16 is UB; cast: `(unsigned long)val << N`
- **`static char sccsid[]`**: triggers lint "unused variable"; use `static const char sccsid[]`
- **Library links**: `passwd`→libcrypt; `rmdir/removerez/whereis/newuser/install`→libcontrib; `tput/more`→libtermcap; `whois`→libnetdb; `printf`→SysFloat; `getty`→libutil

---

## Current Status

### Completed Phases

| Phase | Status | Output |
|-------|--------|--------|
| ORCA/C 2.2.2 | ✓ built + installed | `~/Library/GoldenGate/Languages/cc` |
| Phase 2 — ORCALib | ✓ | `~/Library/GoldenGate/lib/ORCALib` |
| Phase 3 — libc | ✓ 99.6% symbol coverage (444/446) | `gno-obj/lib/libc` |
| ORCA/M from source | ✓ | `goldengate/orca-m/Makefile` → Asm65816 2.1.0 |
| Phase 5 — Support Libraries | ✓ 9 libs (incl. libsim) | `gno-obj/usr/lib/lib*` |
| Phase 6 — Utilities | ✓ 147 built (incl. gsh, less, vi, grep, compress) | `gno-obj/bin/`, `gno-obj/usr/bin/` |
| Phase 7 — Kernel | ✓ | `gno-obj/kern` (150,673B; ref 140,754 — ~7% larger, ksherlock additions) |
| cowrez | ✓ | `goldengate/tools/cowrez.py` |
| Phase 8a — Resource forks | ✓ | attached via `phase8_rez.mk` |
| Phase 8b — ProDOS types | ✓ | set by iix linker automatically |
| Phase 8c — Disk image | ✓ | `diskImages/gno-built.2mg` (32MB, 714 files) |

**Test suites:** ORCA/C 42/42 + 6/6 runtime + 12/12 ORCA/M — all pass.

**Phase 3 libc notes:**
- 2 missing symbols (`_fnmatch_map`, `_getUserID`) — no source in GNO tree
- 36 extra symbols — ksherlock fork additions (strlcpy, strlcat, pread, pwrite, etc.)

**Phase 5 build notes:**
- lsaneglue: `.mac` files pre-generated by `iix macgen`; committed in `lib/lsaneglue/`
- libutil: only login.c, logintty.c, logwtmp.c compiled (not hexdump, pty, setproc, logout)
- libcurses: scanw.c excluded; all 40 .c files require `#define _CURSES_PRIVATE` prepended
- netdb: iso_addr.c, linkaddr.c, ns_addr.c, ns_ntoa.c, send.c, recv.c excluded
- libsim: Serial Interrupt Manager library; source from old-gno/sys/sim/simlib.asm; built via `goldengate/build/libsim.mk`; `lib/libsim/` in this repo

**Phase 6 utilities notes:**
- `false`, `true`, `tr` output to `gno-obj/bin/` (source in `usr.bin/`) — explicit targets in phase6.mk
- `awk`: 9 C files, pre-generated ytab.c/proctab.c — no yacc needed
- `cpp`: 10 C files; `#pragma memorymodel 1` in `cpp.h` fixes code bank overflow
- `nroff`: 9 C files; `isalpha(*optarg)` fix + `#pragma memorymodel 1` in `nroff.h`
- `initd`: reconstructed from 65816 disassembly; GNO-native (`union wait`, `fork(NULL)`)
- `date`, `purge`: ORCA/M assembly; `date` uses e16.ioctl equates
- `gsh`: 22 ORCA/M .asm files; linked 74,340B. Three ORCA/M bugs fixed: `incad @xa` forward-branch failure (split into `incaxa`), `subroutine` loop off-by-one for >9 params, data segment label name mismatches. Built via `goldengate/build/phase6_gsh.mk`.
- `grep`/`egrep`/`fgrep`: BSD port; single grep.c handles all three via symlinks
- `compress`/`uncompress`/`freeze`: BSD compress.c + freeze.c; each gets its own rez file
- `chmod`, `cp`, `echo`, `hostname`: simple C utilities written from scratch or ported
- `mktmp`: written from scratch (~20 lines; creates unique tmp file via mktemp())
- `runover`: written from scratch; runs a program over a tty (opens /dev/tty, redirects I/O)
- `unshar`, `setvers`: ported from GNO sources
- `vi`: Stevie vi editor, ported from old-gno — `#pragma memorymodel 1` in stevie.h; inline asm in fileio.c replaced with C; sys/ioctl.compat.h + sys/ttycom.h for sgttyb/TIOCSTI
- `less`: ported from old-gno
- Skipped — missing BSD headers: `init`, `reboot`, `shutdown`; network deps: `rcp`, `ftp`, `rlogin`, `rsh`, `inetd`, `syslogd`; no source in repo: `diff`, `dmake`
- `libsim`: Serial Interrupt Manager library — source from old-gno/sys/sim/simlib.asm; built via `goldengate/build/libsim.mk`

**Phase 7 kernel notes:**
- All 14 kern/gno C modules compiled with `#define KERNEL` before first include
- `include/stdio.h` has `#ifdef KERNEL` guard — kernel uses ORCALib `stdout`, not GNO libc array
- **Kernel compile mode: `iix --gno compile` (used for header path, NOT GNO semantics)**
  The kernel is a pure GS/OS application that ideally would be compiled without `--gno`. However, the ORCA SDK's `signal.h` (ByteWorks version, `Libraries/ORCACDefs/signal.h`) directly defines `SIG_IGN`/`SIG_ERR`/`SIGFPE` etc., while GNO's `sys/signal.h` also defines them. Without `--gno`, both get included → "cannot redefine a macro" errors. GNO's `signal.h` (`lib/ORCACDefs/signal.h`) properly wraps `sys/signal.h` via include guards, avoiding the conflict. So `--gno` is used as a workaround to get the GNO header path.
  **TODO:** Replace `Libraries/ORCACDefs/signal.h` with GNO's BSD version so the kernel can compile with `iix compile` (no `--gno`), eliminating the spurious `__GNO__` definition in kernel code.
- **Kernel link mode: `iix link` (NOT `iix --gno link`)** — links against ORCALib only; GNO libc is unavailable during kernel boot.
- **ORCALib ABI mismatch — systemic issue for all kernel C code:**
  ORCALib was compiled when `size_t = unsigned` (2 bytes). Current ORCA/C headers define `size_t = unsigned long` (4 bytes) in BOTH `iix compile` and `iix --gno compile` modes. Switching compile modes does NOT fix this. For any ORCALib function that historically took a `size_t` parameter, the kernel pushes 4 bytes but ORCALib's callee-cleans epilogue only pops 2 bytes → 2-byte stack leak per call → corrupted return-address bank byte → jump to garbage bank ($53, $55, etc.) → crash.
  - **Confirmed affected:** `fgets(char *, size_t, FILE *)` — ORCALib binary confirmed `csubroutine (4:s, 2:n, 4:stream), 2`; n is 2 bytes.
  - **Fix pattern** (required for every ORCALib `fgets` call in kernel code):
    ```c
    typedef char *(*fgets_orca_t)(char *, unsigned, FILE *);
    if (((fgets_orca_t)fgets)(buf, (unsigned)n, fp) == NULL) break;
    ```
  - **Fixed in:** `kern/gno/ep.c` (init_htable), `kern/gno/main.c` (initrc reads in doShell + tty.config loop in loadttyconfig)
  - **Audit policy:** Any ORCALib function that takes a `size_t`-typed parameter must be verified. Check the ORCALib source (`~/source/iigs-official-repos/byteworksinc-orcalib/`) for actual `csubroutine` byte widths. `memcpy`, `strlen`, `strcpy` appear safe from source inspection. When adding new kernel C code calling a standard C library function, always verify it resolves to ORCALib (not GNO libc) and check parameter widths.
- **InitialLoad2 dispatch fix — APPLIED:**
  Current ORCALib `toolglue.macros` dispatches `_INITIALLOAD2` as `LDX #$2011` (Loader function $20). GS/OS 6.0.4 returns `idNotLoadFile` ($1104) for function $20. The reference GNO 2.0.6 kernel used `_INITIALLOAD` ($0911, function $09) for ALL driver loading. **Fix applied:** Changed both `InitialLoad2(...)` calls to `InitialLoad(...)` (3 params, drop `privateFlag`):
  - `kern/gno/main.c` `loadttyconfig()`: `il_rec = InitialLoad(ILuserID, (Pointer)&fullpath, 1);`
  - `kern/gno/sys.c` line ~763: `InitialLoad(newID, (Pointer)&resBuf->bufString, 1)`
  Verified in running kernel: `#$2011` absent, `#$0911` at `0B/D641`.
- **GNO prefix architecture — CRITICAL for understanding driver loading:**
  - GNO intercepts ALL GS/OS calls via its TSP, including GetPrefixGS (`PGGetPrefix` in gsos.asm). It returns `PROC->prefix[prefixNum+1]` — GNO's own per-process prefix table.
  - The kernel init loop (main.c ~line 366) calls GetPrefixGS to populate `PROC->prefix[]`, but GNO intercepts those calls too → reads from its own uninitialized table → all entries come back length=0. So `PROC->prefix[10]` (prefix 9) is always length=0 in the kernel.
  - **InitialLoad is a Toolbox call** (Loader tool $11). GNO does NOT intercept Toolbox calls — they bypass the TSP and go directly to GS/OS ROM. GS/OS uses its OWN prefix 9, which was set to `:GNO:` when GS/OS launched the kernel (a $B3 S16 file from `:GNO:kern`).
  - Therefore: passing `"9:dev:null"` as a GSString255 to InitialLoad is CORRECT — GS/OS resolves it as `:GNO:dev:null`. GetPrefixGS/gno_ExpandPath cannot be used for this purpose.
  - `fopen("9/initrc")` works despite PROC->prefix[10]=0 because gno_ExpandPath produces `:initrc` (volume-relative), which GS/OS resolves as `:GNO:initrc` (exists on image).
- **Original $1104 root cause — filename.length never set:**
  The original `sscanf(line1, "%s %d %s", filename.text, ...)` filled `filename.text` but **never set `filename.length`** (static variable stays 0). InitialLoad received a GSString255 with length=0 = empty path → $1104 every time. Fix: build path into a new `fullpath` GSString255 and set `fullpath.length = strlen(fullpath.text)`.
- **ONGOING — driver startup BRK $00 at $11/000C:**
  With the length fix, InitialLoad IS invoked and the GS/OS Loader allocates bank $11 for the driver. But BRK $00 fires at $11/000C and $9D/CFBC, halting at the GS/OS monitor. Memory at $11/0000 shows `ee ff 00 00...` — mostly zeros after 2 bytes. Either the driver failed to fully load into $11, or its startup branches to zero-filled memory. WDM $DA/$DB traps added before/after InitialLoad to capture il_rec.startAddr. **This is the current active debugging target.**
- **GNOBug and SIM (System/System.Setup on reference GNO disk):**
  Reference GNO 2.0.6 ships `System/System.Setup/GNOBug#B60100` and `System/System.Setup/SIM#B60100` (both type $B6/$0100 = GS/OS Init/extension). These are NOT required on the boot disk for GNO to work (confirmed: reference GNO boots without them on System604.2mg). SIM = Serial Interrupt Manager (same as libsim). GNOBug = patches GS/OS bugs at boot time.

**Phase 8c image notes:**
- **STRICT SOURCE POLICY**: binary files ($B5, $B3, $B2, $BB) must come from `gno-obj/` — no reference fallback for executables/libraries; `--warn-missing` escape hatch during Phase 9 porting
- Exemptions: `lib/sysfloat` (GoldenGate SDK) and `lib/orcalib` (byteworksinc-orcalib) via `GG_LOOKUP` map
- verbatim/ files staged with LF→CR conversion for ProDOS text compatibility

**cowrez notes:**
- Replaces `catrez` (requires Apple IIgs Resource Manager toolbox, unavailable in GoldenGate)
- Usage: `python3 goldengate/tools/cowrez.py <file.rez> <target_binary> [-v] [--dry-run] [--output rsrc.bin]`
- Supports: rVersion ($8029), rComment ($802A); handles `#include`, `#define`, `$$Date`

**cadius notes (not in homebrew):**
- cadius ADDFOLDER is **recursive** — one call from root adds the entire tree; do NOT loop per-directory
- Resource fork sidecar: `filename#TTAAAA_ResourceFork.bin` alongside `filename#TTAAAA`
- File type in filename: `#TTAAAA` suffix where TT=hex type, AAAA=4-digit hex auxtype

**ProDOS file type reference:**
- `$B5` auxtype `$0001` — GS/OS application (all utilities: bin/, usr/bin/, sbin/, usr/sbin/)
- `$B3` auxtype `$0000` — System file (kern only)
- `$B2` auxtype `$0000` — OMF library (lib/libc, lib/lsaneglue, usr/lib/lib*)
- `$BB` auxtype `$7E01` — Device driver (dev/null, dev/zero, dev/full, dev/console)

---

### Phase 9: Source Completeness (21 missing — all hard items, no source in repo)

**Policy**: All binaries on the disk image must come from `gno-obj/` (built from source). Reference image fallback is disabled for executables and libraries. `--warn-missing` is the escape hatch while porting is in progress.

**Authoritative source repos (in priority order):**
1. This repo (`/Users/smentzer/source/gno`) — primary
2. `/Users/smentzer/source/iigs-official-repos/ksherlock-gno/gno` — secondary (ksherlock fork)
3. `~/source/old-gno` — tertiary (pre-GNO-2.0 CVS history; no initd or mktmp/runover source at any tag)
4. `~/source/GNO-Extras` — quaternary; UNIX v7 ports already adapted for ORCA/C 2.2.0B3 (cal, dd, find, file, od, rev, units + 7 games: arithmetic, fish, fortune, hangman, quiz, wump + nl, sortdir). Files use `#TTAAAA` ProDOS suffix naming; needs GNU make targets replacing dmake. License: Caldera ancient-UNIX + BSD 2-clause.
5. **Ask before using any other source** — GNO is not BSD; BSD ports require significant adaptation

**init vs initd distinction (IMPORTANT):**
- `/bin/init` (14,818B) = user-space run-level manager — sends messages TO initd to change run levels. Source unknown.
- `/sbin/initd` = `/usr/sbin/initd` (17,907B) = PID 1 daemon — reads `/etc/inittab`, spawns processes. Source: `sbin/init/initd.c` (reconstructed). **Built.**
- BSD `sbin/init/init.c` = BSD-derived PID 1 port that was never shipped; incompatible with GNO syscall set.

**Boot sequence:** Kernel reads `9/initrc` → execs `initd` → `initd` reads `/etc/inittab` → starts `gsh`. All components built — boot should work on hardware.

**Recently completed (Phase 9 progress):**
- ✓ `gsh` — 22 ORCA/M .asm files; 74,340B. Three ORCA/M bugs fixed (see Phase 6 notes). Boot unblocked.
- ✓ `grep` / `egrep` / `fgrep` — BSD port
- ✓ `compress` / `uncompress` / `freeze` — BSD port
- ✓ `chmod`, `cp`, `echo`, `hostname` — written/ported
- ✓ `mktmp`, `runover` — written from scratch
- ✓ `unshar`, `setvers` — ported
- ✓ `vi` (Stevie), `less` — ported from old-gno
- ✓ `libsim` — from old-gno/sys/sim/simlib.asm

**STILL MISSING (21) — all require source from outside this repo:**
- 4 drivers (no source): `dev/modem`, `dev/printer`, `system/drivers/fileport`, `system/drivers/nullport`
- Network (no source): `ftp`, `rcp`, `rlogin`, `rsh`
- No source found: `init` (user-space run-level manager), `su`, `diff`, `dmake`, `yankit`, `copycat`, `coff`, `occ`, `lpd`
- No source found: `uptime`, `uptimed`
- Complex (needs pty/fork/select): `script`
- Low priority: `newuserv` (108KB GUI program)

**External/ORCA toolchain wrappers:**
- [ ] `asml`, `assemble`, `cmpl` — all 3 identical (51,485B each); ORCA/M GNO wrappers
- [ ] `coff`, `occ` — ORCA tools
- [ ] `dmake` — GNO's make; source was never open-sourced

**OMF structural differences (found via cowdiff --different, needs investigation):**
- [ ] **`~_STACK` segment missing from all our EXE builds** — reference binaries contain an `$12` (ABS bank) segment `~_STACK` (~1KB) present in every linked EXE. Likely from a different ORCALib startup or linker version. Investigate: compare `~/Library/GoldenGate/lib/ORCALib` vs `/lib/ORCALib` on reference disk.
- [ ] **`~ExpressLoad` DATA segment smaller** (474B vs 632–711B in reference) — may be benign.
- [ ] **`libc_gen__` / `libc_str__` missing from many bins** — small libc segments (163–390B) absent from our builds; linker dead-code elimination or different libc archive layout.
- [ ] **`/bin/center` over-linked** (+34KB, 4 EXTRA libc segments) — reference used a stripped standalone libc.

**Rebuild after Phase 9 fixes:**
```bash
make -f goldengate/build/phase6.mk
make -f goldengate/build/phase8_rez.mk
python3 goldengate/build/phase8c_image.py --warn-missing
```
Remove `--warn-missing` from `rebuild-all.sh` once all 21 missing binaries are sourced.

### Known Skips
- `libedit` — not building in original
- `fudgeinstall` / `mkboot` / `mkdisk1` / `mkdisk2` — replaced by macOS packaging
- `newuserv` — GUI new-user program; very large (108KB); low priority
- `lpd` — BSD line printer daemon; network/IPC dependent; low priority
- `yankit`, `copycat` — no source found; low priority

---

## Build Quick Reference

```bash
# Build ORCA/C from source (in byteworksinc-orca-c repo)
cd /Users/smentzer/source/iigs-official-repos/byteworksinc-orca-c
make -f GNUmakefile install  # compile + install to ~/Library/GoldenGate/Languages/cc

# Build + install GNO ORCALib (in byteworksinc-orcalib repo)
# make -f goldengate/Makefile TARGET=gno install

# Install GNO headers to GoldenGate (in this repo)
make -f goldengate/install-gno-headers.mk

# Build libc (all subdirs + combine)
make -f goldengate/build/libc.mk

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

# Build Phase 5 — all support libraries
make -f goldengate/build/phase5.mk

# Validate Phase 5 sizes vs reference
make -f goldengate/build/phase5.mk validate

# Build Phase 6 — all utilities
make -f goldengate/build/phase6.mk

# Build one Phase 6 utility
make -f goldengate/build/phase6.mk cat
make -f goldengate/build/phase6.mk bin_du

# Validate Phase 6 sizes vs reference
make -f goldengate/build/phase6.mk validate

# Build Phase 7 — kernel + drivers
make -f goldengate/build/phase7.mk

# Full clean rebuild of everything (headers → libc → libs → utils → kern → rez → image)
bash goldengate/build/rebuild-all.sh

# Incremental rebuild (skip clean)
bash goldengate/build/rebuild-all.sh --no-clean

# Rebuild specific phases only
bash goldengate/build/rebuild-all.sh --no-clean phase7 phase8a phase8c

# Phase 8a — attach all resource forks
make -f goldengate/build/phase8_rez.mk

# Phase 8c — build ProDOS disk image
python3 goldengate/build/phase8c_image.py             # → diskImages/gno-built.2mg
python3 goldengate/build/phase8c_image.py --dry-run   # preview without writing
python3 goldengate/build/phase8c_image.py -v          # verbose: show each file staged

# cowdiff — canonical disk image comparison
REF=/Volumes/Storage/IIgs/DocTemple/gno/2.0.6/dist/gno_206/gno.po

python3 goldengate/tools/cowdiff.py $REF diskImages/gno-built.2mg --types B5,B3,B2,BB -q
python3 goldengate/tools/cowdiff.py $REF diskImages/gno-built.2mg --missing
python3 goldengate/tools/cowdiff.py $REF diskImages/gno-built.2mg --different
python3 goldengate/tools/cowdiff.py $REF diskImages/gno-built.2mg --json | jq '.summary'
python3 goldengate/tools/cowdiff.py extract $REF
python3 goldengate/tools/cowdiff.py extract $REF --out /my/extraction/dir/
python3 goldengate/tools/cowdiff.py cache --list
python3 goldengate/tools/cowdiff.py cache --clear
```

---

## Reference Materials

See `goldengate/index.html` for a full browsable index.

### DocTemple — `/Volumes/Storage/IIgs/DocTemple/`

Canonical reference store for all Apple IIgs development materials.

#### Documentation — `docs/`

| Subfolder | Contents |
|-----------|---------|
| `hardware/` | IIgs schematics, hardware refs (3 versions), firmware refs (2), debugger ref, 65816 CPU manual, LocalTalk, ZipGS registers |
| `orca/` | ORCA/C 2.0, ORCA/M 2.0, Prog Ref 6.0/6.0.1, shell reference, floating point libs |
| `gsos/` | GS/OS Reference Volume 1, ProDOS 16 Reference Manual |
| `apw/` | Apple Programmer's Workshop reference, APW C language/assembler references |
| `c-programming/` | LTP C, Toolbox C, IIgs C+asm programming, Morgan Davis Toolbox book |
| `networking/` | Marinetti TCP/IP stack, Uthernet II manual, W5100/W5500 datasheets |

#### Source Code — `source/` (by product)

ORCA/C (2.1.0–2.2.0-b3), ORCA/M (2.1.0, 4.1), ORCA linker/shell/editor/macgen/makelib/debugger/pascal, ORCALib (beta), SysFloat (beta), AppleSoft BASIC.

#### Binary Distributions

Key distributions (see DocTemple directly for full listing):
- `gno/2.0.6/dist/gno.po` — canonical GNO 2.0.6 reference image (803 files)
- `orca-suite/opus-ii/dist/` — complete ORCA binary suite (2,070 files)
- `goldengate/2.0.0/dist/` — full GoldenGate install tree (1,938 files)

### Local Canonical Repo Clones — `/Users/smentzer/source/iigs-official-repos/`

| Directory | Contents |
|-----------|---------|
| `byteworksinc-orca-c` | **Official** ByteWorks ORCA/C 2.2.2 compiler source. Built via `GNUmakefile`. |
| `byteworksinc-orcalib` | **Official** ByteWorks ORCALib. `unified` branch. GNO build uses `TARGET=gno`. |
| `gno-original` | Original Devin Reade GNO/ME v2.0.6 source |
| `goldengate` | GoldenGate iix emulator source (C++) |
| `ksherlock-orca-c` | ksherlock fork of ORCA/C |
| `nulib2` | ShrinkIt archive tool source |

### Additional Source Repos — `/Users/smentzer/source/`

| Directory | Contents |
|-----------|---------|
| `old-gno` | Pre-GNO-2.0 sources with full CVS history back to 1996. Tags: `v1_0`, `v1_1`, `gsh_v1_1`, `beta_970304`, `beta_971222`. **3rd priority** source for missing GNO files. No initd or mktmp/runover source at any tag. |

---

## Key File Locations

| File | Purpose |
|------|---------|
| `NOTES/devel/doing.builds` | **Authoritative build sequence** |
| `goldengate/build/*.mk` | GNU Makefiles for each build target |
| `goldengate/tools/compare_libc.py` | Symbol comparison between built and reference libc |
| `goldengate/tools/cowrez.py` | Cross-platform Rez compiler: parses .rez → resource fork xattr |
| `goldengate/tools/cowdiff.py` | Canonical disk image comparison + extraction tool |
| `goldengate/orcac-tests/tools/omf_dis.py` | OMF v2 parser + 65816 disassembler |
| `sbin/init/initd.c` | PID 1 daemon — reconstructed from 65816 disassembly of reference binary |
| `diskImages/gno-built.2mg` | Built GNO/ME ProDOS disk image (32MB, 688 files) |
| `goldengate/build/phase8_rez.mk` | Attach resource forks to all built binaries (via cowrez.py) |
| `goldengate/build/phase8c_image.py` | Build ProDOS .2mg disk image from gno-obj/ + reference |
| `.mcp.json` | Claude Code MCP server definitions for this project (`gsplus` debugger integration) |

### gsplus MCP Server — Emulator Integration

Defined in `.mcp.json`. Provides live access to the running GSplus Apple IIgs emulator session.

**Config file:** `~/config.kegs` — disk image assignments; `s7d6` and `s7d8` are commented out (inactive).

**Image update workflow:** After rebuilding `diskImages/gno-built.2mg`, the symlink `~/source/gsplus/content/gno-built.2mg → ~/source/gno/diskImages/gno-built.2mg` means no file copy is needed. For utility/config changes a warm reset (`restart_emulator`) suffices. For a new **kernel** build, a `cold_reset` is required — the old kernel stays resident in RAM through warm resets via `SetTSPtr(0x8000,3,kernTable)`, causing `kernStatus()` to report "already active" and the new kernel to exit immediately.

**CANONICAL RULES — emulator image deployment (MUST follow every time):**
1. After building a new GNO disk image (`phase8c_image.py`), you MUST issue `relaunch_app` via the MCP — GSplus caches the disk image in memory and will not pick up changes with a reset alone.
2. After `relaunch_app` completes, wait 5 seconds, then issue `restart_emulator` via the MCP to trigger a clean warm reset into GS/OS.
3. After any reset/relaunch, verify the correct kernel is running by searching emulator memory in bank $0B for the `BUILD_TIMESTAMP` string (from `kern/gno/build_time.h`) and confirming it matches the current build.

**Reset types:**
- `restart_emulator` / debugger `r` — warm reset: hardware registers + reset vector only, RAM intact
- `cold_reset` / debugger `C` — cold reset: `load_roms_init_memory()` (calloc zeroes all RAM) + `do_reset()`. **Requires GSplus rebuild** after the `debugger.c` change.
- debugger `R` — NOT a reset; shows dtime array and events

**COP instruction ($02):** Fully supported in native mode (vectors through `$FFE4`). In emulation mode it also works but triggers `halt_printf` (debugger halt + log message).

#### Mounted volumes (slot → ProDOS name)

| Slot | Image | Vol Name | Notes |
|------|-------|----------|-------|
| `sp0` | `System604.2mg` | SYSTEM | GS/OS 6.0.4 boot disk |
| `sp1` | `Storage.hdv` | STORAGE | |
| `sp2` | `SourceCode.hdv` | SOURCECODE | |
| `sp3` | `Programming.hdv` | PROGRAMMING | |
| `sp4` | `Utils.hdv` | UTILS | |
| `sp5` | `GNO.hdv` | — | read-only, unknown image type |
| `sp6` | `gno-built.2mg` | GNO | our built GNO/ME image (symlink to diskImages/) |
| `sp7` | `gno.po` | — | reference GNO 2.0.6, read-only (commented out) |

#### Tool reference

| Tool | Key params | Notes |
|------|-----------|-------|
| `list_volumes` | — | Returns slot, vol_name, total_blocks, image_type, write_prot, dirty |
| `list_files` | `slot`, `path` (default `/`), `recursive` (default false) | Set `recursive=true` to expand subdirectories |
| `read_file` | `slot`, `path` | Returns file contents |
| `read_volume` | `slot` | Full ProDOS filesystem as structured JSON + base64 file data; files >1MB listed but data omitted |
| `read_memory` | `addr`, `len` (default 256) | Read from 24-bit address space; addr as int `0xBBOOOO` only (not string format) |
| `write_memory` | `addr`, `data` (hex string e.g. `"EA EA"`) | Write bytes to 24-bit address; cleaner than raw `BB/OOOO:HH` debugger strings |
| `search_memory` | `pattern`, `addr`, `len` | Search emulator memory |
| `get_registers` | — | Current 65816 register state |
| `halt_emulator` | — | Pause execution |
| `continue_emulator` | — | Resume execution |
| `step_emulator` | — | Single-step |
| `debugger_command` | `command` | Raw debugger command string |
| `get_break_info` | — | Current breakpoint/halt state |
| `get_log` | `lines` (default 50) | Last N lines of emulator diagnostic output (128KB ring buffer) |
| `restart_emulator` | — | Warm reset (ROM reset vector only, RAM preserved) |
| `cold_reset` | — | Full cold reset: zeroes all RAM then resets. Required for new kernel builds. |
| `run_until` | `addr`, `timeout_s` (default 60), `poll_interval_s` (default 3.0) | Set temp breakpoint, resume, block until hit. Use poll_interval_s ≥3.0 to avoid stalling disk I/O during boot. |
| `get_screen_text` | `page` (default 1), `col80` (default true) | Read text screen from shadow RAM ($E0/$E1 banks). Returns 24 decoded ASCII lines. Safe to call while running. |

**Boot debugging workflow:**
1. `cold_reset` — clears old kernel, starts fresh boot
2. `run_until(addr_of_gno_entry)` — wait for kernel to load (poll_interval_s=3.0)
3. `get_screen_text()` — see what GNO printed without polling registers

### goldengate/build/ Makefiles

| Makefile | Source | Output |
|----------|--------|--------|
| `install-gno-headers.mk` | `include/` + `orcacdefs/` + `Libraries/ORCACDefs/` | `~/Library/GoldenGate/lib/ORCACDefs/` |
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
| `phase5.mk` | Top-level: invokes all Phase 5 libs | all Phase 5 outputs |
| `lsaneglue.mk` | `lib/lsaneglue/` (2 asm) | `gno-obj/lib/lsaneglue` |
| `libcrypt.mk` | `lib/libcrypt/` (1 asm + 1 C) | `gno-obj/usr/lib/libcrypt` |
| `libsim.mk` | `lib/libsim/` (1 asm) | `gno-obj/usr/lib/libsim` |
| `libutil.mk` | `lib/libutil/` (3 C) | `gno-obj/usr/lib/libutil` |
| `libtermcap.mk` | `lib/libtermcap/` (5 C) | `gno-obj/usr/lib/libtermcap` |
| `libcurses.mk` | `lib/libcurses/` (42 C) | `gno-obj/usr/lib/libcurses` |
| `liby.mk` | `lib/liby/` (2 C) | `gno-obj/usr/lib/liby` |
| `netdb.mk` | `lib/netdb/` (26 C) | `gno-obj/usr/lib/libnetdb` |
| `libcontrib.mk` | `lib/libcontrib/` (4 C) | `gno-obj/usr/lib/libcontrib` |
| `phase6.mk` | 100+ utilities across bin/, usr.bin/, sbin/, usr.sbin/, usr.games/ | `gno-obj/bin/`, `gno-obj/usr/bin/`, `gno-obj/usr/sbin/`, `gno-obj/usr/games/` |
| `phase7.mk` | kern/gno/ (14 C + 16 ASM) + kern/drivers/ (4 ASM linked + 4 standalone) | `gno-obj/kern`, `gno-obj/dev/{null,zero,full,console}` |
