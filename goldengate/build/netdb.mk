#
# goldengate/build/netdb.mk
#
# Build libnetdb — network database routines for GNO.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/netdb.mk
#   make -f goldengate/build/netdb.mk clean
#
# Output: $(LIB_OUT)
# Reference size: 80,506 bytes
#
# Note: writev.c is included here (BSD socket send/recv wrappers).
# protos.h is a local header — compile from SRC_DIR.

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(HOME)/Library/GoldenGate
LIB_OUT   ?= $(abspath $(REPO_ROOT)/../gno-obj/usr/lib/libnetdb)
OBJ_DIR   ?= $(abspath $(REPO_ROOT)/../gno-obj/netdb_obj)

SRC_DIR   := $(REPO_ROOT)/lib/netdb

CC        := iix --gno compile
MAKELIB   := iix makelib

CCFLAGS   := -P +O

C_SRCS := \
	rcmd.c getnetbyname.c getnetbyaddr.c getnetent.c \
	getprotoname.c getproto.c getprotoent.c \
	getservbyname.c getservbyport.c getservent.c \
	gethostnamadr.c sethostent.c \
	inet_addr.c inet_lnaof.c inet_makeaddr.c inet_netof.c \
	inet_network.c inet_ntoa.c \
	res_comp.c res_debug.c res_init.c res_mkquery.c res_query.c res_send.c \
	herror.c writev.c

# Files that trigger ORCA/C 2.2.0 internal "compiler error" — use clang -E preprocessing
# workaround: preprocess with clang, strip # line directives, compile the flattened result.
PP_SRCS := rcmd.c res_send.c
CLANG_PP := clang -E -x c -Wno-everything -D__ORCAC__ -D__appleiigs__ -D__GNO__ \
  -I $(GG_ROOT)/usr/include -I $(GG_ROOT)/lib/ORCACDefs -I $(SRC_DIR)

C_OBJS := $(patsubst %.c,$(OBJ_DIR)/%.a,$(C_SRCS))

.PHONY: all
all: $(LIB_OUT)

$(LIB_OUT): $(C_OBJS) | $(dir $(LIB_OUT))
	rm -f $(LIB_OUT)
	cd $(OBJ_DIR) && ls *.a | sort | while read f; do echo "+$$f"; done | \
	  xargs -n 20 sh -c '$(MAKELIB) $(LIB_OUT) "$$@"' _

# Preprocessed files (clang -E workaround for ORCA/C compiler bug)
$(OBJ_DIR)/rcmd.a: $(SRC_DIR)/rcmd.c | $(OBJ_DIR)
	$(CLANG_PP) $< | sed '/^#/d' > /tmp/rcmd_pp.c
	cd /tmp && iix --gno compile +O rcmd_pp.c
	mv /tmp/rcmd_pp.a $@
	rm -f /tmp/rcmd_pp.root /tmp/rcmd_pp.c

$(OBJ_DIR)/res_send.a: $(SRC_DIR)/res_send.c | $(OBJ_DIR)
	$(CLANG_PP) $< | sed '/^#/d' > /tmp/res_send_pp.c
	cd /tmp && iix --gno compile +O res_send_pp.c
	mv /tmp/res_send_pp.a $@
	rm -f /tmp/res_send_pp.root /tmp/res_send_pp.c

# Standard compile: from SRC_DIR so local protos.h resolves
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
