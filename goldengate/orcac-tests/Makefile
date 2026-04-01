#
# goldengate/orcac-tests/Makefile
#
# ORCA/C 2.2 C99/C11 feature compliance test suite.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/orcac-tests/Makefile           # test against ORCA SDK (default)
#   make -f goldengate/orcac-tests/Makefile SDK=gno   # test against GNO SDK
#   make -f goldengate/orcac-tests/Makefile clean
#
# Output: PASS/FAIL per test, summary count at the end.
# Exit code: 0 if all tests match expectations, non-zero otherwise.
#
# Test naming conventions:
#   t_*.c   — positive tests: expected to compile successfully
#   neg_*.c — negative tests: expected to FAIL compilation (unsupported features)
#   lib_*.c — stdlib compile-only tests: expected to compile successfully
#   run_*.c — runtime tests: compiled, linked, and executed; must exit 0
#
# SDK selection:
#   SDK=orca (default) — iix compile        (uses Libraries/ — standard ORCA)
#   SDK=gno            — iix --gno compile  (uses lib/       — GNO runtime)
#
# Targets:
#   make                — compile tests only (t_*, neg_*, lib_*)
#   make run-stdlib     — compile + link + run (run_*.c)
#   make all-stdlib     — both of the above
#   make clean          — remove all generated files

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
TEST_DIR  := $(REPO_ROOT)/goldengate/orcac-tests/tests

SDK       ?= orca

ifeq ($(SDK),gno)
  CC      := iix --gno compile
  SDK_TAG := [SDK=gno]
else
  CC      := iix compile
  SDK_TAG := [SDK=orca]
endif

# ORCA/C 2.2 selects C99/C11 features via #pragma in source, not CLI flags.
# -P suppresses the "Compiling..." progress line for cleaner output.
CFLAGS    := -P

# ── Test discovery ────────────────────────────────────────────────────────────
POS_TESTS := $(sort $(notdir $(wildcard $(TEST_DIR)/t_*.c)))
NEG_TESTS := $(sort $(notdir $(wildcard $(TEST_DIR)/neg_*.c)))
LIB_TESTS := $(sort $(notdir $(wildcard $(TEST_DIR)/lib_*.c)))
RUN_TESTS := $(sort $(notdir $(wildcard $(TEST_DIR)/run_*.c)))

# Linker: same SDK prefix as compiler, but 'link' instead of 'compile'
ifeq ($(SDK),gno)
  LD := iix --gno link
else
  LD := iix link
endif

# ── Phony targets ─────────────────────────────────────────────────────────────
.PHONY: all run run-stdlib all-stdlib clean

all: run

# ── Main test runner ──────────────────────────────────────────────────────────
run:
	@echo "========================================"
	@echo "ORCA/C 2.2 C99/C11 Test Suite $(SDK_TAG)"
	@echo "CC: $(CC) $(CFLAGS)"
	@echo "========================================"
	@pass=0; fail=0; \
	cd $(TEST_DIR) && \
	echo "" && \
	echo "--- Positive tests (expect compile success) ---" && \
	for f in $(POS_TESTS); do \
		out=$$($(CC) $(CFLAGS) $$f 2>&1); \
		if [ $$? -eq 0 ]; then \
			echo "PASS  $$f"; \
			pass=$$((pass + 1)); \
		else \
			echo "FAIL  $$f"; \
			echo "      $$out" | head -5; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo "" && \
	echo "--- Negative tests (expect compile failure) ---" && \
	for f in $(NEG_TESTS); do \
		out=$$($(CC) $(CFLAGS) $$f 2>&1); \
		if [ $$? -ne 0 ]; then \
			echo "PASS  $$f  (failed as expected)"; \
			pass=$$((pass + 1)); \
		else \
			echo "FAIL  $$f  (should have failed but compiled!)"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo "" && \
	echo "--- Library tests (expect compile success) ---" && \
	for f in $(LIB_TESTS); do \
		out=$$($(CC) $(CFLAGS) $$f 2>&1); \
		if [ $$? -eq 0 ]; then \
			echo "PASS  $$f"; \
			pass=$$((pass + 1)); \
		else \
			echo "FAIL  $$f"; \
			echo "      $$out" | head -5; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "========================================"; \
	echo "Results: $$pass passed, $$fail failed"; \
	echo "========================================"; \
	[ $$fail -eq 0 ]

# ── Runtime tests: compile + link + execute ───────────────────────────────────
run-stdlib:
	@echo "========================================"
	@echo "ORCA/C stdlib runtime tests $(SDK_TAG)"
	@echo "CC: $(CC) $(CFLAGS)  LD: $(LD)"
	@echo "========================================"
	@pass=0; fail=0; \
	cd $(TEST_DIR) && \
	echo "" && \
	echo "--- Runtime tests (compile + link + run) ---" && \
	for f in $(RUN_TESTS); do \
		base=$$(basename $$f .c); \
		cout=$$($(CC) $(CFLAGS) $$f 2>&1); \
		if [ $$? -ne 0 ]; then \
			echo "FAIL  $$f  (compile error)"; \
			echo "      $$cout" | head -5; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		lout=$$($(LD) -P -o $$base $$base 2>&1); \
		if [ $$? -ne 0 ]; then \
			echo "FAIL  $$f  (link error)"; \
			echo "      $$lout" | head -5; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		rout=$$(iix ./$$base 2>&1); \
		rc=$$?; \
		if [ $$rc -eq 0 ]; then \
			echo "PASS  $$f"; \
			pass=$$((pass + 1)); \
		else \
			echo "FAIL  $$f  (exit $$rc)"; \
			echo "      $$rout" | head -10; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "========================================"; \
	echo "Results: $$pass passed, $$fail failed"; \
	echo "========================================"; \
	[ $$fail -eq 0 ]

all-stdlib: run run-stdlib

# ── Verbose mode: show all compiler output ────────────────────────────────────
.PHONY: verbose
verbose:
	@echo "========================================"
	@echo "ORCA/C 2.2 C99/C11 Test Suite $(SDK_TAG) [verbose]"
	@echo "CC: $(CC) $(CFLAGS)"
	@echo "========================================"
	@pass=0; fail=0; \
	cd $(TEST_DIR) && \
	echo "" && \
	echo "--- Positive tests (expect compile success) ---" && \
	for f in $(POS_TESTS); do \
		echo ""; \
		echo ">> $$f"; \
		out=$$($(CC) $(CFLAGS) $$f 2>&1); \
		rc=$$?; \
		echo "$$out"; \
		if [ $$rc -eq 0 ]; then \
			echo "=> PASS"; \
			pass=$$((pass + 1)); \
		else \
			echo "=> FAIL (unexpected error)"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo "" && \
	echo "--- Negative tests (expect compile failure) ---" && \
	for f in $(NEG_TESTS); do \
		echo ""; \
		echo ">> $$f"; \
		out=$$($(CC) $(CFLAGS) $$f 2>&1); \
		rc=$$?; \
		echo "$$out"; \
		if [ $$rc -ne 0 ]; then \
			echo "=> PASS (failed as expected)"; \
			pass=$$((pass + 1)); \
		else \
			echo "=> FAIL (compiled but shouldn't have)"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "========================================"; \
	echo "Results: $$pass passed, $$fail failed"; \
	echo "========================================"; \
	[ $$fail -eq 0 ]

# ── Run a single named test ───────────────────────────────────────────────────
# Usage: make -f goldengate/orcac-tests/Makefile one TEST=t_bool.c
.PHONY: one
one:
	@if [ -z "$(TEST)" ]; then echo "Usage: make one TEST=t_foo.c"; exit 1; fi
	@echo "Compiling $(TEST) with: $(CC) $(CFLAGS)"
	cd $(TEST_DIR) && $(CC) $(CFLAGS) $(TEST)

# ── Clean object files produced by iix compile ────────────────────────────────
clean:
	cd $(TEST_DIR) && rm -f *.a *.root *.o *.ROOT *.A *.sym
	cd $(TEST_DIR) && rm -f $(patsubst %.c,%,$(RUN_TESTS))
	@echo "Test object and binary files removed."
