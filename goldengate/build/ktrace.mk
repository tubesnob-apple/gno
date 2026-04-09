#
# goldengate/build/ktrace.mk
#
# Build libktrace — WDM debug trace library for GNO user-space programs
#
# Usage (from REPO_ROOT):
#   make -f goldengate/build/ktrace.mk          # build libktrace
#   make -f goldengate/build/ktrace.mk clean     # remove objects + library
#
# Source:  lib/ktrace/ktrace.c
# Output:  gno_obj/usr/lib/libktrace
#

REPO_ROOT  ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ    ?= $(abspath $(REPO_ROOT)/gno_obj)

SRC_DIR    := $(REPO_ROOT)/lib/ktrace
OBJ_DIR    := $(GNO_OBJ)/ktrace_obj
LIB_OUT    := $(GNO_OBJ)/usr/lib/libktrace

.PHONY: all clean

all: $(LIB_OUT)

$(LIB_OUT): $(OBJ_DIR)/ktrace.a | $(dir $(LIB_OUT))
	@echo "=== libktrace: makelib ==="
	rm -f $(LIB_OUT)
	cd $(OBJ_DIR) && iix makelib $(LIB_OUT) +ktrace.a
	@echo "=== libktrace: done ===" && ls -l $(LIB_OUT)

$(OBJ_DIR)/ktrace.a: $(SRC_DIR)/ktrace.c $(SRC_DIR)/ktrace.h | $(OBJ_DIR)
	@echo "=== libktrace: compile ==="
	cd $(OBJ_DIR) && iix --gno compile -I -P cc=-I$(SRC_DIR) $(SRC_DIR)/ktrace.c
	@rm -f $(OBJ_DIR)/ktrace.sym 2>/dev/null || true

$(OBJ_DIR) $(dir $(LIB_OUT)):
	@mkdir -p $@

clean:
	@echo "=== libktrace: clean ==="
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
