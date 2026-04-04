# GNO/ME — Build Project Guide

## What This Is

GNO/ME (GNO Multitasking Environment) is a complete Unix-like operating system for the Apple IIgs (65816 processor). This repository is **smentzer's own fork** of the ksherlock/gno repository, created from ksherlock's master at commit `30344bf`. The ksherlock fork is no longer maintained. The first commit (`f76e43f`) adds all the GoldenGate cross-build infrastructure. It contains:

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

#### iix compile (ORCA/C 2.2.2)

The installed compiler is now **ORCA/C 2.2.2**, built from source at `/Users/smentzer/source/iigs-official-repos/byteworksinc-orca-c/` and installed to `~/Library/GoldenGate/Languages/cc`. A 2.2.1 backup is at `cc.bak`.

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
- None currently. All previously known bugs are fixed in 2.2.2:
  - `vfprintf.c` SPLIT_FILE_2 "too many local labels" (error 58, `maxLabel=3275` limit) — **fixed in 2.2.2**. `vfprintf2.c` now compiles directly without any clang preprocessing workaround.
  - The four back-end bugs fixed during 2.2.1 build (GenCall table, cgQuad, cnv variant record, cgString isByteSeq) remain fixed.

#### iix assemble (ORCA/M Asm65816 2.1.0)

```bash
iix assemble +T foo.asm      # +T = terminal on first error
```

**Output:** `foo.A` + `foo.ROOT` in **CWD** (uppercase `.A` extension!)
**File type:** Sets `$B0` outside `/tmp` — **must patch to `$B1`:**
```bash
xattr -wx com.apple.FinderInfo "70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" file.a
```
Why: GoldenGate only sets `$B1` for files in `/tmp` (prefix 3:). All other directories get `$B0`, which makelib silently rejects ("not an object module").

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

### Disk Image / Archive Tools

**Tool selection by format:**

| Format | Tool | Command | Notes |
|--------|------|---------|-------|
| `.2mg`, `.po`, `.hdv` (ProDOS) | **cadius** | `cadius EXTRACTVOLUME image.2mg /output/` | **Preferred** for ProDOS. Handles extended/forked files (type $05). Install: `brew install cadius` |
| `.iso` (hybrid Apple/ISO 9660) | **7z** | `7z x image.iso -o/output/` | Only tool that works on macOS 26.x for hybrid Apple/ISO 9660 images |
| `.shk` (ShrinkIt) | **nulib2** | `nulib2 -xe archive.shk` | Extracts in CWD; `cd` to destination first |
| `.zip` | **unzip** | `unzip archive.zip -d /output/` | Standard |

| Tool | Location | Notes |
|------|----------|-------|
| cadius | `brew install cadius` | **Not yet installed** — install when needed |
| 7z (p7zip) | `/opt/homebrew/bin/7z` | brew-installed |
| nulib2 | `/Users/smentzer/source/nulib2/nulib2/nulib2` | Built from source |
| AppleCommander | `~/Library/Mobile Documents/com~apple~CloudDocs/NotesAndStuff/IIgs/Apple Commander/AppleCommander-macosx-1.4.0.jar` | Java required; **listing only** — use `-ls` or `-l` to view directories |
| Java (for AppleCommander) | `/opt/homebrew/opt/openjdk/bin/java` | brew-installed; not in default PATH |

**IMPORTANT — AppleCommander limitations:**
- AppleCommander 1.4.0 can **list** ProDOS images but **fails to extract** binary files with extended/forked storage (type $05) — throws "Unknown ProDOS storage type!" and only extracts text files.
- Cannot read ISO 9660 images at all (throws DiskUnrecognizedException).
- Use only for quick directory listings. Use **cadius** for actual extraction.

**IMPORTANT — ISO 9660 hybrid images:**
- The Opus ][ CD ISOs are hybrid Apple partition map images with both ISO 9660 and classic HFS partitions.
- `hdiutil attach` fails with "no mountable file systems" — macOS 26.x dropped classic HFS (non-Plus) mount support.
- `bsdtar` fails with "Invalid location of extent of file".
- **Use `7z x`** — but note each file appears twice (data fork + resource fork). Resource fork overwrites data fork on extraction. Fine for source/text; may be lossy for binaries. Prefer existing extractions when available.

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
| `extracted/usr/lib/libnetdb` | 80,506 | Phase 5 |
| `extracted/usr/lib/libcrypt` | 7,180 | Phase 5 |
| `extracted/usr/lib/libutil` | 2,146 | Phase 5 |
| `extracted/usr/lib/liby` | 660 | Phase 5 |
| `extracted/usr/lib/libcontrib` | 19,889 | Phase 5 |

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
- **catrez** — resource fork tool; source in `usr.orca.bin/catrez/`; must be bootstrapped
- **gsh** — GNO shell; fails with version error in GoldenGate
- **GNO namespace** — `/src`, `/obj`, `/lang/orca` paths don't resolve in iix (see above)

---

## Current Status

### Completed

#### ORCA/C 2.2.2 ✓
- Source: `/Users/smentzer/source/iigs-official-repos/byteworksinc-orca-c/`
- Build: `GNUmakefile` using iix toolchain (Pascal + ORCA/M assembly modules)
- Installed to: `~/Library/GoldenGate/Languages/cc` (2.2.1 backup at `cc.bak`)
- **Test suite: 42/42 compile tests + 6/6 runtime tests + 12/12 ORCA/M tests — all pass**
- Bugs fixed across 2.2.1 and 2.2.2 builds:
  - Missing `GenCall` entries 78–98 (`~MUL8`, `~SHL8`, `~CDIV8`, etc. for `long long` ops)
  - Missing `cgQuad`/`cgUQuad` constant handler (global `long long` initializers crashed)
  - `cnv` variant record incomplete — added `qval`, `eval`, and `ival5` fields
  - `cgString` missing `isByteSeq` branch — `char[] = "..."` emitted garbage bytes
  - DAG2.pas: ~25 opcodes missing from case statement (`pc_rev`, `pc_fix`, quad ops, etc.)
  - `maxLabel` limit (3275) causing "too many local labels" error 58 on `vfprintf.c` SPLIT_FILE_2

#### Phase 2 — ORCALib ✓
- Source: `/Users/smentzer/source/iigs-official-repos/byteworksinc-orcalib/` (`unified` branch)
- Build: `make -f goldengate/Makefile TARGET=gno install` (in orcalib repo)
- Installed to: `~/Library/GoldenGate/lib/ORCALib` (39,468 bytes, 166 segments)
- Also installs `assert.A` → `~/Library/GoldenGate/lib/assert.A` (used by libc build)
- GNO override: `gno/locale.asm` — C-standard `struct lconv` field order matching GNO `locale.h`
- `lib/ORCALib/` removed from this repo — canonical source is `byteworksinc-orcalib` unified branch

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
- `lib/libc/stdio/vfprintf1.c` + `vfprintf2.c`: wrapper files for SPLIT_FILE defines (compile cleanly with ORCA/C 2.2.2 — clang workaround no longer needed)

#### Test Suites ✓
- **ORCA/C C99/C11** (against 2.2.2): 27 positive + 4 negative + 11 library compile tests = **42/42 pass**
- **ORCA/C stdlib runtime**: 6 run tests — **6/6 pass**
- **Stack/ABI**: 6 tests — all pass
- **ORCA/M macros**: 11 positive + 1 negative — all 12 pass
- Run: `make -f goldengate/orcac-tests/Makefile all-stdlib` and `make -f goldengate/orca-m-tests/Makefile`

#### ORCA/M Build from Source ✓
- `goldengate/orca-m/Makefile` — builds Asm65816 2.1.0 (54,297 bytes)

#### Phase 5 — Support Libraries ✓
- **8 libraries built:** lsaneglue, libcrypt, libutil, libtermcap, libcurses, liby, libnetdb, libcontrib
- Makefiles: `goldengate/build/phase5.mk` (top-level) + individual `goldengate/build/<lib>.mk`
- Output: `gno-obj/lib/lsaneglue`, `gno-obj/usr/lib/lib{crypt,util,termcap,curses,y,netdb,contrib}`

**Source fixes applied during Phase 5 build:**
- `lib/lsaneglue/saneglue.asm`: changed `copy :lang:orca:...:e16.sane` → `copy E16.SANE` (symlinked)
- `lib/libcurses/*.c` (all 40 files): prepended `#define _CURSES_PRIVATE` — ORCA/C CLI doesn't support `-D`
- `lib/netdb/rcmd.c` + `res_send.c`: clang -E preprocessing workaround applied during Phase 5 build (the vfprintf label-count bug is fixed in 2.2.2, but these files may still benefit from preprocessing due to `struct iovec` forward-ref issue — verify when rebuilding Phase 5)
- `lib/netdb/res_send.c`: uses `struct iovec` from `sys/uio.h` after forward ref in `sys/socket.h` — preprocessing resolves
- `lib/libcontrib/Makefile` SRCS: errnoGS.c excluded (not in reference build; only copyfile, expandpath, strarray, xalloc)

**Build notes:**
- lsaneglue: requires `.mac` files generated by `iix macgen` before assembly; generated files committed in `lib/lsaneglue/`
- libutil: only login.c, logintty.c, logwtmp.c compiled (not hexdump, pty, setproc, logout — not in reference)
- libcurses: scanw.c excluded (noted as having trouble in original Makefile — `_SRCS`)
- netdb: iso_addr.c, linkaddr.c, ns_addr.c, ns_ntoa.c, send.c, recv.c excluded (not in original Makefile SRCS)

#### Phase 6 — Utilities ✓
- Makefile: `goldengate/build/phase6.mk`
- **79/79 utilities built** across `bin/`, `usr.bin/`, `usr.orca.bin/`, `sbin/`, `usr.sbin/`
- Output: `gno-obj/bin/`, `gno-obj/usr/bin/`, etc.
- `more` and `tput` now link — fixed by adding `lib/libtermcap/getcap.c` (full BSD getcap)

**Source fixes applied during Phase 6 build:**
- `bin/du/du.c`: removed `#pragma lint -1` (was enabling all lint); changed `sccsid` to `const`
- `bin/passwd/passwd.c`: `pw_comment` → `pw_gecos` (old GNO 2.0.4 field name)
- `bin/touch/touch.c`: wrapped local `GSString` struct in `#ifndef __appleiigs__`; `->string` → `->text`
- `bin/df/df.c`: wrapped `struct ufs_args mdev;` in `#ifndef __GNO__` (type undefined in GNO)
- `bin/cmp/regular.c`: added `#define getpagesize() 512` for GNO (unused in GNO mmap-free code path)
- `bin/ls/ls.c`: removed conflicting `extern GSString255Ptr __C2GSMALLOC(char *)`; added cast
- `include/types.h`: added `typedef struct GSString GSString;` value-type alias after GSStringPtr typedef
- `include/getopt.h`: created (shim that includes `<stdlib.h>` where `getopt` is declared in GNO)
- `include/gno/contrib.h`: created by copying from `lib/libcontrib/contrib.h`
- `usr.bin/launch/launch.c`: changed `gs` from `GSString255Ptr` to `GSStringPtr` (matches `SetGNOQuitRec` arg type)
- `usr.bin/env/env.c`: removed `#pragma lint -1`; removed unused `ResultBuf255 tmp`
- `usr.bin/printenv/printenv.c`: removed `#pragma lint -1`; wrapped unused vars in `#ifndef __ORCAC__`
- `usr.bin/catrez/catrez.c`: removed `#pragma lint -1`
- `usr.bin/fmt/head.c`: added `#define BUILD_FMT` before `#include "def.h"` (prevents pathnames.h include)
- `usr.bin/sort/dsort.c` + `msort.c`: changed `#include "/usr/include/getopt.h"` → `#include <getopt.h>`
- `usr.bin/sort/tempnam.c`: wrapped `#define __GNO__ 1` in `#ifndef __GNO__` guard (was redefinition)
- `usr.bin/cal/cal.c`: removed `extern int _INITGNOSTDIO(void)` and call (not in modern libc; handled by runtime)
- `usr.orca.bin/udl/common.h`: added `#include <errno.h>` (needed for strerror)

**Phase 6 build patterns:**
- Simple utilities: `cd srcdir && iix --gno compile -P prog.c && mv prog.a objdir/ && { mv prog.root objdir/ 2>/dev/null || true; }`, then `iix --gno link -P -o outdir/prog prog`
- Multi-file utilities: compile each .c, then link all together
- Utilities with multiple mains (sort, describe): each program linked separately
- Library links: `passwd`→libcrypt; `rmdir`,`removerez`,`whereis`,`newuser`,`install`→libcontrib; `newuser`→libcrypt+libcontrib; `tput`,`more`→libtermcap; `whois`→libnetdb; `printf`→SysFloat (`~/Library/GoldenGate/Libraries/SysFloat`); `getty`→libutil
- **`~DOUBLEPRECISION`** runtime label: in `~/Library/GoldenGate/Libraries/SysFloat` (ORCA SDK, not GNO lib/)
- **`#pragma lint -1`**: ENABLES all lint (= 0xFFFF); lint is OFF by default — remove these pragmas
- **`const` on sccsid**: ORCA/C lint doesn't flag `static char const sccsid[]` as unused; plain `static char sccsid[]` IS flagged

**Skipped utilities:**
- Kernel deps: `ps`, `init`, `reboot`, `shutdown`, `nogetty`
- Network deps: `rcp`, `ftp`, `rlogin`, `rsh`, `inetd`, `syslogd`
- Asm-only: `gsh`, `date`, `purge`, `getvers`, `help`, `setvers`
- C+asm mixed (deferred): `binprint`, `mkdir`
- Complex (deferred): `vi`, `less`, `awk`, `man`, `nroff`, `cpp`

#### Phase 7 — Kernel ✓
- Makefile: `goldengate/build/phase7.mk` — `make -k -f goldengate/build/phase7.mk`
- **kern**: 150,673 bytes (reference 140,754 — ~7% larger due to ksherlock fork additions)
- **Drivers**: `dev/null` (592 bytes), `dev/zero` (619), `dev/full` (620), `dev/console` (5,927)
- 14 C modules + 16 kern/gno ASM + 4 driver ASM (linked into kern) + 4 standalone driver ASM

**Source fixes applied during Phase 7 build:**
- `kern/gno/*.c` (all 14): added `#define KERNEL` before first `#include`
- `kern/gno/*.c`: replaced GNO namespace includes (`/lang/orca/...`) with standard `<stdio.h>` etc.
- `kern/gno/fastfile.c`: removed `#pragma lint -1` (enables ALL lint — 7 unused-var errors)
- `kern/gno/sys.c` fix 1: `if (h = (FindHandle(mem) == NULL))` → `if ((h = FindHandle(mem)) == NULL)`
- `kern/gno/sys.c` fix 2: reordered includes — `kvm.h` before `gno.h` so `struct kvmt` is complete; `kvmt *` → `struct kvmt *` throughout
- `kern/gno/queue.c`: `return (mptr - kp)` → `return (int)(mptr - kp->procTable)`
- `kern/gno/signal.c`: `(sig->v_signal[signum] >> 16)` → `(word)((unsigned long)sig->v_signal[signum] >> 16)`
- `kern/gno/ep.c`: strincmp signature → `short strincmp(const char *, const char *, unsigned)`
- `kern/gno/inc/tty.inc`, `gsos.inc`, `kern.inc`: converted LF→CR (COPY directive requires CR)
- `kern/drivers/*.equates`: converted LF→CR
- `include/stdio.h`: added `#ifdef KERNEL` guard — kernel uses `extern FILE *stdout` (ORCALib) instead of `&__sF[1]` (GNO libc array); run `make -f goldengate/install-gno-headers.mk` after this change

#### maccatrez — macOS Resource Fork Tool ✓
- **`goldengate/tools/maccatrez.py`** — replaces `catrez` (which requires Apple IIgs Resource Manager toolbox, unavailable in GoldenGate)
- Parses GNO `.rez` source files; writes Apple IIgs resource fork binary as `com.apple.ResourceFork` xattr
- Supports: rVersion ($8029), rComment ($802A)
- Handles: `#include`, `#define` macros (recursive), `BUILD_DATE`/`$$Date`, adjacent string concat, `\n`→CR
- Verified byte-for-byte vs GNO 2.0.6 `catrez.rsrc` reference; all 80+ GNO `.rez` files parse cleanly
- Usage: `python3 goldengate/tools/maccatrez.py <file.rez> <target_binary> [-v] [--dry-run] [--output rsrc.bin]`

**Apple IIgs resource fork binary format** (documented from reference analysis):
- Header (140 bytes at offset 0): rFileVersion=0, rFileToMap=0x8C, rFileMapSize=mapSize
- Map at 0x8C: 32-byte fixed header + 10×8-byte free list + 4-byte padding + N×20-byte index + 2-byte trail
- `mapToIndex` = 0x74 (offset from map start to ref index)
- ResRefRec (20 bytes each): type(2)+id(4)+absOffset(4)+attr(2)+size(4)+handle(4, zero on disk)
- rVersion: ReverseBytes{nonfinal, stage, minor|bug, major} + country(2 LE) + pstring + pstring
- rComment: raw string, NO null terminator (`string;` type is not C-terminated)
- Free list sentinel: blkOffset=fileSize, blkSize=-(fileSize+1)

### Next Steps (in order)
- [ ] **Phase 8a — Resource forks**: `phase8_rez.mk` — run maccatrez for all ~80 binaries that have a `.rez` file
- [ ] **Phase 8b — ProDOS file types**: set `com.apple.FinderInfo` xattr on each binary ($B3 for executables, $BB auxtype 0x7E01 for drivers)
- [ ] **Phase 8c — Disk image**: install cadius (`brew install cadius`), assemble full GNO directory tree into a ProDOS `.2mg` volume matching the 2.0.6 reference layout (`diskImages/extracted/`)

### Known Skips
- `libedit` / `libsim` — not building in original
- `fudgeinstall` / `mkboot` / `mkdisk1` / `mkdisk2` — replaced by macOS packaging

---

## Build Quick Reference

```bash
# Build ORCA/C from source (in byteworksinc-orca-c repo)
cd /Users/smentzer/source/iigs-official-repos/byteworksinc-orca-c
make -f GNUmakefile          # compile only
make -f GNUmakefile install  # compile + install to ~/Library/GoldenGate/Languages/cc

# Build + install GNO ORCALib (in byteworksinc-orcalib repo)
cd /Users/smentzer/source/iigs-official-repos/byteworksinc-orcalib
make -f goldengate/Makefile TARGET=gno
make -f goldengate/Makefile TARGET=gno install  # installs liborca + assert.A

# Install GNO headers to GoldenGate (in this repo)
make -f goldengate/install-gno-headers.mk

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

# Build Phase 5 — all support libraries
make -f goldengate/build/phase5.mk

# Build individual Phase 5 library
make -f goldengate/build/libtermcap.mk
make -f goldengate/build/libcurses.mk
make -f goldengate/build/netdb.mk

# Validate Phase 5 sizes vs reference
make -f goldengate/build/phase5.mk validate

# Build Phase 6 — all utilities
make -k -f goldengate/build/phase6.mk

# Build one Phase 6 utility
make -f goldengate/build/phase6.mk cat
make -f goldengate/build/phase6.mk bin_du

# Validate Phase 6 sizes vs reference
make -f goldengate/build/phase6.mk validate

# Build Phase 7 — kernel + drivers
make -k -f goldengate/build/phase7.mk

# Attach resource fork to a built binary (maccatrez)
python3 goldengate/tools/maccatrez.py kern/gno/kern.rez gno-obj/kern -v
python3 goldengate/tools/maccatrez.py bin/cat/cat.rez gno-obj/bin/cat -v

# Dry-run / inspect without writing
python3 goldengate/tools/maccatrez.py kern/gno/kern.rez --dry-run --verify -v
```

---

## Reference Materials

See `goldengate/index.html` for a full browsable index.

### DocTemple — `/Volumes/Storage/IIgs/DocTemple/`

Canonical reference store for all Apple IIgs development materials. Organized by product and version, with `source/` and `dist/` subdirectories.

#### Documentation — `docs/`

| Subfolder | Contents |
|-----------|---------|
| `hardware/` | IIgs schematics, hardware refs (3 versions), firmware refs (2), debugger ref, 65816 CPU manual, LocalTalk, ZipGS registers, PEEKS/POKES ref |
| `orca/` | ORCA/C 2.0, ORCA/M 2.0, disassembler, debugger, sublib source, Merlin→ORCA/M, Prog Ref 6.0/6.0.1, MPW IIgs, floating point libs, shell reference, Utility Pack, Talking Tools |
| `gsos/` | GS/OS Reference Volume 1, ProDOS 16 Reference Manual |
| `apw/` | Apple Programmer's Workshop reference, APW C language/assembler references, APW C release notes |
| `c-programming/` | LTP C, Toolbox C, Small C, IIgs asm programming, IIgs C+asm programming, Morgan Davis Toolbox book |
| `networking/` | Marinetti TCP/IP stack, Uthernet II manual, W5100/W5500 datasheets |
| `opus-ii/` | Opus ][ about + overview |
| `misc/` | SuperScribe II reference |

#### Source Code — by product & version

| Product | Versions | Source |
|---------|----------|--------|
| `orca-c/` | 2.1.0, 2.1.1-b3, 2.2.0-b2, 2.2.0-b3 | ORCA/C compiler (Pascal + asm) |
| `orca-m/` | 2.1.0, 4.1 | ORCA/M assembler; 4.1 has full multi-build (editor, monitor, host, 6502 asm, linker, utilities, libraries) |
| `orca-linker/` | 2.0.3 | Linker source |
| `orca-shell/` | 2.0.4, 2.0.5-b2 | Shell source |
| `orca-editor/` | 2.1.0, 2.2.0-b1 | Editor source |
| `orca-macgen/` | 2.0.3 | Macro generator source |
| `orca-makelib/` | 2.0 | Library builder source |
| `orca-makebin/` | 2.0 | Binary builder source |
| `orca-dumpobj/` | 2.0.1, 2.0.2.1 | Object dumper source |
| `orca-debugger/` | 1.1 | Source + dist (.2mg) |
| `orca-crunch/` | 2.0 | Source compressor |
| `orca-entab/` | 2.0 | Tab utility |
| `orca-prizm/` | 2.1.0, 2.1.1-b1 | Resource editor source |
| `orca-pascal/` | 2.2.0, 2.2.1-b1 | Pascal compiler source |
| `orcalib/` | beta | Runtime library source |
| `sysfloat/` | beta | Floating point library source |
| `sysfpe-float/` | beta | FPE float library source |
| `applesoft/` | — | AppleSoft BASIC source (.shk) |

#### Binary Distributions

| Product | Location | Contents |
|---------|----------|---------|
| `orca-c/2.2.0-b3/dist/` | 4 archives + extracted | ORCA/C compiler + linker + headers + ORCALib |
| `orca-debugger/1.1/dist/` | .2mg + extracted | ORCA Debugger |
| `orca-suite/opus-ii/dist/` | 2,070 files | Complete ORCA binary suite from Opus ][ CD |
| `gno/2.0.0/dist/` | 3 disk images + extracted | GNO/ME base distribution (3-disk set) |
| `gno/2.0.2+2.0.3-updates/dist/` | .2mg + extracted | Combined GNO updates |
| `gno/2.0.4-update/dist/` | .2mg + extracted | GNO 2.0.4 patch |
| `gno/2.0.6/dist/` | .zip → gno.po + full extraction (803 files) | GNO 2.0.6 consolidated |
| `goldengate/2.0.0/dist/` | .zip → full GoldenGate install tree (1,938 files) | GoldenGate runtime image |
| `goldengate/installer-2018/dist/` | .zip → .pkg + docs | GoldenGate installer |
| `goldengate/2.0.2/source/` | .zip | GoldenGate + profuse source |
| `goldengate/2.0.4/source/` | .zip | GoldenGate source |

### Local Canonical Repo Clones — `/Users/smentzer/source/iigs-official-repos/`

| Directory | Contents |
|-----------|---------|
| `byteworksinc-orca-c` | **Official** ByteWorks ORCA/C 2.2.2 compiler source (Pascal + asm). Built via `GNUmakefile`. |
| `byteworksinc-orcalib` | **Official** ByteWorks ORCALib. `unified` branch = current work (GNO + non-GNO). GNO build uses `TARGET=gno`; adds `gno/locale.asm` override for C-standard `struct lconv` field order. |
| `gno-original` | Original Devin Reade GNO/ME v2.0.6 source |
| `goldengate` | GoldenGate iix emulator source (C++) |
| `goldengate-documentation` | GoldenGate docs |
| `ksherlock-gno` | ksherlock fork of GNO/ME (upstream, unmaintained) |
| `ksherlock-orca-c` | ksherlock fork of ORCA/C |
| `nulib2` | nulib2 — ShrinkIt archive tool source |

---

## Key File Locations

| File | Purpose |
|------|---------|
| `NOTES/devel/doing.builds` | **Authoritative build sequence** |
| `goldengate/build/*.mk` | GNU Makefiles for each build target |
| `goldengate/tools/compare_libc.py` | Symbol comparison between built and reference libc |
| `goldengate/tools/maccatrez.py` | macOS Rez compiler: parses .rez → resource fork xattr (replaces catrez) |
| `goldengate/orcac-tests/tools/omf_dis.py` | OMF v2 parser + 65816 disassembler |
| `diskImages/extracted/` | All files from GNO 2.0.6 reference disk image |
| `diskImages/extracted/metadata.json` | File types, sizes, dates for all extracted files |

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
| `libutil.mk` | `lib/libutil/` (3 C) | `gno-obj/usr/lib/libutil` |
| `libtermcap.mk` | `lib/libtermcap/` (5 C) | `gno-obj/usr/lib/libtermcap` |
| `libcurses.mk` | `lib/libcurses/` (42 C) | `gno-obj/usr/lib/libcurses` |
| `liby.mk` | `lib/liby/` (2 C) | `gno-obj/usr/lib/liby` |
| `netdb.mk` | `lib/netdb/` (26 C) | `gno-obj/usr/lib/libnetdb` |
| `libcontrib.mk` | `lib/libcontrib/` (4 C) | `gno-obj/usr/lib/libcontrib` |
| `phase6.mk` | 79 utilities across bin/, usr.bin/, usr.orca.bin/, sbin/, usr.sbin/ | `gno-obj/bin/`, `gno-obj/usr/bin/`, etc. |
| `phase7.mk` | kern/gno/ (14 C + 16 ASM) + kern/drivers/ (4 ASM linked + 4 standalone) | `gno-obj/kern`, `gno-obj/dev/{null,zero,full,console}` |
