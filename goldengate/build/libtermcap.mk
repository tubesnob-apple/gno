#
# goldengate/build/libtermcap.mk
#
# Build libtermcap — terminal capability library for GNO.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libtermcap.mk
#   make -f goldengate/build/libtermcap.mk clean
#
# Output: $(LIB_OUT)
# Source: lib/libtermcap/ (termcap.c tgoto.c tputs.c tparm.c tospeed.c)
# Reference size: 40,386 bytes
#
# CFLAGS notes:
#   -DCM_N -DCM_GT -DCM_B -DCM_D: enable cursor motion capability sets
#   -I$(SRC_DIR): needed for local "termcap.h" and "pathnames.h"
#   -Slibtermcap: sets OMF segment name prefix

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),/Library/GoldenGate)
LIB_OUT   ?= $(abspath $(REPO_ROOT)/gno_obj/usr/lib/libtermcap)
OBJ_DIR   ?= $(abspath $(REPO_ROOT)/gno_obj/libtermcap_obj)

SRC_DIR   := $(REPO_ROOT)/lib/libtermcap

CC        := iix --gno compile
MAKELIB   := iix makelib

# -P: suppress "Compiling..." line; +O: enable optimizations
# Segment prefix via pragma in source (ORCA/C doesn't support -S on CLI)
CCFLAGS   := -P +O

C_SRCS    := termcap.c getcap.c tgoto.c tputs.c tparm.c tospeed.c
C_OBJS    := $(patsubst %.c,$(OBJ_DIR)/%.a,$(C_SRCS))

.PHONY: all
all: $(LIB_OUT)

$(LIB_OUT): $(C_OBJS) | $(dir $(LIB_OUT))
	rm -f $(LIB_OUT)
	cd $(OBJ_DIR) && ls *.a | sort | while read f; do echo "+$$f"; done | \
	  xargs -n 20 sh -c '$(MAKELIB) $(LIB_OUT) "$$@"' _

# Compile from SRC_DIR so local headers (termcap.h, pathnames.h) resolve
$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	cd $(SRC_DIR) && $(CC) $(CCFLAGS) $*.c && mv $*.a $(OBJ_DIR)/ && rm -f $*.sym 2>/dev/null || true

$(OBJ_DIR):
	mkdir -p $@

$(dir $(LIB_OUT)):
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
