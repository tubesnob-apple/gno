#
# goldengate/build/libc.mk
#
# Top-level libc build — combines all 8 subdir partial archives into final libc.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/libc.mk          # build all subdirs + combine
#   make -f goldengate/build/libc.mk clean     # remove everything
#   make -f goldengate/build/libc.mk validate  # compare against 2.0.6 reference
#
# Prerequisites: ORCALib must be built first (for assert.A).
#   make -f goldengate/build/orcalib.mk
#
# Output: $(LIB_OUT) — final libc library
#
# Build order (matches NOTES/devel/doing.builds):
#   gen → gno → locale → stdio → stdlib → stdtime → string → sys → combine
#

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/../gno-obj)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
LIB_OUT   := $(GNO_OBJ)/lib/libc
BUILD     := $(REPO_ROOT)/goldengate/build

# assert.A — built from byteworksinc-orcalib (TARGET=gno) and installed to GoldenGate.
# Run: make -f byteworksinc-orcalib/goldengate/Makefile TARGET=gno install
ASSERT_OBJ := $(GG_ROOT)/lib/assert.A

# Subdirectory Makefiles
SUBDIRS := gen gno locale regex stdio stdlib stdtime string sys

# All individual object files across all subdirectories
OBJ_FILES := $(wildcard $(GNO_OBJ)/libc/gen/*.a) \
             $(wildcard $(GNO_OBJ)/libc/gno/*.a) \
             $(wildcard $(GNO_OBJ)/libc/locale/*.a) \
             $(wildcard $(GNO_OBJ)/libc/stdio/*.a) \
             $(wildcard $(GNO_OBJ)/libc/stdlib/*.a) \
             $(wildcard $(GNO_OBJ)/libc/stdtime/*.a) \
             $(wildcard $(GNO_OBJ)/libc/string/*.a) \
             $(wildcard $(GNO_OBJ)/libc/sys/*.a)

MAKELIB := iix makelib

# Reference binary for validation
REF_LIBC := $(REPO_ROOT)/diskImages/extracted/lib/libc

# ── Default target ─────────────────────────────────────────────────────────────
.PHONY: all
all: subdirs $(LIB_OUT)

# ── Build all subdirectories ───────────────────────────────────────────────────
.PHONY: subdirs
subdirs:
	$(MAKE) -f $(BUILD)/libc_gen.mk
	$(MAKE) -f $(BUILD)/libc_gno.mk
	$(MAKE) -f $(BUILD)/libc_locale.mk
	$(MAKE) -f $(BUILD)/libc_regex.mk
	$(MAKE) -f $(BUILD)/libc_stdio.mk
	$(MAKE) -f $(BUILD)/libc_stdlib.mk
	$(MAKE) -f $(BUILD)/libc_stdtime.mk
	$(MAKE) -f $(BUILD)/libc_string.mk
	$(MAKE) -f $(BUILD)/libc_sys.mk

STAGE := $(GNO_OBJ)/libc_stage

# ── Combine into final libc ───────────────────────────────────────────────────
# MakeLib has a short command-line limit (~256 chars). We stage all objects
# into one directory with short names, then add in batches of 20.
$(LIB_OUT): subdirs $(ASSERT_OBJ) | $(dir $(LIB_OUT))
	@echo "=== combining final libc ==="
	rm -f $@
	mkdir -p $(STAGE)
	@for d in gen gno locale regex stdio stdlib stdtime string sys; do \
		for f in $(GNO_OBJ)/libc/$$d/*.a; do \
			ln -sf "$$(cd "$$(dirname "$$f")" && pwd)/$$(basename "$$f")" $(STAGE)/$$(basename "$$f"); \
		done; \
	done
	ln -sf $(abspath $(ASSERT_OBJ)) $(STAGE)/assert.a
	cd $(STAGE) && ls *.a | sort | while read batch; do echo "+$$batch"; done | \
		xargs -n 20 sh -c 'iix makelib $(LIB_OUT) "$$@"' _
	rm -rf $(STAGE)
	@echo "=== libc: $$(wc -c < $@) bytes ==="

$(dir $(LIB_OUT)):
	mkdir -p $@

# ── Validate against 2.0.6 reference ──────────────────────────────────────────
.PHONY: validate
validate: $(LIB_OUT)
	@echo "Built libc:     $$(wc -c < $(LIB_OUT)) bytes"
	@echo "Reference libc: $$(wc -c < $(REF_LIBC)) bytes"

# ── Clean everything ──────────────────────────────────────────────────────────
.PHONY: clean
clean:
	@for sub in $(SUBDIRS); do \
		$(MAKE) -f $(BUILD)/libc_$$sub.mk clean; \
	done
	rm -f $(LIB_OUT)
	@echo "All libc objects and library removed."
