# syslib.mk — Build GoldenGate SysLib from byteworksinc-syslib source
#
# The GoldenGate-shipped SysLib was compiled from an older source version
# that used JSR for cross-segment calls. The current source uses JSL (correct
# for memorymodel 1 / bank-spanning programs). This Makefile rebuilds SysLib
# from the current source and installs it to GoldenGate.
#
# Usage:
#   make -f goldengate/build/syslib.mk          # build + install
#   make -f goldengate/build/syslib.mk install  # alias
#   make -f goldengate/build/syslib.mk clean

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)

SRC       := $(HOME)/source/iigs-official-repos/byteworksinc-syslib
OBJ       := $(SRC)/obj
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
INSTALL   := $(GG_ROOT)/lib/SysLib

# OMF files output by assembler (keep directive is "keep obj/<name>" but GoldenGate
# ignores subdirectory components and places output in CWD = $(SRC))
OBJS := $(SRC)/io.A $(SRC)/i2.A $(SRC)/lm.A $(SRC)/cd.A $(SRC)/mm.A $(SRC)/nl.A

.PHONY: all install clean

all: install

install: $(INSTALL)

$(INSTALL): $(OBJS)
	@echo "=== syslib: building library ==="
	@rm -f $(SRC)/SysLib
	cd $(SRC) && iix makelib SysLib +io.A
	cd $(SRC) && iix makelib SysLib +i2.A
	cd $(SRC) && iix makelib SysLib +lm.A
	cd $(SRC) && iix makelib SysLib +cd.A
	cd $(SRC) && iix makelib SysLib +mm.A
	cd $(SRC) && iix makelib SysLib +nl.A
	@echo "=== syslib: installing to $(INSTALL) ==="
	cp $(SRC)/SysLib $(INSTALL)
	@echo "=== syslib: done ==="

# Convert .macros LF→CR (ORCA/M MCOPY requires CR line endings)
# then assemble; assembler writes to obj/<name>.A via keep directive
# NOTE: The two-step read-then-write is intentional — opening 'wb' truncates
#       before reading if combined in one expression.
LFTOCR = python3 -c "import sys; d=open(sys.argv[1],'rb').read(); open(sys.argv[1],'wb').write(d.replace(b'\n',b'\r'))"

$(SRC)/io.A: $(SRC)/io.asm $(SRC)/io.macros
	@echo "=== syslib: converting io.macros LF→CR ==="
	$(LFTOCR) $(SRC)/io.macros
	@echo "=== syslib: assembling io.asm ==="
	cd $(SRC) && iix assemble +T io.asm
	iix chtyp -t obj $(SRC)/io.A

$(SRC)/i2.A: $(SRC)/i2.asm $(SRC)/i2.macros
	$(LFTOCR) $(SRC)/i2.macros
	cd $(SRC) && iix assemble +T i2.asm
	iix chtyp -t obj $(SRC)/i2.A

$(SRC)/lm.A: $(SRC)/lm.asm $(SRC)/lm.macros
	$(LFTOCR) $(SRC)/lm.macros
	cd $(SRC) && iix assemble +T lm.asm
	iix chtyp -t obj $(SRC)/lm.A

$(SRC)/cd.A: $(SRC)/cd.asm $(SRC)/cd.macros
	$(LFTOCR) $(SRC)/cd.macros
	cd $(SRC) && iix assemble +T cd.asm
	iix chtyp -t obj $(SRC)/cd.A

$(SRC)/mm.A: $(SRC)/mm.asm $(SRC)/mm.macros
	$(LFTOCR) $(SRC)/mm.macros
	cd $(SRC) && iix assemble +T mm.asm
	iix chtyp -t obj $(SRC)/mm.A

$(SRC)/nl.A: $(SRC)/nl.asm $(SRC)/nl.macros
	$(LFTOCR) $(SRC)/nl.macros
	cd $(SRC) && iix assemble +T nl.asm
	iix chtyp -t obj $(SRC)/nl.A

clean:
	rm -f $(OBJS) $(SRC)/SysLib
