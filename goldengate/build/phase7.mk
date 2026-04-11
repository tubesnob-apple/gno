#
# goldengate/build/phase7.mk
#
# Phase 7: GNO Kernel + Device Drivers
#
# Usage (run from REPO_ROOT):
#   make -k -f goldengate/build/phase7.mk          # build all (kern + drivers)
#   make    -f goldengate/build/phase7.mk kern      # kernel only
#   make    -f goldengate/build/phase7.mk drivers   # drivers only
#   make    -f goldengate/build/phase7.mk clean
#
# Output:
#   $(OBJ_BASE)/kern           — GNO kernel (ProDOS type $B3 / s16)
#   $(OBJ_BASE)/dev/null       — null device driver (type $BB / 187)
#   $(OBJ_BASE)/dev/zero       — zero device driver
#   $(OBJ_BASE)/dev/full       — full device driver
#   $(OBJ_BASE)/dev/console    — console device driver
#   $(OBJ_BASE)/dev/modem      — modem SCC serial driver (SCC-B, $E0C038)
#   $(OBJ_BASE)/dev/printer    — printer SCC serial driver (SCC-A, $E0C039)
#
# Notes:
#   - All C files compiled with iix --gno compile (GNO headers needed for
#     kernel-internal types).  Linked with iix link (standard ORCALib only —
#     the kernel IS the GNO libc, it does not consume it).
#   - KERNEL macro must be defined in each .c source; it gates #ifdef KERNEL
#     blocks in system headers and guards test stubs (tests/test*.c).
#   - Driver ASM modules linked INTO the kernel (inout/console/box/conpatch)
#     are assembled from kern/gno/ so that their mcopy/copy paths resolve
#     via the shared ../drivers/ and ../gno/inc/ relative references.
#   - Standalone driver ASM (null/zero/full/console-binary) are assembled
#     from kern/drivers/ where port.mac lives directly.

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)
OBJ_BASE  := $(abspath $(REPO_ROOT)/gno_obj)
KERN_OBJ  := $(OBJ_BASE)/kern_obj
DRV_OBJ   := $(OBJ_BASE)/drv_obj
KERN_OUT  := $(OBJ_BASE)/kern
DEV_OUT   := $(OBJ_BASE)/dev

KERN_SRC  := $(REPO_ROOT)/kern/gno
DRV_SRC   := $(REPO_ROOT)/kern/drivers

CC    := iix --gno compile
AS    := iix assemble
LD    := iix link

CFLAGS  := -P
ASFLAGS := +T

# Format: 70 <type_byte> <auxtype_lo> <auxtype_hi>  70 64 6F 73  <16 zeros>

# ── Module lists ──────────────────────────────────────────────────────────────

# C modules from kern/gno/
KERN_C_MODS := main patch sys signal sem queue data diag stat sleep net ep ports fastfile ktrace

# ASM modules from kern/gno/ (assembled from kern/gno/ dir)
KERN_ASM_MODS := kern gsos texttool shellcall tty p16 ctool resource var pipe pty select util err regexp driver

# Driver ASM modules linked into the kernel
# (source in kern/drivers/, assembled from kern/gno/ for correct relative path resolution)
KERN_DRV_MODS := inout console box conpatch

ALL_KERN_MODS := $(KERN_C_MODS) $(KERN_ASM_MODS) $(KERN_DRV_MODS)
ALL_KERN_OBJS := $(foreach m,$(ALL_KERN_MODS),$(KERN_OBJ)/$(m).a)

# ── Top-level targets ─────────────────────────────────────────────────────────

.PHONY: all kern drivers validate clean clean-kern

all: kern drivers

# ── Kernel ────────────────────────────────────────────────────────────────────

# Always clean objects before rebuilding to prevent stale binary issues.
clean-kern:
	rm -f $(KERN_OBJ)/*.a $(KERN_OBJ)/*.root $(KERN_OUT)

kern: clean-kern $(KERN_OUT)

$(KERN_OUT): $(ALL_KERN_OBJS) | $(OBJ_BASE)
	cd $(KERN_OBJ) && $(LD) -o $(KERN_OUT) $(ALL_KERN_MODS)
	iix chtyp -t s16 -a 1 $(KERN_OUT)
	@SIZE=$$(wc -c < $(KERN_OUT)); echo "kern: $$SIZE bytes (reference: 140754)"

# ── Compile C modules ─────────────────────────────────────────────────────────

# Regenerate build_time.h (always fresh — clean-kern ensures main.a is rebuilt)
$(KERN_SRC)/build_time.h:
	python3 -c "from datetime import datetime; dt=datetime.now(); print('#define BUILD_TIMESTAMP \"' + dt.strftime('%Y-%m-%d %H:%M:%S.') + f'{dt.microsecond//1000:03d}' + '\"')" > $(KERN_SRC)/build_time.h

$(KERN_OUT): $(KERN_SRC)/build_time.h $(ALL_KERN_OBJS) | $(OBJ_BASE)

$(KERN_OBJ)/%.a: $(KERN_SRC)/%.c | $(KERN_OBJ)
	cd $(KERN_SRC) && $(CC) $(CFLAGS) $<
	mv $(KERN_SRC)/$*.a $(KERN_OBJ)/
	-mv $(KERN_SRC)/$*.root $(KERN_OBJ)/ 2>/dev/null || true
	-rm -f $(KERN_SRC)/$*.sym 2>/dev/null || true

# ── Assemble kern/gno/ ASM modules ───────────────────────────────────────────

$(KERN_OBJ)/%.a: $(KERN_SRC)/%.asm | $(KERN_OBJ)
	cd $(KERN_SRC) && $(AS) $(ASFLAGS) $*.asm
	iix chtyp -t obj $(KERN_SRC)/$*.A
	mv $(KERN_SRC)/$*.A $(KERN_OBJ)/$*.a
	-mv $(KERN_SRC)/$*.ROOT $(KERN_OBJ)/$*.root 2>/dev/null || true

# ── Driver ASM modules linked into kernel (assembled from kern/gno/) ──────────

$(KERN_OBJ)/inout.a: $(DRV_SRC)/inout.asm | $(KERN_OBJ)
	cd $(KERN_SRC) && $(AS) $(ASFLAGS) $(DRV_SRC)/inout.asm
	iix chtyp -t obj $(KERN_SRC)/inout.A
	mv $(KERN_SRC)/inout.A $(KERN_OBJ)/inout.a
	-mv $(KERN_SRC)/inout.ROOT $(KERN_OBJ)/inout.root 2>/dev/null || true

$(KERN_OBJ)/console.a: $(DRV_SRC)/console.asm | $(KERN_OBJ)
	cd $(KERN_SRC) && $(AS) $(ASFLAGS) $(DRV_SRC)/console.asm
	iix chtyp -t obj $(KERN_SRC)/console.A
	mv $(KERN_SRC)/console.A $(KERN_OBJ)/console.a
	-mv $(KERN_SRC)/console.ROOT $(KERN_OBJ)/console.root 2>/dev/null || true

$(KERN_OBJ)/box.a: $(DRV_SRC)/box.asm | $(KERN_OBJ)
	cd $(KERN_SRC) && $(AS) $(ASFLAGS) $(DRV_SRC)/box.asm
	iix chtyp -t obj $(KERN_SRC)/box.A
	mv $(KERN_SRC)/box.A $(KERN_OBJ)/box.a
	-mv $(KERN_SRC)/box.ROOT $(KERN_OBJ)/box.root 2>/dev/null || true

$(KERN_OBJ)/conpatch.a: $(DRV_SRC)/conpatch.asm | $(KERN_OBJ)
	cd $(KERN_SRC) && $(AS) $(ASFLAGS) $(DRV_SRC)/conpatch.asm
	iix chtyp -t obj $(KERN_SRC)/conpatch.A
	mv $(KERN_SRC)/conpatch.A $(KERN_OBJ)/conpatch.a
	-mv $(KERN_SRC)/conpatch.ROOT $(KERN_OBJ)/conpatch.root 2>/dev/null || true

# ── Device Drivers (standalone binaries) ──────────────────────────────────────
# null, zero, full: single-module drivers
# console: four modules (console + inout + box + conpatch)
# modem/printer: single-module SCC serial drivers, linked with libsim
# All assembled from DRV_SRC dir (port.mac / msccf_full.mac live there).

LIBSIM := $(OBJ_BASE)/usr/lib/libsim

drivers: $(DEV_OUT)/null $(DEV_OUT)/zero $(DEV_OUT)/full $(DEV_OUT)/console \
         $(DEV_OUT)/modem $(DEV_OUT)/printer

# null
$(DRV_OBJ)/null.a: $(DRV_SRC)/null.asm | $(DRV_OBJ)
	cd $(DRV_SRC) && $(AS) $(ASFLAGS) null.asm
	iix chtyp -t obj $(DRV_SRC)/null.A
	mv $(DRV_SRC)/null.A $(DRV_OBJ)/null.a
	-mv $(DRV_SRC)/null.ROOT $(DRV_OBJ)/null.root 2>/dev/null || true

$(DEV_OUT)/null: $(DRV_OBJ)/null.a | $(DEV_OUT)
	cd $(DRV_OBJ) && $(LD) -o $(DEV_OUT)/null null
	iix chtyp -t dvr -a 0x7e01 $(DEV_OUT)/null

# zero
$(DRV_OBJ)/zero.a: $(DRV_SRC)/zero.asm | $(DRV_OBJ)
	cd $(DRV_SRC) && $(AS) $(ASFLAGS) zero.asm
	iix chtyp -t obj $(DRV_SRC)/zero.A
	mv $(DRV_SRC)/zero.A $(DRV_OBJ)/zero.a
	-mv $(DRV_SRC)/zero.ROOT $(DRV_OBJ)/zero.root 2>/dev/null || true

$(DEV_OUT)/zero: $(DRV_OBJ)/zero.a | $(DEV_OUT)
	cd $(DRV_OBJ) && $(LD) -o $(DEV_OUT)/zero zero
	iix chtyp -t dvr -a 0x7e01 $(DEV_OUT)/zero

# full
$(DRV_OBJ)/full.a: $(DRV_SRC)/full.asm | $(DRV_OBJ)
	cd $(DRV_SRC) && $(AS) $(ASFLAGS) full.asm
	iix chtyp -t obj $(DRV_SRC)/full.A
	mv $(DRV_SRC)/full.A $(DRV_OBJ)/full.a
	-mv $(DRV_SRC)/full.ROOT $(DRV_OBJ)/full.root 2>/dev/null || true

$(DEV_OUT)/full: $(DRV_OBJ)/full.a | $(DEV_OUT)
	cd $(DRV_OBJ) && $(LD) -o $(DEV_OUT)/full full
	iix chtyp -t dvr -a 0x7e01 $(DEV_OUT)/full

# console (four modules, assembled from DRV_SRC)
$(DRV_OBJ)/console_drv.a: $(DRV_SRC)/console.asm | $(DRV_OBJ)
	cd $(DRV_SRC) && $(AS) $(ASFLAGS) console.asm
	iix chtyp -t obj $(DRV_SRC)/console.A
	mv $(DRV_SRC)/console.A $(DRV_OBJ)/console_drv.a
	-mv $(DRV_SRC)/console.ROOT $(DRV_OBJ)/console_drv.root 2>/dev/null || true

$(DRV_OBJ)/inout_drv.a: $(DRV_SRC)/inout.asm | $(DRV_OBJ)
	cd $(DRV_SRC) && $(AS) $(ASFLAGS) inout.asm
	iix chtyp -t obj $(DRV_SRC)/inout.A
	mv $(DRV_SRC)/inout.A $(DRV_OBJ)/inout_drv.a
	-mv $(DRV_SRC)/inout.ROOT $(DRV_OBJ)/inout_drv.root 2>/dev/null || true

$(DRV_OBJ)/box_drv.a: $(DRV_SRC)/box.asm | $(DRV_OBJ)
	cd $(DRV_SRC) && $(AS) $(ASFLAGS) box.asm
	iix chtyp -t obj $(DRV_SRC)/box.A
	mv $(DRV_SRC)/box.A $(DRV_OBJ)/box_drv.a
	-mv $(DRV_SRC)/box.ROOT $(DRV_OBJ)/box_drv.root 2>/dev/null || true

$(DRV_OBJ)/conpatch_drv.a: $(DRV_SRC)/conpatch.asm | $(DRV_OBJ)
	cd $(DRV_SRC) && $(AS) $(ASFLAGS) conpatch.asm
	iix chtyp -t obj $(DRV_SRC)/conpatch.A
	mv $(DRV_SRC)/conpatch.A $(DRV_OBJ)/conpatch_drv.a
	-mv $(DRV_SRC)/conpatch.ROOT $(DRV_OBJ)/conpatch_drv.root 2>/dev/null || true

$(DEV_OUT)/console: $(DRV_OBJ)/console_drv.a $(DRV_OBJ)/inout_drv.a \
                    $(DRV_OBJ)/box_drv.a $(DRV_OBJ)/conpatch_drv.a | $(DEV_OUT)
	cd $(DRV_OBJ) && $(LD) -o $(DEV_OUT)/console \
	  console_drv inout_drv box_drv conpatch_drv
	iix chtyp -t dvr -a 0x7e01 $(DEV_OUT)/console

# modem (SCC channel B: $E0C038/$E0C03A, CtlPanBaud $12, SIM port 2)
$(DRV_OBJ)/modem.a: $(DRV_SRC)/modem.asm \
                    $(DRV_SRC)/msccf_full.mac \
                    $(DRV_SRC)/equates \
                    $(DRV_SRC)/md.equates \
                    $(DRV_SRC)/portbody.asm \
                    $(DRV_SRC)/sccf.asm \
                    $(REPO_ROOT)/kern/gno/inc/tty.inc | $(DRV_OBJ)
	cd $(DRV_SRC) && $(AS) $(ASFLAGS) modem.asm
	iix chtyp -t obj $(DRV_SRC)/modem.A
	mv $(DRV_SRC)/modem.A $(DRV_OBJ)/modem.a
	-mv $(DRV_SRC)/modem.ROOT $(DRV_OBJ)/modem.root 2>/dev/null || true

$(DEV_OUT)/modem: $(DRV_OBJ)/modem.a $(LIBSIM) | $(DEV_OUT)
	cd $(DRV_OBJ) && $(LD) -P -o $(DEV_OUT)/modem modem $(LIBSIM)
	iix chtyp -t dvr -a 0x7e01 $(DEV_OUT)/modem

# printer (SCC channel A: $E0C039/$E0C03B, CtlPanBaud $6, SIM port 1)
$(DRV_OBJ)/printer.a: $(DRV_SRC)/printer.asm \
                      $(DRV_SRC)/msccf_full.mac \
                      $(DRV_SRC)/equates \
                      $(DRV_SRC)/pr.equates \
                      $(DRV_SRC)/portbody.asm \
                      $(DRV_SRC)/sccf.asm \
                      $(REPO_ROOT)/kern/gno/inc/tty.inc | $(DRV_OBJ)
	cd $(DRV_SRC) && $(AS) $(ASFLAGS) printer.asm
	iix chtyp -t obj $(DRV_SRC)/printer.A
	mv $(DRV_SRC)/printer.A $(DRV_OBJ)/printer.a
	-mv $(DRV_SRC)/printer.ROOT $(DRV_OBJ)/printer.root 2>/dev/null || true

$(DEV_OUT)/printer: $(DRV_OBJ)/printer.a $(LIBSIM) | $(DEV_OUT)
	cd $(DRV_OBJ) && $(LD) -P -o $(DEV_OUT)/printer printer $(LIBSIM)
	iix chtyp -t dvr -a 0x7e01 $(DEV_OUT)/printer

# ── Directories ───────────────────────────────────────────────────────────────

$(KERN_OBJ) $(DRV_OBJ) $(DEV_OUT) $(OBJ_BASE):
	mkdir -p $@

# ── Size validation ───────────────────────────────────────────────────────────

validate:
	@echo "=== Phase 7 size check ==="
	@for f in kern dev/null dev/zero dev/full dev/console dev/modem dev/printer; do \
	  p=$(OBJ_BASE)/$$f; \
	  if [ -f "$$p" ]; then \
	    echo "  $$f: $$(wc -c < $$p) bytes"; \
	  else \
	    echo "  $$f: MISSING"; \
	  fi; \
	done

# ── Clean ─────────────────────────────────────────────────────────────────────

clean:
	rm -rf $(KERN_OBJ) $(DRV_OBJ)
	rm -f $(KERN_OUT) $(DEV_OUT)/null $(DEV_OUT)/zero $(DEV_OUT)/full $(DEV_OUT)/console \
	      $(DEV_OUT)/modem $(DEV_OUT)/printer
