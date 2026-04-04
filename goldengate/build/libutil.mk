#
# goldengate/build/libutil.mk
#
# Build libutil — login/tty utilities for GNO.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libutil.mk
#   make -f goldengate/build/libutil.mk clean
#
# Output: $(LIB_OUT)
# Source: lib/libutil/ (login.c logintty.c logwtmp.c)
# Reference size: 2,146 bytes  (3 modules: login, logintty, logwtmp)
#
# Note: hexdump.c, pty.c, setproc.c, logout.c are NOT in the reference
# build (reference only has login, logintty, logwtmp).

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
LIB_OUT   ?= $(abspath $(REPO_ROOT)/../gno-obj/usr/lib/libutil)
OBJ_DIR   ?= $(abspath $(REPO_ROOT)/../gno-obj/libutil_obj)

SRC_DIR   := $(REPO_ROOT)/lib/libutil

CC        := iix --gno compile
MAKELIB   := iix makelib

CCFLAGS   := -P +O

C_SRCS    := login.c logintty.c logwtmp.c
C_OBJS    := $(patsubst %.c,$(OBJ_DIR)/%.a,$(C_SRCS))

.PHONY: all
all: $(LIB_OUT)

$(LIB_OUT): $(C_OBJS) | $(dir $(LIB_OUT))
	rm -f $(LIB_OUT)
	cd $(OBJ_DIR) && ls *.a | sort | while read f; do echo "+$$f"; done | \
	  xargs -n 20 sh -c '$(MAKELIB) $(LIB_OUT) "$$@"' _

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
