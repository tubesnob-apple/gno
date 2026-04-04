#
# goldengate/build/libcurses.mk
#
# Build libcurses — curses terminal interface library for GNO.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libcurses.mk
#   make -f goldengate/build/libcurses.mk clean
#
# Output: $(LIB_OUT)
# Reference size: 80,535 bytes
#
# CFLAGS notes:
#   -D_CURSES_PRIVATE: enables internal curses definitions
#   -I$(SRC_DIR): for local curses.h
#   Compile from SRC_DIR so local headers resolve

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
LIB_OUT   ?= $(abspath $(REPO_ROOT)/../gno-obj/usr/lib/libcurses)
OBJ_DIR   ?= $(abspath $(REPO_ROOT)/../gno-obj/libcurses_obj)

SRC_DIR   := $(REPO_ROOT)/lib/libcurses

CC        := iix --gno compile
MAKELIB   := iix makelib

CCFLAGS   := -P +O

# scanw.c excluded (noted as having trouble in original Makefile)
C_SRCS := \
	addbytes.c addch.c addnstr.c box.c clear.c clrtobot.c clrtoeol.c \
	cr_put.c ctrace.c cur_hash.c curses.c delch.c deleteln.c delwin.c \
	erase.c fullname.c getch.c getstr.c id_subwins.c idlok.c initscr.c \
	insch.c insertln.c longname.c move.c mvwin.c newwin.c overlay.c \
	overwrite.c printw.c _putchar.c putchar.c refresh.c scroll.c \
	setterm.c standout.c toucholap.c touchwin.c tscroll.c tstp.c tty.c \
	unctrl.c

C_OBJS := $(patsubst %.c,$(OBJ_DIR)/%.a,$(C_SRCS))

.PHONY: all
all: $(LIB_OUT)

$(LIB_OUT): $(C_OBJS) | $(dir $(LIB_OUT))
	rm -f $(LIB_OUT)
	cd $(OBJ_DIR) && ls *.a | sort | while read f; do echo "+$$f"; done | \
	  xargs -n 20 sh -c '$(MAKELIB) $(LIB_OUT) "$$@"' _

# Compile from SRC_DIR so local curses.h resolves
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
