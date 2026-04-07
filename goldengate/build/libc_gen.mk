#
# goldengate/build/libc_gen.mk
#
# Build lib/libc/gen/ — general C library functions.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libc_gen.mk          # build
#   make -f goldengate/build/libc_gen.mk clean     # remove objects and partial lib
#   make -f goldengate/build/libc_gen.mk validate  # compare size to 2.0.6 reference
#
# Output: $(LIB_OUT)  — partial library gno-obj/libc_gen.a
#         All objects: gno-obj/libc/gen/*.a
#
# Source: lib/libc/gen/
#
# Notes:
#   - Must use 'iix --gno compile' (not plain 'iix compile') to define __GNO__.
#     fnmatch.c guards #include "collate.h" with #ifndef __GNO__; other files
#     use __GNO__ to select GNO-specific code paths.
#   - iix compile writes output to CWD. Compile via: cd OBJ_DIR && iix --gno compile SRC
#   - iix compile does not support -S (segment name) or -O<n> CLI flags.
#     Segment name (libc_gen__) and optimize level (78) must come from source
#     pragmas. Source files lack these pragmas; we inject via a per-build prefix
#     header $(OBJ_DIR)/libc_gen_pfx.h using -I.
#     Note: iix compile doesn't support -include, but ORCA/C's orcacdefs path
#     is searched for defaults.h automatically. We cannot easily inject pragmas
#     without modifying source; instead we rely on +O flag (generic optimize on).
#   - Assembly (setjmp.asm): iix assemble writes MODULE.A + MODULE.ROOT in CWD.
#     Must patch FinderInfo xattr to $B1 (iix assemble outside /tmp gives $B0).
#   - Source also contains syslog2.asm and oldlog.c — NOT in original Makefile,
#     not built here.
#   - Reference binary: diskImages/extracted/lib/libc (482,317 bytes total libc)
#     gen contributes ~23 source modules to that total.
#

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/gno_obj)
SRC_DIR   := $(REPO_ROOT)/lib/libc/gen
OBJ_DIR   := $(GNO_OBJ)/libc/gen
LIB_OUT   := $(GNO_OBJ)/libc_gen.a

CC        := iix --gno compile
AS        := iix assemble
MAKELIB   := iix makelib
SET_FINDERINFO := python3 $(REPO_ROOT)/goldengate/tools/set-finder-info.py

# +O enables optimizations (closest available to original -O78).
# -P suppresses the "Compiling..." progress line.
# Original also used -S libc_gen__ (segment name) — not supported by iix CLI;
# source pragmas would be needed to set segment names.
CFLAGS    := -P +O
ASFLAGS   := +T

# ProDOS FinderInfo for object module type $B1, aux $0000, creator 'pdos'
PRODOS_OBJ_FINDERINFO := 70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

# Source files — from original lib/libc/gen/Makefile
# oldlog.c added: defines old_syslog(), present in reference 2.0.6 libc
# (syslog2.asm is an alternate asm implementation of syslog — not built here,
#  the C version syslog.c is used instead; both export the same API)
SRC_C := \
	basename.c \
	compat.c \
	dirent.c \
	err.c \
	errlist.c \
	fnmatch.c \
	fts.c \
	getcwd.c \
	getgrent.c \
	getlogin.c \
	getpass.c \
	getpwent.c \
	getttyent.c \
	hostname.c \
	oldlog.c \
	popen.c \
	psignal.c \
	pwcache.c \
	scandir.c \
	siglist.c \
	sleep.c \
	syslog.c \
	termios.c \
	tty.c \
	uname.c \
	unvis.c \
	utime.c \
	vis.c

SRC_ASM := setjmp.asm

# Object file lists
OBJ_C   := $(patsubst %.c,$(OBJ_DIR)/%.a,$(SRC_C))
OBJ_ASM := $(patsubst %.asm,$(OBJ_DIR)/%.a,$(SRC_ASM))
OBJS    := $(OBJ_ASM) $(OBJ_C)

# makelib +arg list (relative names, run from OBJ_DIR)
MAKELIB_ARGS := $(patsubst $(OBJ_DIR)/%.a,+%.a,$(OBJS))

# ── Default target ─────────────────────────────────────────────────────────────
.PHONY: all
all: $(LIB_OUT)

# ── Partial library ────────────────────────────────────────────────────────────
$(LIB_OUT): $(OBJS) | $(GNO_OBJ)
	@echo "--- makelib libc_gen ---"
	cd $(OBJ_DIR) && $(MAKELIB) $@ $(MAKELIB_ARGS)
	@echo "--- libc_gen.a: $$(wc -c < $@) bytes ---"

# ── Compile C sources ──────────────────────────────────────────────────────────
# iix --gno compile writes foo.a + foo.root in CWD.
# cd to OBJ_DIR so output lands there; pass full path to source.
$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	@echo "--- compile $*.c ---"
	cd $(OBJ_DIR) && $(CC) $(CFLAGS) $(SRC_DIR)/$*.c

# ── Assemble ASM sources ───────────────────────────────────────────────────────
# iix assemble writes $*.A + $*.ROOT in CWD (uppercase A).
# Must run from SRC_DIR so any local includes resolve.
# Patch FinderInfo: iix assemble outside /tmp produces $B0; makelib requires $B1.
$(OBJ_DIR)/%.a: $(SRC_DIR)/%.asm | $(OBJ_DIR)
	@echo "--- assemble $*.asm ---"
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) $*.asm
	mv $(SRC_DIR)/$*.A $@
	mv $(SRC_DIR)/$*.ROOT $(OBJ_DIR)/$*.root 2>/dev/null || true
	$(SET_FINDERINFO) $@ "$(PRODOS_OBJ_FINDERINFO)"

# ── Create output directories ──────────────────────────────────────────────────
$(OBJ_DIR):
	mkdir -p $@

$(GNO_OBJ):
	mkdir -p $@

# ── Validate against 2.0.6 reference ──────────────────────────────────────────
# The full libc reference is 482,317 bytes. This target shows the partial
# library size as a sanity check. Full validation happens in libc.mk.
REF_LIBC := $(REPO_ROOT)/diskImages/extracted/lib/libc

.PHONY: validate
validate: $(LIB_OUT)
	@echo "--- libc_gen.a size: $$(wc -c < $(LIB_OUT)) bytes"
	@echo "--- reference libc total: $$(wc -c < $(REF_LIBC)) bytes"
	@echo "(libc_gen is a partial archive; full comparison done in libc.mk)"

# ── Clean ──────────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
	@echo "libc/gen objects and partial library removed."
