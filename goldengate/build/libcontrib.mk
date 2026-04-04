#
# goldengate/build/libcontrib.mk
#
# Build libcontrib — GNO contributed utilities library.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libcontrib.mk
#   make -f goldengate/build/libcontrib.mk clean
#
# Output: $(LIB_OUT)
# Source: lib/libcontrib/ (copyfile.c expandpath.c strarray.c xalloc.c errnoGS.c)
# Reference size: 19,889 bytes
#
# Note: contrib.h is a local header — compile from SRC_DIR.
# errnoGS.c uses gsos.h (available in GNO --gno mode).

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(HOME)/Library/GoldenGate
LIB_OUT   ?= $(abspath $(REPO_ROOT)/../gno-obj/usr/lib/libcontrib)
OBJ_DIR   ?= $(abspath $(REPO_ROOT)/../gno-obj/libcontrib_obj)

SRC_DIR   := $(REPO_ROOT)/lib/libcontrib

CC        := iix --gno compile
MAKELIB   := iix makelib

CCFLAGS   := -P +O

C_SRCS    := copyfile.c expandpath.c strarray.c xalloc.c
C_OBJS    := $(patsubst %.c,$(OBJ_DIR)/%.a,$(C_SRCS))

.PHONY: all
all: $(LIB_OUT)

$(LIB_OUT): $(C_OBJS) | $(dir $(LIB_OUT))
	rm -f $(LIB_OUT)
	cd $(OBJ_DIR) && ls *.a | sort | while read f; do echo "+$$f"; done | \
	  xargs -n 20 sh -c '$(MAKELIB) $(LIB_OUT) "$$@"' _

# Compile from SRC_DIR so local contrib.h resolves
$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	cd $(SRC_DIR) && $(CC) $(CCFLAGS) $*.c && mv $*.a $(OBJ_DIR)/

$(OBJ_DIR):
	mkdir -p $@

$(dir $(LIB_OUT)):
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
