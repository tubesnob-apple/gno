#
# goldengate/build/libc_locale.mk — Build lib/libc/locale/ (1 C file)
#
REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/../gno-obj)
SRC_DIR   := $(REPO_ROOT)/lib/libc/locale
OBJ_DIR   := $(GNO_OBJ)/libc/locale
LIB_OUT   := $(GNO_OBJ)/libc_locale.a

CC        := iix --gno compile
MAKELIB   := iix makelib
CFLAGS    := -P +O

SRC_C := table.c
OBJ_C := $(patsubst %.c,$(OBJ_DIR)/%.a,$(SRC_C))

.PHONY: all clean
all: $(LIB_OUT)

$(LIB_OUT): $(OBJ_C) | $(GNO_OBJ)
	@echo "--- makelib libc_locale ---"
	cd $(OBJ_DIR) && $(MAKELIB) $@ $(patsubst $(OBJ_DIR)/%.a,+%.a,$(OBJ_C))
	@echo "--- libc_locale.a: $$(wc -c < $@) bytes ---"

$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	@echo "--- compile $*.c ---"
	cd $(OBJ_DIR) && $(CC) $(CFLAGS) $(SRC_DIR)/$*.c

$(OBJ_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
