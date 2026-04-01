#
# goldengate/orca-m-tests/Makefile
#
# ORCA/M macro test suite.
# Assembles each test file, extracts the code bytes from the OMF .ROOT output,
# and compares them against pre-recorded expected values.
#
# Usage (run from REPO_ROOT or this directory):
#   make -f goldengate/orca-m-tests/Makefile          # run all tests
#   make -f goldengate/orca-m-tests/Makefile record   # (re-)generate .expected files
#   make -f goldengate/orca-m-tests/Makefile clean    # remove generated artifacts
#
# Test naming conventions:
#   t_macro_*.asm   — positive: expect assembly success + correct bytes
#   neg_macro_*.asm — negative: expect assembly failure (non-zero exit)
#
# How byte validation works:
#   1. iix assembles foo.asm → foo.ROOT (OMF v2 object file)
#   2. tools/omf_check.py parses the OMF, extracts CONST/LCONST bytes
#   3. Extracted bytes are compared against tests/foo.expected (hex string)
#
# Running 'make record' populates the .expected files from actual output.
# Inspect the .expected files after recording to confirm correctness before
# committing them as the ground-truth.
#
# Assembly flags:
#   +T  treat all errors as terminal (stop on first)
#   +E  enable extended (Apple II) character set
#   NOTE: iix getopt_orca only accepts uppercase +[A-Z] flags.
#

REPO_ROOT  ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
TEST_DIR   := $(REPO_ROOT)/goldengate/orca-m-tests/tests
TOOLS_DIR  := $(REPO_ROOT)/goldengate/orca-m-tests/tools

AS         := iix assemble
ASFLAGS    := +T +E
CHECK      := python3 $(TOOLS_DIR)/omf_check.py

POS_TESTS  := $(sort $(notdir $(wildcard $(TEST_DIR)/t_macro_*.asm)))
NEG_TESTS  := $(sort $(notdir $(wildcard $(TEST_DIR)/neg_macro_*.asm)))

.PHONY: all record clean

# ── Run all tests ─────────────────────────────────────────────────────────────
all:
	@echo "========================================"
	@echo "ORCA/M Macro Test Suite"
	@echo "AS: $(AS) $(ASFLAGS)"
	@echo "========================================"
	@pass=0; fail=0; \
	cd $(TEST_DIR) && \
	echo "" && \
	echo "--- Positive tests (expect success + correct bytes) ---" && \
	for f in $(POS_TESTS); do \
		base=$$(basename $$f .asm); \
		aout=$$($(AS) $(ASFLAGS) $$f 2>&1); \
		rc=$$?; \
		if [ $$rc -ne 0 ]; then \
			echo "FAIL  $$f  (assembly error)"; \
			echo "$$aout" | grep -i 'error\|fatal\|terminal' | head -5 | sed 's/^/      /'; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		root=$$base.ROOT; \
		[ -f $$root ] || root=$$base.root; \
		if [ ! -f $$root ]; then \
			echo "FAIL  $$f  (no .ROOT output found)"; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		expected=$$base.expected; \
		if [ ! -f $$expected ]; then \
			echo "FAIL  $$f  (no .expected file — run 'make record' first)"; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		result=$$($(CHECK) $$root $$expected 2>&1); \
		if [ $$? -eq 0 ]; then \
			echo "PASS  $$f  $$result"; \
			pass=$$((pass + 1)); \
		else \
			echo "FAIL  $$f"; \
			echo "$$result" | sed 's/^/      /'; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo "" && \
	echo "--- Negative tests (expect assembly failure) ---" && \
	for f in $(NEG_TESTS); do \
		aout=$$($(AS) $(ASFLAGS) $$f 2>&1); \
		if [ $$? -ne 0 ]; then \
			echo "PASS  $$f  (failed as expected)"; \
			pass=$$((pass + 1)); \
		else \
			echo "FAIL  $$f  (should have failed but succeeded)"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "========================================"; \
	echo "Results: $$pass passed, $$fail failed"; \
	echo "========================================"; \
	[ $$fail -eq 0 ]

# ── Record expected output ────────────────────────────────────────────────────
# Assembles every positive test, extracts actual bytes, writes .expected files.
# Run once to bootstrap; inspect the .expected files before committing.
record:
	@echo "========================================"
	@echo "ORCA/M Macro Tests — recording expected bytes"
	@echo "========================================"
	@cd $(TEST_DIR) && \
	for f in $(POS_TESTS); do \
		base=$$(basename $$f .asm); \
		echo "  assembling $$f ..."; \
		aout=$$($(AS) $(ASFLAGS) $$f 2>&1); \
		if [ $$? -ne 0 ]; then \
			echo "  ERROR: $$f failed to assemble:"; \
			echo "$$aout" | head -5 | sed 's/^/    /'; \
			continue; \
		fi; \
		root=$$base.ROOT; \
		[ -f $$root ] || root=$$base.root; \
		if [ ! -f $$root ]; then \
			echo "  ERROR: no .ROOT for $$f"; \
			continue; \
		fi; \
		$(CHECK) --record $$root $$base.expected; \
	done; \
	echo ""; \
	echo "Done.  Inspect tests/*.expected before treating them as ground truth."

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	cd $(TEST_DIR) && rm -f *.ROOT *.root *.A *.a *.sym *.SYM
	@echo "ORCA/M test artifacts removed."
