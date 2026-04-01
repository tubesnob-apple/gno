#
# goldengate/build/orcalib.mk
#
# Build ORCALib — the 65816 assembly runtime library for ORCA/C.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/orcalib.mk          # build
#   make -f goldengate/build/orcalib.mk clean     # remove objects
#   make -f goldengate/build/orcalib.mk install   # copy to GoldenGate lib
#
# Output: $(LIB_OUT)  (ProDOS library file)
#
# Source: lib/ORCALib/*.asm
# Reference: lib/ORCALib/make  (original ORCA shell script — not bash)
#
# Notes on iix assembly output:
#   - iix assemble (no -o) writes MODULE.A + MODULE.ROOT in the CURRENT directory
#   - iix assemble -o path/foo.a writes path/foo.a.A + path/foo.a.ROOT (appends .A!)
#   - So we assemble without -o, running from SRC_DIR, producing SRC_DIR/MODULE.A
#   - macOS is case-insensitive: makelib +foo.a finds foo.A correctly
#   - makelib must be run from SRC_DIR so relative +foo.a args resolve
#   - makelib needs the .a suffix (avoids matching .asm source files)
#
# Notes on ProDOS file types:
#   - GoldenGate sets ProDOS type $B1 (obj) only for files written in /tmp (prefix 3:)
#   - Files assembled in other directories get type $B0 (unknown), which makelib rejects
#   - Fix: after assembly, patch FinderInfo xattr to set type $B1, aux $0000
#   - FinderInfo layout: [type-byte0='p'][ProDOS-type][aux-hi][aux-lo] 'pdos' zeros...
#

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(HOME)/Library/GoldenGate
LIB_OUT   ?= $(abspath $(REPO_ROOT)/../gno-obj/orcalib)

SRC_DIR   := $(REPO_ROOT)/lib/ORCALib

AS        := iix assemble
MAKELIB   := iix makelib
XATTR     := xattr

# Assembler flags: +T = treat all errors as terminal
ASFLAGS   := +T

# ProDOS FinderInfo for object module type $B1, aux $0000, creator 'pdos'
# GoldenGate only sets $B1 for files in /tmp (prefix 3:); patch it here.
PRODOS_OBJ_FINDERINFO := 70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

# Assembly modules — order matches original ORCA make script for makelib
MODULES := \
	vars \
	assert \
	cc \
	setjmp \
	ctype \
	string \
	stdlib \
	time \
	signal \
	toolglue \
	orca \
	fcntl \
	stdio

# iix assemble (no -o) writes MODULE.A and MODULE.ROOT in the current directory.
# makelib +MODULE.a finds MODULE.A on macOS (case-insensitive).
OBJ_A    := $(foreach m,$(MODULES),$(SRC_DIR)/$(m).A)
OBJ_ARGS := $(foreach m,$(MODULES),+$(m).a)

# ── Default target ────────────────────────────────────────────────────────────
.PHONY: all
all: $(LIB_OUT)

# ── Library archive ───────────────────────────────────────────────────────────
$(LIB_OUT): $(OBJ_A) | $(dir $(LIB_OUT))
	@echo "--- makelib orcalib ---"
	cd $(SRC_DIR) && $(MAKELIB) $(LIB_OUT) $(OBJ_ARGS)

# ── Assemble each module ──────────────────────────────────────────────────────
# iix assemble without -o writes to current directory.
# cd to SRC_DIR first so includes (equates.asm, *.macros) resolve correctly.
# After assembly, patch the FinderInfo xattr: GoldenGate sets $B0 for files
# outside /tmp; makelib requires $B1 (object module type).
$(SRC_DIR)/%.A: $(SRC_DIR)/%.asm $(SRC_DIR)/equates.asm
	@echo "--- assemble $*.asm ---"
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) $*.asm
	$(XATTR) -wx com.apple.FinderInfo "$(PRODOS_OBJ_FINDERINFO)" $@

# ── Create output directory ───────────────────────────────────────────────────
$(dir $(LIB_OUT)):
	mkdir -p $@

# ── Install into GoldenGate lib/ ─────────────────────────────────────────────
.PHONY: install
install: $(LIB_OUT)
	@echo "--- install orcalib -> $(GG_ROOT)/lib/ORCALib ---"
	cp -p $(LIB_OUT) $(GG_ROOT)/lib/ORCALib

# ── Clean ─────────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -f $(OBJ_A) $(foreach m,$(MODULES),$(SRC_DIR)/$(m).ROOT)
	rm -f $(LIB_OUT)
	@echo "ORCALib objects and library removed."
