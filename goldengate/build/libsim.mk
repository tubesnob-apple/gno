#
# goldengate/build/libsim.mk
#
# Build libsim — Serial Interrupt Manager library for GNO.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libsim.mk
#   make -f goldengate/build/libsim.mk clean
#
# Output: $(LIB_OUT)
# Source: lib/libsim/simlib.asm
#
# Notes:
#   - simlib.mac contains all required macros (str, ph4, subroutine, return, _SendRequest)
#   - simequates.equ contains SIM error/port/opcode constants
#   - Assembly output gets $B0 type by default; patched to $B1 for makelib

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
LIB_OUT   ?= $(abspath $(REPO_ROOT)/gno-obj/usr/lib/libsim)

SRC_DIR   := $(REPO_ROOT)/lib/libsim

AS        := iix assemble
MAKELIB   := iix makelib
SET_FINDERINFO := python3 $(REPO_ROOT)/goldengate/tools/set-finder-info.py

ASFLAGS   := +T
PRODOS_OBJ_FINDERINFO := 70 B1 00 00 70 64 6F 73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

.PHONY: all
all: $(LIB_OUT)

$(LIB_OUT): $(SRC_DIR)/simlib.A | $(dir $(LIB_OUT))
	rm -f $(LIB_OUT)
	$(MAKELIB) $(LIB_OUT) +$(SRC_DIR)/simlib.A

$(SRC_DIR)/simlib.A: $(SRC_DIR)/simlib.asm $(SRC_DIR)/simlib.mac $(SRC_DIR)/simequates.equ
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) simlib.asm
	$(SET_FINDERINFO) $@ "$(PRODOS_OBJ_FINDERINFO)"

$(dir $(LIB_OUT)):
	mkdir -p $@

.PHONY: clean
clean:
	rm -f $(SRC_DIR)/simlib.A $(SRC_DIR)/simlib.ROOT
	rm -f $(LIB_OUT)
