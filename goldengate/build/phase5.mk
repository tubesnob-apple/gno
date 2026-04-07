#
# goldengate/build/phase5.mk
#
# Phase 5 — Support Libraries
#
# Builds all Phase 5 libraries in dependency order:
#   lsaneglue → libcrypt → libutil → libtermcap → libcurses → liby → netdb → libcontrib
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/phase5.mk          # build all
#   make -f goldengate/build/phase5.mk clean    # clean all
#   make -f goldengate/build/phase5.mk validate # compare sizes vs reference
#
# Reference sizes (from GNO 2.0.6 reference disk image):
#   libtermcap:  40,386 bytes   (usr/lib/libtermcap)
#   libcurses:   80,535 bytes   (usr/lib/libcurses)
#   libnetdb:    80,506 bytes   (usr/lib/libnetdb)
#   libcrypt:     7,180 bytes   (usr/lib/libcrypt)
#   libutil:      2,146 bytes   (usr/lib/libutil)
#   liby:           660 bytes   (usr/lib/liby)
#   libcontrib:  19,889 bytes   (usr/lib/libcontrib)

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
MAKE      := $(MAKE) --no-print-directory

BUILD_DIR := $(REPO_ROOT)/goldengate/build

.PHONY: all
all: lsaneglue libcrypt libsim libutil libtermcap libcurses liby netdb libcontrib

.PHONY: lsaneglue
lsaneglue:
	$(MAKE) -f $(BUILD_DIR)/lsaneglue.mk

.PHONY: libcrypt
libcrypt:
	$(MAKE) -f $(BUILD_DIR)/libcrypt.mk

.PHONY: libsim
libsim:
	$(MAKE) -f $(BUILD_DIR)/libsim.mk

.PHONY: libutil
libutil:
	$(MAKE) -f $(BUILD_DIR)/libutil.mk

.PHONY: libtermcap
libtermcap:
	$(MAKE) -f $(BUILD_DIR)/libtermcap.mk

.PHONY: libcurses
libcurses: libtermcap
	$(MAKE) -f $(BUILD_DIR)/libcurses.mk

.PHONY: liby
liby:
	$(MAKE) -f $(BUILD_DIR)/liby.mk

.PHONY: netdb
netdb:
	$(MAKE) -f $(BUILD_DIR)/netdb.mk

.PHONY: libcontrib
libcontrib:
	$(MAKE) -f $(BUILD_DIR)/libcontrib.mk

.PHONY: clean
clean:
	$(MAKE) -f $(BUILD_DIR)/lsaneglue.mk clean
	$(MAKE) -f $(BUILD_DIR)/libcrypt.mk clean
	$(MAKE) -f $(BUILD_DIR)/libsim.mk clean
	$(MAKE) -f $(BUILD_DIR)/libutil.mk clean
	$(MAKE) -f $(BUILD_DIR)/libtermcap.mk clean
	$(MAKE) -f $(BUILD_DIR)/libcurses.mk clean
	$(MAKE) -f $(BUILD_DIR)/liby.mk clean
	$(MAKE) -f $(BUILD_DIR)/netdb.mk clean
	$(MAKE) -f $(BUILD_DIR)/libcontrib.mk clean

.PHONY: validate
validate: all
	@echo ""
	@echo "=== Phase 5 Library Sizes ==="
	@REF=$(REPO_ROOT)/diskImages/extracted/usr/lib; \
	GNO_OBJ=$(abspath $(REPO_ROOT)/gno_obj/usr/lib); \
	GNO_LIB=$(abspath $(REPO_ROOT)/gno_obj/lib); \
	for lib in libcrypt libsim libutil libtermcap libcurses liby libnetdb libcontrib; do \
	  built=$$GNO_OBJ/$$lib; \
	  ref=$$REF/$$lib; \
	  if [ -f "$$built" ]; then \
	    built_sz=$$(wc -c < "$$built" | tr -d ' '); \
	  else \
	    built_sz="MISSING"; \
	  fi; \
	  if [ -f "$$ref" ]; then \
	    ref_sz=$$(wc -c < "$$ref" | tr -d ' '); \
	  else \
	    ref_sz="N/A"; \
	  fi; \
	  printf "  %-14s built: %7s  ref: %7s\n" $$lib $$built_sz $$ref_sz; \
	done; \
	if [ -f "$$GNO_LIB/lsaneglue" ]; then \
	  ls_sz=$$(wc -c < "$$GNO_LIB/lsaneglue" | tr -d ' '); \
	else \
	  ls_sz="MISSING"; \
	fi; \
	printf "  %-14s built: %7s  ref: %7s\n" lsaneglue $$ls_sz "N/A"
