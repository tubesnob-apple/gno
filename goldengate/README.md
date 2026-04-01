# goldengate/

This directory contains the modern build infrastructure for GNO/ME using GoldenGate + iix on macOS.

The original GNO Makefiles (using `dmake` and GNO namespace paths) are preserved throughout
the repo as reference material but cannot be used directly. This directory replaces them.

## Files

| File | Purpose |
|------|---------|
| `setup.sh` | Environment verification and directory setup. Run once before building. |
| `index.html` | Full knowledge base — open in a browser for project overview, toolchain status, build plan, archive inventory, and TODO list. |

## Quick Start

```bash
# 1. Verify environment
bash goldengate/setup.sh

# 2. Open knowledge base
open goldengate/index.html
```

## Build Approach

GNU make + `iix compile` / `iix link` / `iix makelib` / `iix assemble`

This is the same pattern used by the tubesnob-applespi project. The GoldenGate iix
command provides ORCA/C 2.2.0 (C17-capable), the ORCA/M assembler, the linker, and
MakeLib — all the tools needed to produce 65816 Apple IIgs binaries from macOS.

## Adding Build Scripts

As build phases are implemented, add them here:

```
goldengate/
├── build/
│   ├── orcalib.mk      # Phase 2: ORCALib assembly
│   ├── libc.mk         # Phase 5: C library
│   ├── libs.mk         # Phase 6: support libraries
│   ├── utilities.mk    # Phase 8: bin/, usr.bin/, etc.
│   └── kernel.mk       # Phase 9: kern/
└── package.sh          # Phase 10: produce .shk / disk image
```

## Key References

- `CLAUDE.md` — project overview, current state, full TODO
- `NOTES/devel/doing.builds` — authoritative build sequence from original authors
- `/Volumes/Storage/IIgs/` — documentation, ORCA archives, disk images
- `build.tools/dmake.startup` — original tool definitions (reference for flags)
