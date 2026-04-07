#
# goldengate/build/libc_regex.mk — Build lib/libc/regex/ (4 C files, POSIX regex)
#
# Notes:
#   - Has local headers (utils.h, regex2.h, cclass.h, cname.h) — compile from SRC_DIR
#   - regexec.c #includes engine.c twice (with different defines) — not a separate compile unit
#   - POSIX_MISTAKE define added directly to regcomp.c (iix has no -D flag)
#
REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/gno_obj)
SRC_DIR   := $(REPO_ROOT)/lib/libc/regex
OBJ_DIR   := $(GNO_OBJ)/libc/regex
LIB_OUT   := $(GNO_OBJ)/libc_regex.a

CC        := iix --gno compile
MAKELIB   := iix makelib
CFLAGS    := -P +O

SRC_C := regcomp.c regerror.c regexec.c regfree.c
OBJ_C := $(patsubst %.c,$(OBJ_DIR)/%.a,$(SRC_C))

.PHONY: all clean
all: $(LIB_OUT)

$(LIB_OUT): $(OBJ_C) | $(GNO_OBJ)
	@echo "--- makelib libc_regex ---"
	cd $(OBJ_DIR) && $(MAKELIB) $@ $(patsubst $(OBJ_DIR)/%.a,+%.a,$(OBJ_C))
	@echo "--- libc_regex.a: $$(wc -c < $@) bytes ---"

# Compile from SRC_DIR so local headers resolve.
$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	@echo "--- compile $*.c ---"
	cd $(SRC_DIR) && $(CC) $(CFLAGS) $*.c
	mv $(SRC_DIR)/$*.a $@
	mv $(SRC_DIR)/$*.root $(OBJ_DIR)/$*.root 2>/dev/null || true
	-rm -f $(SRC_DIR)/$*.sym 2>/dev/null || true

$(OBJ_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
