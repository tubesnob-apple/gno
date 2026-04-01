#
# goldengate/orca-m/Makefile
#
# Build ORCA/M (Asm65816 2.1.0) from source using iix assemble + iix link,
# then compare the result against the binary already installed in GoldenGate.
#
# Usage (run from REPO_ROOT or this directory):
#   make -f goldengate/orca-m/Makefile          # build + compare
#   make -f goldengate/orca-m/Makefile build     # build only
#   make -f goldengate/orca-m/Makefile compare   # compare only (must build first)
#   make -f goldengate/orca-m/Makefile install   # replace GoldenGate binary (careful!)
#   make -f goldengate/orca-m/Makefile clean     # remove generated files
#
# Source structure (ORCA/M APPEND chain):
#   Asm.asm  → FAsmb.asm → FPas1.asm → FKeep.asm
#            → Forml.asm → FSntx.asm → FEval.asm → FMcro.asm (empty, terminal)
#   File.asm  (standalone)
#
# Each top-level file carries a KEEP directive that names the output object:
#   Asm.asm  → KEEP OBJ/ASM  → obj/asm.a  + obj/asm.root
#   File.asm → keep obj/file → obj/file.a + obj/file.root
#
# The linker writes to 16/Asm65816 which iix resolves to:
#   ~/Library/GoldenGate/Languages/Asm65816
# We redirect output to ./Asm65816 instead via -o.
#
# Assembly flags (NOTE: iix getopt_orca only accepts uppercase +[A-Z] flags):
#   +T  treat all errors as terminal (stop on first error)
#   +E  enable extended character set support
#
# ENDPROG / Z.EndP:
#   The original linkit script copies Z.EndP (an OMF library) to ORCA volume 13
#   (the library path) so the linker can resolve the ENDPROG symbol referenced
#   in FAsmb.asm: LEN EQU ENDPROG-ASM41-2
#   Under iix the library search does not pick up files dropped in lib/, so we
#   instead assemble a tiny EndProg.asm stub and include it directly in the link.
#   This produces a functionally equivalent binary; the internal ENDPROG address
#   differs from the GoldenGate-installed binary because the stub segment is
#   smaller than Z.EndP's original END.ROOT object.
#

REPO_ROOT  ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
SRC_DIR    := $(REPO_ROOT)/goldengate/orca-m
GG_ROOT    ?= $(HOME)/Library/GoldenGate
INSTALLED  := $(GG_ROOT)/Languages/Asm65816

AS         := iix assemble
LD         := iix link
ASFLAGS    := +T +E

OBJ_DIR      := $(SRC_DIR)/obj
OBJ_ASM      := $(OBJ_DIR)/asm.a
OBJ_FILE     := $(OBJ_DIR)/file.a
OBJ_ENDPROG  := $(SRC_DIR)/EndProg.ROOT
OUTPUT       := $(SRC_DIR)/Asm65816

# All files in the APPEND chain for asm.asm (dependencies for rebuild detection)
ASM_SRCS := \
	$(SRC_DIR)/Asm.asm \
	$(SRC_DIR)/Asm.mac \
	$(SRC_DIR)/DirectPage \
	$(SRC_DIR)/FAsmb.asm \
	$(SRC_DIR)/FPas1.asm \
	$(SRC_DIR)/FKeep.asm \
	$(SRC_DIR)/Forml.asm \
	$(SRC_DIR)/FSntx.asm \
	$(SRC_DIR)/FEval.asm \
	$(SRC_DIR)/FMcro.asm

FILE_SRCS := \
	$(SRC_DIR)/File.asm \
	$(SRC_DIR)/File.mac \
	$(SRC_DIR)/DirectPage

# ── Default: build then compare ───────────────────────────────────────────────
.PHONY: all build compare install clean
all: build compare

# ── Build ─────────────────────────────────────────────────────────────────────
build: $(OUTPUT)

$(OUTPUT): $(OBJ_ASM) $(OBJ_FILE) $(OBJ_ENDPROG)
	@echo "--- link Asm65816 ---"
	cd $(SRC_DIR) && $(LD) -P -o $(OUTPUT) obj/asm obj/file EndProg
	@printf '--- built: %s (%s bytes) ---\n' "$(OUTPUT)" "$$(wc -c < $(OUTPUT) | tr -d ' ')"

# Assemble the main chain.  The KEEP OBJ/ASM directive inside Asm.asm is
# supposed to write to obj/asm, but iix ignores the directory prefix and writes
# Asm.A + Asm.ROOT to the working directory.  Move them into obj/ afterward.
$(OBJ_ASM): $(ASM_SRCS) | $(OBJ_DIR)
	@echo "--- assemble Asm.asm (+ APPEND chain) ---"
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) Asm.asm
	mv $(SRC_DIR)/Asm.A   $(OBJ_DIR)/asm.a
	mv $(SRC_DIR)/Asm.ROOT $(OBJ_DIR)/asm.root

# Assemble the file I/O unit.  Same situation: File.A + File.ROOT land in the
# working directory; move them into obj/.
$(OBJ_FILE): $(FILE_SRCS) | $(OBJ_DIR)
	@echo "--- assemble File.asm ---"
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) File.asm
	mv $(SRC_DIR)/File.A   $(OBJ_DIR)/file.a
	mv $(SRC_DIR)/File.ROOT $(OBJ_DIR)/file.root

# Assemble the ENDPROG terminal stub (replaces Z.EndP library object).
# iix assembler produces EndProg.ROOT (no .A because the segment has no data).
$(OBJ_ENDPROG): $(SRC_DIR)/EndProg.asm
	@echo "--- assemble EndProg.asm ---"
	cd $(SRC_DIR) && $(AS) $(ASFLAGS) EndProg.asm

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

# ── Compare ───────────────────────────────────────────────────────────────────
# Binary diff against the installed GoldenGate Asm65816.
# Identical output = source matches what ships in GoldenGate.
# Different output = source is older/newer or was patched.
compare: $(OUTPUT)
	@echo ""
	@echo "--- comparing built vs installed ---"
	@echo "  built:     $(OUTPUT)  ($(shell wc -c < $(OUTPUT) | tr -d ' ') bytes)"
	@echo "  installed: $(INSTALLED)  ($(shell wc -c < $(INSTALLED) | tr -d ' ') bytes)"
	@if cmp -s $(OUTPUT) $(INSTALLED); then \
		echo "  RESULT: IDENTICAL — built binary matches installed Asm65816"; \
	else \
		echo "  RESULT: DIFFERENT — built binary differs from installed"; \
		echo ""; \
		echo "  First difference (cmp):"; \
		cmp $(OUTPUT) $(INSTALLED) || true; \
		echo ""; \
		echo "  Size diff: built=$(shell wc -c < $(OUTPUT) | tr -d ' ') installed=$(shell wc -c < $(INSTALLED) | tr -d ' ')"; \
	fi
	@echo ""

# ── Install ───────────────────────────────────────────────────────────────────
# Replaces the GoldenGate binary with the freshly built one.
# Back up the original first.
install: $(OUTPUT)
	@echo "--- backing up $(INSTALLED) -> $(INSTALLED).bak ---"
	cp -p $(INSTALLED) $(INSTALLED).bak
	@echo "--- installing $(OUTPUT) -> $(INSTALLED) ---"
	cp -p $(OUTPUT) $(INSTALLED)
	@echo "--- done ---"

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	rm -f $(OBJ_DIR)/asm.a   $(OBJ_DIR)/asm.root   $(OBJ_DIR)/asm.ROOT
	rm -f $(OBJ_DIR)/file.a  $(OBJ_DIR)/file.root  $(OBJ_DIR)/file.ROOT
	rm -f $(SRC_DIR)/EndProg.ROOT $(SRC_DIR)/EndProg.A
	rm -f $(OUTPUT)
	@echo "ORCA/M build artifacts removed."
