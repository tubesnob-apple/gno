#
# goldengate/build/libcrypt.mk
#
# Build libcrypt — DES encryption library for GNO.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libcrypt.mk
#   make -f goldengate/build/libcrypt.mk clean
#
# Output: $(LIB_OUT)
# Source: lib/libcrypt/crypta.asm + crypt.c
# Reference size: 7,180 bytes

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
LIB_OUT   ?= $(abspath $(REPO_ROOT)/../gno-obj/usr/lib/libcrypt)
OBJ_DIR   ?= $(abspath $(REPO_ROOT)/../gno-obj/libcrypt_obj)

SRC_DIR   := $(REPO_ROOT)/lib/libcrypt

AS        := iix assemble
CC        := iix --gno compile
MAKELIB   := iix makelib
SET_FINDERINFO := python3 $(REPO_ROOT)/goldengate/tools/set-finder-info.py

ASFLAGS   := +T
CCFLAGS   := -P +O
PRODOS_OBJ_FINDERINFO := 70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

.PHONY: all
all: $(LIB_OUT)

C_SRCS   := crypt.c
C_OBJS   := $(patsubst %.c,$(OBJ_DIR)/%.a,$(C_SRCS))

$(LIB_OUT): $(OBJ_DIR)/crypta.a $(C_OBJS) | $(dir $(LIB_OUT))
	rm -f $(LIB_OUT)
	cd $(OBJ_DIR) && ls *.a | sort | while read f; do echo "+$$f"; done | \
	  xargs -n 20 sh -c '$(MAKELIB) $(LIB_OUT) "$$@"' _

# Assemble crypta.asm (crypta.mac already exists in SRC_DIR)
$(OBJ_DIR)/crypta.a: $(SRC_DIR)/crypta.asm $(SRC_DIR)/crypta.mac | $(OBJ_DIR)
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) crypta.asm
	mv $(SRC_DIR)/crypta.A $@
	rm -f $(SRC_DIR)/crypta.ROOT
	$(SET_FINDERINFO) $@ "$(PRODOS_OBJ_FINDERINFO)"

# Compile C sources
$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	cd $(OBJ_DIR) && $(CC) $(CCFLAGS) $(SRC_DIR)/$*.c

$(OBJ_DIR):
	mkdir -p $@

$(dir $(LIB_OUT)):
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
