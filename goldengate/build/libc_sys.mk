#
# goldengate/build/libc_sys.mk — Build lib/libc/sys/ (2 C + 1 ASM)
#
REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/gno_obj)
SRC_DIR   := $(REPO_ROOT)/lib/libc/sys
OBJ_DIR   := $(GNO_OBJ)/libc/sys
LIB_OUT   := $(GNO_OBJ)/libc_sys.a

CC        := iix --gno compile
AS        := iix assemble
MAKELIB   := iix makelib
CFLAGS    := -P +O
ASFLAGS   := +T

SRC_C   := exec.c syscall.c
SRC_ASM := trap.asm
OBJ_C   := $(patsubst %.c,$(OBJ_DIR)/%.a,$(SRC_C))
OBJ_ASM := $(patsubst %.asm,$(OBJ_DIR)/%.a,$(SRC_ASM))
OBJS    := $(OBJ_ASM) $(OBJ_C)

.PHONY: all clean
all: $(LIB_OUT)

$(LIB_OUT): $(OBJS) | $(GNO_OBJ)
	@echo "--- makelib libc_sys ---"
	cd $(OBJ_DIR) && $(MAKELIB) $@ $(patsubst $(OBJ_DIR)/%.a,+%.a,$(OBJS))
	@echo "--- libc_sys.a: $$(wc -c < $@) bytes ---"

$(OBJ_DIR)/%.a: $(SRC_DIR)/%.c | $(OBJ_DIR)
	@echo "--- compile $*.c ---"
	cd $(OBJ_DIR) && $(CC) $(CFLAGS) $(SRC_DIR)/$*.c

$(OBJ_DIR)/%.a: $(SRC_DIR)/%.asm $(SRC_DIR)/%.mac | $(OBJ_DIR)
	@echo "--- assemble $*.asm ---"
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) $*.asm
	mv $(SRC_DIR)/$*.A $@
	mv $(SRC_DIR)/$*.ROOT $(OBJ_DIR)/$*.root 2>/dev/null || true
	iix chtyp -t obj $@

$(OBJ_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR)
	rm -f $(LIB_OUT)
