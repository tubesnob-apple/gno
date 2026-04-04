#
# goldengate/build/libc_stdio.mk — Build lib/libc/stdio/ (46+ C files)
#
# Notes:
#   - Has local headers (local.h, fvwrite.h, floatio.h, glue.h) so must
#     compile from SRC_DIR and move output to OBJ_DIR.
#   - vfprintf.c is split into two compilation units via wrapper files:
#     vfprintf1.c (#define SPLIT_FILE_1 + #include "vfprintf.c")
#     vfprintf2.c (#define SPLIT_FILE_2 + #include "vfprintf.c")
#     Original workaround was cpp preprocessing (ORCA/C 2.1.1b2 crash).
#     ORCA/C 2.2.0 may not need the split, but we keep it for safety.
#
REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/../gno-obj)
SRC_DIR   := $(REPO_ROOT)/lib/libc/stdio
OBJ_DIR   := $(GNO_OBJ)/libc/stdio
LIB_OUT   := $(GNO_OBJ)/libc_stdio.a

CC        := iix --gno compile
MAKELIB   := iix makelib
CFLAGS    := -P +O
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)

# From original Makefile SRCS — note vfprintf.c is NOT compiled directly;
# vfprintf1.c and vfprintf2.c are the wrapper files.
SRC_C := \
	clrerr.c fclose.c fdopen.c feof.c ferror.c fflush.c fgetc.c \
	fgetln.c fgetpos.c fgets.c fileno.c findfp.c flags.c fopen.c \
	fprintf.c fpurge.c fputc.c fputs.c fread.c freopen.c fscanf.c \
	fseek.c fsetpos.c ftell.c funopen.c fvwrite.c fwalk.c fwrite.c \
	getc.c getchar.c gets.c getw.c makebuf.c mktemp.c perror.c printf.c \
	putc.c putchar.c puts.c putw.c refill.c remove.c rewind.c rget.c \
	scanf.c setbuf.c setbuffer.c setvbuf.c snprintf.c sprintf.c sscanf.c \
	stdio.c tempnam.c tmpfile.c tmpnam.c ungetc.c vfscanf.c \
	vprintf.c vscanf.c vsnprintf.c vsprintf.c vsscanf.c wbuf.c wsetup.c \
	vfprintf1.c vfprintf2.c

OBJ_C := $(patsubst %.c,$(OBJ_DIR)/%.a,$(SRC_C))

.PHONY: all clean
all: $(LIB_OUT)

$(LIB_OUT): $(OBJ_C) | $(GNO_OBJ)
	@echo "--- makelib libc_stdio ---"
	cd $(OBJ_DIR) && $(MAKELIB) $@ $(patsubst $(OBJ_DIR)/%.a,+%.a,$(OBJ_C))
	@echo "--- libc_stdio.a: $$(wc -c < $@) bytes ---"

# Compile from SRC_DIR so local headers (local.h etc.) resolve.
$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	@echo "--- compile $*.c ---"
	cd $(SRC_DIR) && $(CC) $(CFLAGS) $*.c
	mv $(SRC_DIR)/$*.a $@
	mv $(SRC_DIR)/$*.root $(OBJ_DIR)/$*.root 2>/dev/null || true

# vfprintf2.c: ORCA/C 2.2.0 hits an internal "compiler error" on the
# SPLIT_FILE_2 half of vfprintf.c (same bug as 2.1.1b2, just doesn't crash).
# Workaround: preprocess with macOS clang -E, strip # line directives,
# then compile the flattened result.
$(OBJ_DIR)/vfprintf2.a: $(SRC_DIR)/vfprintf.c $(SRC_DIR)/local.h $(SRC_DIR)/fvwrite.h $(SRC_DIR)/floatio.h | $(OBJ_DIR)
	@echo "--- preprocess + compile vfprintf2 ---"
	cd $(SRC_DIR) && clang -E -x c -Wno-everything \
		-D__ORCAC__ -D__appleiigs__ -D__GNO__ -DSPLIT_FILE_2 \
		-I $(GG_ROOT)/usr/include \
		-I $(GG_ROOT)/lib/ORCACDefs \
		-I . \
		vfprintf.c | sed '/^#/d' > $(OBJ_DIR)/vfprintf2_pp.c
	cd $(OBJ_DIR) && $(CC) $(CFLAGS) vfprintf2_pp.c
	mv $(OBJ_DIR)/vfprintf2_pp.a $@
	rm -f $(OBJ_DIR)/vfprintf2_pp.c $(OBJ_DIR)/vfprintf2_pp.root

$(OBJ_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
