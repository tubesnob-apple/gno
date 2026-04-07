#
# goldengate/build/libc_string.mk — Build lib/libc/string/ (all C, SEGMENT=libc_str__)
#
REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/gno_obj)
SRC_DIR   := $(REPO_ROOT)/lib/libc/string
OBJ_DIR   := $(GNO_OBJ)/libc/string
LIB_OUT   := $(GNO_OBJ)/libc_string.a

CC        := iix --gno compile
MAKELIB   := iix makelib
CFLAGS    := -P +O

# From original Makefile
SRC_C := bmem.c case.c ffs.c ffsl.c fls.c flsl.c memccpy.c memmem.c \
	memrchr.c stpcpy.c stpncpy.c str.c strcasestr.c strerror.c \
	strlcat.c strlcpy.c strmode.c strndup.c strnlen.c strnstr.c \
	strsignal.c strtok.c swab.c

OBJ_C := $(patsubst %.c,$(OBJ_DIR)/%.a,$(SRC_C))

.PHONY: all clean
all: $(LIB_OUT)

$(LIB_OUT): $(OBJ_C) | $(GNO_OBJ)
	@echo "--- makelib libc_string ---"
	cd $(OBJ_DIR) && $(MAKELIB) $@ $(patsubst $(OBJ_DIR)/%.a,+%.a,$(OBJ_C))
	@echo "--- libc_string.a: $$(wc -c < $@) bytes ---"

$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	@echo "--- compile $*.c ---"
	cd $(OBJ_DIR) && $(CC) $(CFLAGS) $(SRC_DIR)/$*.c

$(OBJ_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
