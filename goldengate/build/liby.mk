#
# goldengate/build/liby.mk
#
# Build liby — yacc runtime library for GNO.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/liby.mk
#   make -f goldengate/build/liby.mk clean
#
# Output: $(LIB_OUT)
# Source: lib/liby/ (main.c yyerror.c)
# Reference size: 660 bytes

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(HOME)/Library/GoldenGate
LIB_OUT   ?= $(abspath $(REPO_ROOT)/../gno-obj/usr/lib/liby)
OBJ_DIR   ?= $(abspath $(REPO_ROOT)/../gno-obj/liby_obj)

SRC_DIR   := $(REPO_ROOT)/lib/liby

CC        := iix --gno compile
MAKELIB   := iix makelib

CCFLAGS   := -P +O

C_SRCS    := main.c yyerror.c
C_OBJS    := $(patsubst %.c,$(OBJ_DIR)/%.a,$(C_SRCS))

.PHONY: all
all: $(LIB_OUT)

$(LIB_OUT): $(C_OBJS) | $(dir $(LIB_OUT))
	rm -f $(LIB_OUT)
	ls $(OBJ_DIR)/*.a | sort | while read f; do echo "+$$f"; done | \
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
