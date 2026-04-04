#
# goldengate/build/phase6.mk
#
# Phase 6: GNO/ME utility programs (bin/, usr.bin/, usr.orca.bin/, sbin/, usr.sbin/)
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/phase6.mk           # build all utilities
#   make -f goldengate/build/phase6.mk bin        # build bin/ only
#   make -f goldengate/build/phase6.mk usr_bin    # build usr.bin/ only
#   make -f goldengate/build/phase6.mk <progname> # build one utility
#   make -f goldengate/build/phase6.mk validate   # compare sizes vs reference
#   make -f goldengate/build/phase6.mk clean      # remove all built utilities
#
# Skipped (kernel deps):  ps, init, reboot, shutdown, nogetty
# Skipped (network deps): rcp, ftp, rlogin, rsh, inetd, syslogd
# Needs getcap.c: more, tput (cgetset/cgetent/tcgetattr missing from our libtermcap)
# Skipped (asm-only):     gsh, date, purge, getvers, help, setvers
# Skipped (C+asm mixed):  binprint, mkdir  (needs separate asm compile step)
# Complex (deferred):     vi, less, awk, man, nroff, cpp
#

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/../gno-obj)

BIN_SRC     := $(REPO_ROOT)/bin
USRBIN_SRC  := $(REPO_ROOT)/usr.bin
USRORCA_SRC := $(REPO_ROOT)/usr.orca.bin
SBIN_SRC    := $(REPO_ROOT)/sbin
USRSBIN_SRC := $(REPO_ROOT)/usr.sbin

BIN_OUT     := $(GNO_OBJ)/bin
USRBIN_OUT  := $(GNO_OBJ)/usr/bin
USRORCA_OUT := $(GNO_OBJ)/usr/orca/bin
SBIN_OUT    := $(GNO_OBJ)/sbin
USRSBIN_OUT := $(GNO_OBJ)/usr/sbin

# Temporary object directory (per-utility subdirs created here)
OBJ_BASE    := $(GNO_OBJ)/utils_obj

# ── Helper macros ─────────────────────────────────────────────────────────────

# Compile one C file from a source directory into an obj dir.
# Always cd to srcdir so local .h files resolve.
# After compile, move .a to objdir; move .root only if it exists (some
# files with #pragma noroot don't generate a .root).
# Usage: $(call cc1,srcdir,stem,objdir)
define cc1
cd $(1) && iix --gno compile -P $(2).c && mv $(2).a $(3)/ && { mv $(2).root $(3)/ 2>/dev/null || true; }
endef

# Link all objects in objdir, produce binary in outdir.
# objs = space-separated list of base names (no extension).
# Usage: $(call ld1,objdir,outdir,progname,objs[,extra_libs])
define ld1
cd $(1) && iix --gno link -P -o $(2)/$(3) $(4) $(5)
endef

# Library paths
LIBTERMCAP  := $(GNO_OBJ)/usr/lib/libtermcap
LIBCURSES   := $(GNO_OBJ)/usr/lib/libcurses
LIBCONTRIB  := $(GNO_OBJ)/usr/lib/libcontrib
LIBCRYPT    := $(GNO_OBJ)/usr/lib/libcrypt
LIBUTIL     := $(GNO_OBJ)/usr/lib/libutil
LIBNETDB    := $(GNO_OBJ)/usr/lib/libnetdb
SYSFLOAT    := $(HOME)/Library/GoldenGate/Libraries/SysFloat

# Build a single-C-file utility (source file = progname.c).
# Usage: $(call build_simple,srcparent,outdir,progname)
define build_simple
	@echo "=== $(3) ==="
	@mkdir -p $(OBJ_BASE)/$(3) $(2)
	$(call cc1,$(1)/$(3),$(3),$(OBJ_BASE)/$(3))
	$(call ld1,$(OBJ_BASE)/$(3),$(2),$(3),$(3))
endef

# Build a multi-C-file utility.  objs = "main obj2 obj3 ..." (base names).
# All sources assumed to live in srcdir; local headers resolve from there.
# Usage: $(call build_multi,srcdir,outdir,progname,objs)
define build_multi
	@echo "=== $(3) ==="
	@mkdir -p $(OBJ_BASE)/$(3) $(2)
	$(foreach s,$(4), cd $(1) && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/$(3)/ && { mv $(s).root $(OBJ_BASE)/$(3)/ 2>/dev/null || true; };)
	$(call ld1,$(OBJ_BASE)/$(3),$(2),$(3),$(4))
endef

# ── Default target ─────────────────────────────────────────────────────────────

.PHONY: all bin usr_bin usr_orca_bin sbin usr_sbin
all: bin usr_bin usr_orca_bin sbin usr_sbin

# ── bin/ ──────────────────────────────────────────────────────────────────────

BIN_SIMPLE := \
	cat center du edit head kill pwd \
	sleep split strings stty tar tee time touch uname \
	uniq upper wc yes

BIN_MULTI_AROFF  := aroff printoff
BIN_MULTI_CHTYP  := chtyp chtyp_ftype
BIN_MULTI_CMP    := cmp cmp_extern cmp_special cmp_regular cmp_stdin
BIN_MULTI_DF     := df dfutil
BIN_MULTI_LS     := ls ls_extern
BIN_MULTI_RM     := rm rm_extern
BIN_MULTI_TAIL   := tail tail_extern tail_special tail_regular tail_stdin
BIN_MULTI_TEST   := test test_operator

.PHONY: bin $(BIN_SIMPLE:%=bin_%) \
	bin_aroff bin_chtyp bin_cmp bin_df bin_ls bin_more bin_passwd bin_rm bin_rmdir bin_tail bin_test

bin: $(BIN_SIMPLE:%=bin_%) \
	bin_aroff bin_chtyp bin_cmp bin_df bin_ls bin_more bin_passwd bin_rm bin_rmdir bin_tail bin_test

$(BIN_SIMPLE:%=bin_%):
	$(call build_simple,$(BIN_SRC),$(BIN_OUT),$(@:bin_%=%))

bin_passwd:
	@echo "=== passwd ==="
	@mkdir -p $(OBJ_BASE)/passwd $(BIN_OUT)
	$(call cc1,$(BIN_SRC)/passwd,passwd,$(OBJ_BASE)/passwd)
	$(call ld1,$(OBJ_BASE)/passwd,$(BIN_OUT),passwd,passwd,$(LIBCRYPT))

bin_aroff:
	@# aroff: check actual source file names
	@echo "=== aroff ==="
	@mkdir -p $(OBJ_BASE)/aroff $(BIN_OUT)
	$(foreach s,$(shell ls $(BIN_SRC)/aroff/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(BIN_SRC)/aroff && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/aroff/ && { mv $(s).root $(OBJ_BASE)/aroff/ 2>/dev/null || true; };)
	@mainobj=$$(ls $(OBJ_BASE)/aroff/*.root | head -1 | xargs basename | sed 's/\.root//'); \
	 allobjs=$$(ls $(OBJ_BASE)/aroff/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/aroff && iix --gno link -P -o $(BIN_OUT)/aroff $$allobjs

bin_chtyp:
	@echo "=== chtyp ==="
	@mkdir -p $(OBJ_BASE)/chtyp $(BIN_OUT)
	$(foreach s,$(shell ls $(BIN_SRC)/chtyp/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(BIN_SRC)/chtyp && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/chtyp/ && { mv $(s).root $(OBJ_BASE)/chtyp/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/chtyp/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/chtyp && iix --gno link -P -o $(BIN_OUT)/chtyp $$allobjs

bin_cmp:
	@echo "=== cmp ==="
	@mkdir -p $(OBJ_BASE)/cmp $(BIN_OUT)
	$(foreach s,$(shell ls $(BIN_SRC)/cmp/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(BIN_SRC)/cmp && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/cmp/ && { mv $(s).root $(OBJ_BASE)/cmp/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/cmp/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/cmp && iix --gno link -P -o $(BIN_OUT)/cmp $$allobjs

bin_df:
	@echo "=== df ==="
	@mkdir -p $(OBJ_BASE)/df $(BIN_OUT)
	$(foreach s,$(shell ls $(BIN_SRC)/df/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(BIN_SRC)/df && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/df/ && { mv $(s).root $(OBJ_BASE)/df/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/df/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/df && iix --gno link -P -o $(BIN_OUT)/df $$allobjs

bin_ls:
	@echo "=== ls ==="
	@mkdir -p $(OBJ_BASE)/ls $(BIN_OUT)
	$(foreach s,$(shell ls $(BIN_SRC)/ls/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(BIN_SRC)/ls && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/ls/ && { mv $(s).root $(OBJ_BASE)/ls/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/ls/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/ls && iix --gno link -P -o $(BIN_OUT)/ls $$allobjs

bin_rm:
	@echo "=== rm ==="
	@mkdir -p $(OBJ_BASE)/rm $(BIN_OUT)
	$(foreach s,$(shell ls $(BIN_SRC)/rm/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(BIN_SRC)/rm && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/rm/ && { mv $(s).root $(OBJ_BASE)/rm/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/rm/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/rm && iix --gno link -P -o $(BIN_OUT)/rm $$allobjs

bin_tail:
	@echo "=== tail ==="
	@mkdir -p $(OBJ_BASE)/tail $(BIN_OUT)
	$(foreach s,$(shell ls $(BIN_SRC)/tail/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(BIN_SRC)/tail && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/tail/ && { mv $(s).root $(OBJ_BASE)/tail/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/tail/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/tail && iix --gno link -P -o $(BIN_OUT)/tail $$allobjs

bin_test:
	@echo "=== test ==="
	@mkdir -p $(OBJ_BASE)/test $(BIN_OUT)
	$(foreach s,$(shell ls $(BIN_SRC)/test/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(BIN_SRC)/test && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/test/ && { mv $(s).root $(OBJ_BASE)/test/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/test/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/test && iix --gno link -P -o $(BIN_OUT)/test $$allobjs

bin_more:
	@echo "=== more ==="
	@mkdir -p $(OBJ_BASE)/more $(BIN_OUT)
	$(call cc1,$(BIN_SRC)/more,more,$(OBJ_BASE)/more)
	$(call ld1,$(OBJ_BASE)/more,$(BIN_OUT),more,more,$(LIBTERMCAP))

bin_rmdir:
	@echo "=== rmdir ==="
	@mkdir -p $(OBJ_BASE)/rmdir $(BIN_OUT)
	$(call cc1,$(BIN_SRC)/rmdir,rmdir,$(OBJ_BASE)/rmdir)
	$(call ld1,$(OBJ_BASE)/rmdir,$(BIN_OUT),rmdir,rmdir,$(LIBCONTRIB))

# ── usr.bin/ ──────────────────────────────────────────────────────────────────

USRBIN_SIMPLE := \
	alarm asa basename cal calendar catrez colcrt compile \
	cut dirname env false file2c fold last launch \
	link logger lseg printenv true \
	tsort who write

.PHONY: usr_bin $(USRBIN_SIMPLE:%=usrbin_%) \
	usrbin_cksum usrbin_ctags usrbin_fmt usrbin_install usrbin_printf usrbin_sed \
	usrbin_sort usrbin_tr usrbin_tput usrbin_removerez \
	usrbin_wall usrbin_whereis usrbin_whois

usr_bin: $(USRBIN_SIMPLE:%=usrbin_%) \
	usrbin_cksum usrbin_ctags usrbin_fmt usrbin_install usrbin_printf usrbin_sed \
	usrbin_sort usrbin_tr usrbin_tput usrbin_removerez \
	usrbin_wall usrbin_whereis usrbin_whois

$(USRBIN_SIMPLE:%=usrbin_%):
	$(call build_simple,$(USRBIN_SRC),$(USRBIN_OUT),$(@:usrbin_%=%))

# printf uses floating-point format specifiers → needs SysFloat for ~DOUBLEPRECISION
usrbin_printf:
	@echo "=== printf ==="
	@mkdir -p $(OBJ_BASE)/printf $(USRBIN_OUT)
	$(call cc1,$(USRBIN_SRC)/printf,printf,$(OBJ_BASE)/printf)
	$(call ld1,$(OBJ_BASE)/printf,$(USRBIN_OUT),printf,printf,$(SYSFLOAT))

# install source is inst.c (not install.c); uses LC_ExpandPath/LC_CopyFileGS from libcontrib
usrbin_install:
	@echo "=== install ==="
	@mkdir -p $(OBJ_BASE)/install $(USRBIN_OUT)
	$(call cc1,$(USRBIN_SRC)/install,inst,$(OBJ_BASE)/install)
	$(call ld1,$(OBJ_BASE)/install,$(USRBIN_OUT),install,inst,$(LIBCONTRIB))

usrbin_whois:
	@echo "=== whois ==="
	@mkdir -p $(OBJ_BASE)/whois $(USRBIN_OUT)
	$(call cc1,$(USRBIN_SRC)/whois,whois,$(OBJ_BASE)/whois)
	$(call ld1,$(OBJ_BASE)/whois,$(USRBIN_OUT),whois,whois,$(LIBNETDB))

usrbin_tput:
	@echo "=== tput ==="
	@mkdir -p $(OBJ_BASE)/tput $(USRBIN_OUT)
	$(call cc1,$(USRBIN_SRC)/tput,tput,$(OBJ_BASE)/tput)
	$(call ld1,$(OBJ_BASE)/tput,$(USRBIN_OUT),tput,tput,$(LIBTERMCAP))

usrbin_removerez:
	@echo "=== removerez ==="
	@mkdir -p $(OBJ_BASE)/removerez $(USRBIN_OUT)
	$(call cc1,$(USRBIN_SRC)/removerez,removerez,$(OBJ_BASE)/removerez)
	$(call ld1,$(OBJ_BASE)/removerez,$(USRBIN_OUT),removerez,removerez,$(LIBCONTRIB))

usrbin_whereis:
	@echo "=== whereis ==="
	@mkdir -p $(OBJ_BASE)/whereis $(USRBIN_OUT)
	$(call cc1,$(USRBIN_SRC)/whereis,whereis,$(OBJ_BASE)/whereis)
	$(call ld1,$(OBJ_BASE)/whereis,$(USRBIN_OUT),whereis,whereis,$(LIBCONTRIB))

usrbin_cksum:
	@echo "=== cksum ==="
	@mkdir -p $(OBJ_BASE)/cksum $(USRBIN_OUT)
	$(foreach s,$(shell ls $(USRBIN_SRC)/cksum/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(USRBIN_SRC)/cksum && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/cksum/ && { mv $(s).root $(OBJ_BASE)/cksum/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/cksum/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/cksum && iix --gno link -P -o $(USRBIN_OUT)/cksum $$allobjs

usrbin_ctags:
	@echo "=== ctags ==="
	@mkdir -p $(OBJ_BASE)/ctags $(USRBIN_OUT)
	$(foreach s,$(shell ls $(USRBIN_SRC)/ctags/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(USRBIN_SRC)/ctags && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/ctags/ && { mv $(s).root $(OBJ_BASE)/ctags/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/ctags/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/ctags && iix --gno link -P -o $(USRBIN_OUT)/ctags $$allobjs

usrbin_fmt:
	@echo "=== fmt ==="
	@mkdir -p $(OBJ_BASE)/fmt $(USRBIN_OUT)
	$(foreach s,$(shell ls $(USRBIN_SRC)/fmt/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(USRBIN_SRC)/fmt && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/fmt/ && { mv $(s).root $(OBJ_BASE)/fmt/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/fmt/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/fmt && iix --gno link -P -o $(USRBIN_OUT)/fmt $$allobjs

usrbin_sed:
	@echo "=== sed ==="
	@mkdir -p $(OBJ_BASE)/sed $(USRBIN_OUT)
	$(foreach s,$(shell ls $(USRBIN_SRC)/sed/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(USRBIN_SRC)/sed && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/sed/ && { mv $(s).root $(OBJ_BASE)/sed/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/sed/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/sed && iix --gno link -P -o $(USRBIN_OUT)/sed $$allobjs

usrbin_sort:
	@echo "=== sort (msort + dsort) ==="
	@mkdir -p $(OBJ_BASE)/sort $(USRBIN_OUT)
	$(foreach s,msort linecount loadarray sortarray disksort dsort initdisksort mergeone tempnam, \
		cd $(USRBIN_SRC)/sort && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/sort/ && { mv $(s).root $(OBJ_BASE)/sort/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/sort && iix --gno link -P -o $(USRBIN_OUT)/msort msort linecount loadarray sortarray
	cd $(OBJ_BASE)/sort && iix --gno link -P -o $(USRBIN_OUT)/dsort dsort disksort initdisksort mergeone tempnam sortarray

usrbin_tr:
	@echo "=== tr ==="
	@mkdir -p $(OBJ_BASE)/tr $(USRBIN_OUT)
	$(foreach s,$(shell ls $(USRBIN_SRC)/tr/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(USRBIN_SRC)/tr && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/tr/ && { mv $(s).root $(OBJ_BASE)/tr/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/tr/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/tr && iix --gno link -P -o $(USRBIN_OUT)/tr $$allobjs

usrbin_wall:
	@echo "=== wall ==="
	@mkdir -p $(OBJ_BASE)/wall $(USRBIN_OUT)
	$(foreach s,$(shell ls $(USRBIN_SRC)/wall/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(USRBIN_SRC)/wall && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/wall/ && { mv $(s).root $(OBJ_BASE)/wall/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/wall/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/wall && iix --gno link -P -o $(USRBIN_OUT)/wall $$allobjs

# ── usr.orca.bin/ ─────────────────────────────────────────────────────────────

USRORCA_MULTI := describe udl

.PHONY: usr_orca_bin usrorca_describe usrorca_udl

usr_orca_bin: usrorca_describe usrorca_udl

usrorca_describe:
	@echo "=== describe ==="
	@mkdir -p $(OBJ_BASE)/describe $(USRORCA_OUT)
	$(foreach s,describe descc descu, \
		cd $(USRORCA_SRC)/describe && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/describe/ && { mv $(s).root $(OBJ_BASE)/describe/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/describe && iix --gno link -P -o $(USRORCA_OUT)/describe describe
	cd $(OBJ_BASE)/describe && iix --gno link -P -o $(USRORCA_OUT)/descc descc
	cd $(OBJ_BASE)/describe && iix --gno link -P -o $(USRORCA_OUT)/descu descu

usrorca_udl:
	@echo "=== udl ==="
	@mkdir -p $(OBJ_BASE)/udl $(USRORCA_OUT)
	$(foreach s,udlgs udluse common globals, \
		cd $(USRORCA_SRC)/udl && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/udl/ && { mv $(s).root $(OBJ_BASE)/udl/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/udl && iix --gno link -P -o $(USRORCA_OUT)/udl udlgs udluse common globals

# ── sbin/ ─────────────────────────────────────────────────────────────────────

SBIN_SIMPLE := mkso renram5

.PHONY: sbin $(SBIN_SIMPLE:%=sbin_%)
sbin: $(SBIN_SIMPLE:%=sbin_%)

$(SBIN_SIMPLE:%=sbin_%):
	$(call build_simple,$(SBIN_SRC),$(SBIN_OUT),$(@:sbin_%=%))

# ── usr.sbin/ ─────────────────────────────────────────────────────────────────

USRSBIN_SIMPLE := cron

.PHONY: usr_sbin $(USRSBIN_SIMPLE:%=usrsbin_%) usrsbin_newuser usrsbin_getty

usr_sbin: $(USRSBIN_SIMPLE:%=usrsbin_%) usrsbin_newuser usrsbin_getty

$(USRSBIN_SIMPLE:%=usrsbin_%):
	$(call build_simple,$(USRSBIN_SRC),$(USRSBIN_OUT),$(@:usrsbin_%=%))

usrsbin_newuser:
	@echo "=== newuser ==="
	@mkdir -p $(OBJ_BASE)/newuser $(USRSBIN_OUT)
	$(call cc1,$(USRSBIN_SRC)/newuser,newuser,$(OBJ_BASE)/newuser)
	$(call ld1,$(OBJ_BASE)/newuser,$(USRSBIN_OUT),newuser,newuser,$(LIBCRYPT) $(LIBCONTRIB))

usrsbin_getty:
	@echo "=== getty ==="
	@mkdir -p $(OBJ_BASE)/getty $(USRSBIN_OUT)
	$(foreach s,$(shell ls $(USRSBIN_SRC)/getty/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(USRSBIN_SRC)/getty && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/getty/ && { mv $(s).root $(OBJ_BASE)/getty/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/getty/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/getty && iix --gno link -P -o $(USRSBIN_OUT)/getty $$allobjs $(LIBUTIL)

# ── Convenience aliases (build by program name) ───────────────────────────────

$(BIN_SIMPLE): %: bin_%
aroff: bin_aroff
chtyp: bin_chtyp
cmp: bin_cmp
df: bin_df
ls: bin_ls
more: bin_more
rm: bin_rm
rmdir: bin_rmdir
tail: bin_tail
test: bin_test

$(USRBIN_SIMPLE): %: usrbin_%
cksum: usrbin_cksum
ctags: usrbin_ctags
fmt: usrbin_fmt
sed: usrbin_sed
sort: usrbin_sort
tr: usrbin_tr
wall: usrbin_wall

describe udl: %: usrorca_%
mkso renram5: %: sbin_%
cron newuser: %: usrsbin_%
getty: usrsbin_getty

# ── Validate vs reference ─────────────────────────────────────────────────────

REF_BIN     := $(REPO_ROOT)/diskImages/extracted/bin
REF_USRBIN  := $(REPO_ROOT)/diskImages/extracted/usr/bin
REF_SBIN    := $(REPO_ROOT)/diskImages/extracted/sbin
REF_USRSBIN := $(REPO_ROOT)/diskImages/extracted/usr/sbin

.PHONY: validate
validate:
	@echo "=== bin/ ==="
	@for p in $(BIN_OUT)/*; do \
		name=$$(basename $$p); ref=$(REF_BIN)/$$name; \
		built=$$(wc -c < $$p 2>/dev/null || echo 0); \
		refsize=$$(wc -c < $$ref 2>/dev/null || echo "?"); \
		printf "  %-20s built:%-8s ref:%s\n" "$$name" "$$built" "$$refsize"; \
	done
	@echo "=== usr/bin/ ==="
	@for p in $(USRBIN_OUT)/*; do \
		name=$$(basename $$p); ref=$(REF_USRBIN)/$$name; \
		built=$$(wc -c < $$p 2>/dev/null || echo 0); \
		refsize=$$(wc -c < $$ref 2>/dev/null || echo "?"); \
		printf "  %-20s built:%-8s ref:%s\n" "$$name" "$$built" "$$refsize"; \
	done

# ── Clean ─────────────────────────────────────────────────────────────────────

.PHONY: clean
clean:
	rm -rf $(OBJ_BASE)
	rm -rf $(BIN_OUT) $(USRBIN_OUT) $(USRORCA_OUT) $(SBIN_OUT) $(USRSBIN_OUT)
	@echo "Phase 6 objects and binaries removed."
