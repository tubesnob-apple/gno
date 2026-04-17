# install-gno-headers.mk — Install GNO/ME headers into the GoldenGate --gno environment
#
# This Makefile owns the GNO-specific header installation for iix --gno mode.
# The ORCA/C repo installs only ORCA toolbox headers; it knows nothing about GNO.
#
# What this does:
#   Rebuilds lib/ORCACDefs/ for --gno mode by:
#     1. Removing any stale symlinks (cleanup from prior install approach)
#     2. Copying ORCA toolbox headers from Libraries/ORCACDefs/ (base layer)
#     3. Copying GNO headers from include/ on top — GNO wins for all overlapping files
#     4. Installing Defaults.h from this repo (defines __GNO__, sets pragma paths)
#
# Result: lib/ORCACDefs/ contains everything needed for --gno compilation.
#         No symlinks. No usr/include/ dependency.
#
# Usage:
#   make -f goldengate/install-gno-headers.mk

GOLDENGATE    := $(or $(GOLDEN_GATE),$(ORCA_ROOT),/Library/GoldenGate)
LIBRARIES_ORC := $(GOLDENGATE)/Libraries/ORCACDefs
LIB_ORC       := $(GOLDENGATE)/lib/ORCACDefs

REPO_ROOT     := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
REPO_ROOT     := $(patsubst %/goldengate,%,$(REPO_ROOT))
GNO_INCLUDE   := $(REPO_ROOT)/include
GNO_ORCACDEFS := $(REPO_ROOT)/orcacdefs

.PHONY: all lib-orcacdefs status

all: lib-orcacdefs

# ── Rebuild lib/ORCACDefs/ for --gno mode ─────────────────────────────────
#
# Step 1: Remove any existing symlinks (safe to run after previous symlink-based install)
# Step 2: Copy ORCA toolbox headers — all flat .h files from Libraries/ORCACDefs/
# Step 3: rsync GNO include/ tree on top — overwrites ORCA versions for overlapping
#          headers; also brings in subdirs (arpa/, gno/, machine/, net/, netinet/,
#          protocols/, rpc/, sys/) and their contents as regular files
# Step 4: Install Defaults.h from this repo (must come last to win over any other version)
lib-orcacdefs:
	@echo "==> Rebuilding $(LIB_ORC)/"
	@mkdir -p "$(LIB_ORC)"
	@# Step 1: Remove stale symlinks
	@count=$$(find "$(LIB_ORC)" -maxdepth 2 -type l | wc -l | tr -d ' '); \
	find "$(LIB_ORC)" -maxdepth 2 -type l -delete; \
	[ "$$count" -gt 0 ] && echo "    Removed $$count stale symlinks" || true
	@# Step 2: ORCA toolbox headers (base layer — flat files only, no subdirs in Libraries/)
	@cp -f "$(LIBRARIES_ORC)"/*.h "$(LIB_ORC)/"
	@echo "    $$(ls "$(LIBRARIES_ORC)"/*.h | wc -l | tr -d ' ') ORCA toolbox headers copied"
	@# Step 3: GNO headers (overwrite ORCA versions; also installs subdirs)
	@rsync -a "$(GNO_INCLUDE)/" "$(LIB_ORC)/"
	@echo "    $$(find "$(GNO_INCLUDE)" -name '*.h' | wc -l | tr -d ' ') GNO headers synced (flat + subdirs)"
	@# Step 4: Defaults.h from this repo
	@cp "$(GNO_ORCACDEFS)/Defaults.h" "$(LIB_ORC)/Defaults.h"
	@echo "    Defaults.h installed from repo"
	@echo "==> Done. lib/ORCACDefs/: $$(find "$(LIB_ORC)" -name '*.h' | wc -l | tr -d ' ') total headers."

# ── Diagnostic ────────────────────────────────────────────────────────────
status:
	@echo "GoldenGate: $(GOLDENGATE)"
	@echo "lib/ORCACDefs/ total .h files: $$(find "$(LIB_ORC)" -name '*.h' | wc -l | tr -d ' ')"
	@symlinks=$$(find "$(LIB_ORC)" -maxdepth 2 -type l | wc -l | tr -d ' '); \
	 regular=$$(find "$(LIB_ORC)" -maxdepth 1 -type f | wc -l | tr -d ' '); \
	 dirs=$$(find "$(LIB_ORC)" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' '); \
	 echo "  top-level: $$regular files, $$dirs subdirs, $$symlinks symlinks (want 0)"
	@echo "  Defaults.h: $$([ -f "$(LIB_ORC)/Defaults.h" ] && echo present || echo MISSING)"
