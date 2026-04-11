#
# goldengate/build/libtermcap.mk
#
# Build libtermcap — terminal capability library for GNO.
# Uses the native 65816 assembly implementation (termcap.asm) which is
# significantly faster than the C port.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libtermcap.mk
#   make -f goldengate/build/libtermcap.mk clean
#
# Output: $(LIB_OUT)
# Source: lib/libtermcap/termcap.asm
# Reference size: 40,386 bytes (C version); asm version is ~5KB

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
LIB_OUT   ?= $(abspath $(REPO_ROOT)/gno_obj/usr/lib/libtermcap)
OBJ_DIR   ?= $(abspath $(REPO_ROOT)/gno_obj/libtermcap_obj)

SRC_DIR   := $(REPO_ROOT)/lib/libtermcap

ASM       := iix assemble
MAKELIB   := iix makelib

ASM_OBJ   := $(OBJ_DIR)/termcap.A

.PHONY: all
all: $(LIB_OUT)

$(LIB_OUT): $(ASM_OBJ) | $(dir $(LIB_OUT))
	rm -f $(LIB_OUT)
	cd $(OBJ_DIR) && $(MAKELIB) $(LIB_OUT) +termcap.A

# Assemble from OBJ_DIR so termcap.mac (copied there) resolves for mcopy.
# iix assemble writes output to CWD.
$(ASM_OBJ): $(SRC_DIR)/termcap.asm $(SRC_DIR)/termcap.mac | $(OBJ_DIR)
	cp $(SRC_DIR)/termcap.mac $(OBJ_DIR)/
	cd $(OBJ_DIR) && $(ASM) +T $(SRC_DIR)/termcap.asm
	iix chtyp -t obj $(ASM_OBJ)

$(OBJ_DIR):
	mkdir -p $@

$(dir $(LIB_OUT)):
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
