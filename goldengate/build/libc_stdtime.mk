#
# goldengate/build/libc_stdtime.mk — Build lib/libc/stdtime/ (only strftime.c active)
#
# Note: original Makefile had asctime.c, difftime.c, localtime.c commented out.
# Only strftime.c is built (matching the original 2.0.6 build).
#
REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/gno_obj)
SRC_DIR   := $(REPO_ROOT)/lib/libc/stdtime
OBJ_DIR   := $(GNO_OBJ)/libc/stdtime
LIB_OUT   := $(GNO_OBJ)/libc_stdtime.a

CC        := iix --gno compile
MAKELIB   := iix makelib
CFLAGS    := -P +O

SRC_C := strftime.c
OBJ_C := $(patsubst %.c,$(OBJ_DIR)/%.a,$(SRC_C))

.PHONY: all clean
all: $(LIB_OUT)

$(LIB_OUT): $(OBJ_C) | $(GNO_OBJ)
	@echo "--- makelib libc_stdtime ---"
	cd $(OBJ_DIR) && $(MAKELIB) $@ $(patsubst $(OBJ_DIR)/%.a,+%.a,$(OBJ_C))
	@echo "--- libc_stdtime.a: $$(wc -c < $@) bytes ---"

# Compile from SRC_DIR so local headers (private.h, timelocal.h, tzfile.h) resolve.
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
