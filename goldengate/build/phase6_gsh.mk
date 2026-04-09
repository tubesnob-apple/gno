#
# goldengate/build/phase6_gsh.mk
#
# Build gsh — the GNO Shell (bin/gsh/)
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/phase6_gsh.mk         # build gsh
#   make -f goldengate/build/phase6_gsh.mk clean   # remove objects + binary
#
# Output: gno-obj/bin/gsh
# Source: bin/gsh/ (22 ORCA/M .asm files, 21 linked into binary)
#
# Notes:
#   - MCOPY paths fixed: /obj/gno/bin/gsh/xxx.mac → M/xxx.mac
#   - Pre-generated .mac files live in bin/gsh/M/ (committed to repo)
#   - Assembly must run from bin/gsh/ so M/*.mac paths resolve correctly
#   - .ROOT files are deleted after assembly (all are dummy root segments;
#     the stack/dp segment in main.ROOT is not needed — ORCALib provides it)
#   - oldorca.asm is NOT linked (has separate keep directive, not in SRCS)
#   - Links against libtermcap (gno-obj/usr/lib/libtermcap)
#

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/gno_obj)

SRC_DIR   := $(REPO_ROOT)/bin/gsh
GSH_OBJ   := $(GNO_OBJ)/gsh_obj
BIN_OUT   := $(GNO_OBJ)/bin
GSH_OUT   := $(BIN_OUT)/gsh

AS      := iix assemble
LD      := iix --gno link
ASFLAGS := +T


LIBTERMCAP := $(GNO_OBJ)/usr/lib/libtermcap

# Module list — matches Makefile SRCS order (main first for startup)
GSH_MODS := \
	main shell history prompt cmd expand invoke shellutil builtin \
	hash alias dir shellvar jobs sv stdio orca edit term bufpool mmdebug

GSH_OBJS := $(foreach m,$(GSH_MODS),$(GSH_OBJ)/$(m).a)

# ── Top-level target ──────────────────────────────────────────────────────────

.PHONY: all
all: $(GSH_OUT)

# ── Link ─────────────────────────────────────────────────────────────────────

$(GSH_OUT): $(GSH_OBJS) $(LIBTERMCAP) | $(BIN_OUT)
	cd $(GSH_OBJ) && $(LD) -o $(GSH_OUT) $(notdir $(GSH_OBJS)) $(LIBTERMCAP)
	iix chtyp -t exe -a 1 $(GSH_OUT)
	@SIZE=$$(wc -c < $(GSH_OUT)); echo "gsh: $$SIZE bytes (reference: 58624)"

# ── Assemble each module ──────────────────────────────────────────────────────
# Run from SRC_DIR so MCOPY M/xxx.mac resolves; rename .A → .a for portability;
# delete .ROOT (dummy root segments — ORCALib startup provides the real one).

$(GSH_OBJ)/%.a: $(SRC_DIR)/%.asm | $(GSH_OBJ)
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) $*.asm
	iix chtyp -t obj $(SRC_DIR)/$*.A
	mv $(SRC_DIR)/$*.A $(GSH_OBJ)/$*.a
	rm -f $(SRC_DIR)/$*.ROOT

# ── Directory creation ────────────────────────────────────────────────────────

$(GSH_OBJ):
	mkdir -p $@

$(BIN_OUT):
	mkdir -p $@

# ── Clean ─────────────────────────────────────────────────────────────────────

.PHONY: clean
clean:
	rm -f $(GSH_OBJS) $(GSH_OUT) $(GSH_OUT).rsrc.done
	rm -f $(SRC_DIR)/*.A $(SRC_DIR)/*.ROOT
	-rmdir $(GSH_OBJ) 2>/dev/null || true
