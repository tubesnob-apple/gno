#
# goldengate/build/libc_stdlib.mk — Build lib/libc/stdlib/ (4 C + 1 ASM)
#
REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/../gno-obj)
SRC_DIR   := $(REPO_ROOT)/lib/libc/stdlib
OBJ_DIR   := $(GNO_OBJ)/libc/stdlib
LIB_OUT   := $(GNO_OBJ)/libc_stdlib.a

CC        := iix --gno compile
AS        := iix assemble
MAKELIB   := iix makelib
SET_FINDERINFO := python3 $(REPO_ROOT)/goldengate/tools/set-finder-info.py
CFLAGS    := -P +O
ASFLAGS   := +T
PRODOS_OBJ_FINDERINFO := 70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

SRC_C   := cvt.c environ.c getopt.c getsubopt.c
SRC_ASM := fpspecnum.asm
OBJ_C   := $(patsubst %.c,$(OBJ_DIR)/%.a,$(SRC_C))
OBJ_ASM := $(patsubst %.asm,$(OBJ_DIR)/%.a,$(SRC_ASM))
OBJS    := $(OBJ_ASM) $(OBJ_C)

.PHONY: all clean
all: $(LIB_OUT)

$(LIB_OUT): $(OBJS) | $(GNO_OBJ)
	@echo "--- makelib libc_stdlib ---"
	cd $(OBJ_DIR) && $(MAKELIB) $@ $(patsubst $(OBJ_DIR)/%.a,+%.a,$(OBJS))
	@echo "--- libc_stdlib.a: $$(wc -c < $@) bytes ---"

$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	@echo "--- compile $*.c ---"
	cd $(OBJ_DIR) && $(CC) $(CFLAGS) $(SRC_DIR)/$*.c

GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
AINCLUDE  := $(GG_ROOT)/Libraries/AINClude

# fpspecnum.asm uses COPY E16.SANE (SANE equates).
# ORCA/M resolves COPY relative to CWD; original path was
# :lang:orca:libraries:ainclude:e16.sane (GNO namespace, doesn't resolve in iix).
# We change the source COPY to just "E16.SANE" and symlink it into SRC_DIR.
$(OBJ_DIR)/fpspecnum.a: $(SRC_DIR)/fpspecnum.asm $(SRC_DIR)/fpspecnum.mac | $(OBJ_DIR)
	@echo "--- assemble fpspecnum.asm ---"
	ln -sf $(AINCLUDE)/E16.SANE $(SRC_DIR)/E16.SANE
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) fpspecnum.asm
	rm -f $(SRC_DIR)/E16.SANE
	mv $(SRC_DIR)/fpspecnum.A $@
	mv $(SRC_DIR)/fpspecnum.ROOT $(OBJ_DIR)/fpspecnum.root 2>/dev/null || true
	$(SET_FINDERINFO) $@ "$(PRODOS_OBJ_FINDERINFO)"

$(OBJ_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
