#
# goldengate/build/libc_gno.mk
#
# Build lib/libc/gno/ — GNO-specific libc functions.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libc_gno.mk          # build
#   make -f goldengate/build/libc_gno.mk clean     # remove objects and partial lib
#
# Output: $(LIB_OUT)  — partial library gno-obj/libc_gno.a
#
# Source: lib/libc/gno/
#
# Notes:
#   - 3 ASM files use MCOPY to include pre-generated .mac files.
#     gnocmd.asm → gnocmd.mac (in source dir)
#     parsearg.asm → parsearg.mac (in source dir)
#     stack.asm → stack.mac (in source dir; mcopy path was changed from
#       :obj:gno:lib:libc:gno:stack.mac to stack.mac for GoldenGate)
#   - C files already contain #pragma segment and #pragma optimize in source.
#   - Assembly files use KEEP directive; assembler writes KEEP.A in CWD.
#

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/../gno-obj)
SRC_DIR   := $(REPO_ROOT)/lib/libc/gno
OBJ_DIR   := $(GNO_OBJ)/libc/gno
LIB_OUT   := $(GNO_OBJ)/libc_gno.a

CC        := iix --gno compile
AS        := iix assemble
MAKELIB   := iix makelib
XATTR     := xattr

CFLAGS    := -P +O
ASFLAGS   := +T

PRODOS_OBJ_FINDERINFO := 70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

# Source files — from original Makefile
SRC_ASM := gnocmd.asm parsearg.asm stack.asm
SRC_C   := gnomisc.c gsstring.c map.c stack2.c vsprintmt.c

# Object file lists
OBJ_ASM := $(patsubst %.asm,$(OBJ_DIR)/%.a,$(SRC_ASM))
OBJ_C   := $(patsubst %.c,$(OBJ_DIR)/%.a,$(SRC_C))
OBJS    := $(OBJ_ASM) $(OBJ_C)

MAKELIB_ARGS := $(patsubst $(OBJ_DIR)/%.a,+%.a,$(OBJS))

# ── Default target ─────────────────────────────────────────────────────────────
.PHONY: all
all: $(LIB_OUT)

# ── Partial library ────────────────────────────────────────────────────────────
$(LIB_OUT): $(OBJS) | $(GNO_OBJ)
	@echo "--- makelib libc_gno ---"
	cd $(OBJ_DIR) && $(MAKELIB) $@ $(MAKELIB_ARGS)
	@echo "--- libc_gno.a: $$(wc -c < $@) bytes ---"

# ── Compile C sources ──────────────────────────────────────────────────────────
$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	@echo "--- compile $*.c ---"
	cd $(OBJ_DIR) && $(CC) $(CFLAGS) $(SRC_DIR)/$*.c

# ── Assemble ASM sources ───────────────────────────────────────────────────────
# ASM files use KEEP + MCOPY. Run from SRC_DIR so .mac files resolve.
# KEEP writes MODULE.A in CWD; move to OBJ_DIR and patch FinderInfo.
$(OBJ_DIR)/%.a: $(SRC_DIR)/%.asm $(SRC_DIR)/%.mac | $(OBJ_DIR)
	@echo "--- assemble $*.asm ---"
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) $*.asm
	mv $(SRC_DIR)/$*.A $@
	mv $(SRC_DIR)/$*.ROOT $(OBJ_DIR)/$*.root 2>/dev/null || true
	$(XATTR) -wx com.apple.FinderInfo "$(PRODOS_OBJ_FINDERINFO)" $@

# ── Create output directories ──────────────────────────────────────────────────
$(OBJ_DIR):
	mkdir -p $@

$(GNO_OBJ):
	mkdir -p $@

# ── Clean ──────────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
	@echo "libc/gno objects and partial library removed."
