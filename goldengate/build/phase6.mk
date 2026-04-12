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
# Skipped (missing BSD headers):  reboot, shutdown (sys/sysctl.h, sys/reboot.h not in GNO tree)
# Skipped (network deps): rcp, ftp, rlogin, rsh, inetd, syslogd
# Skipped (asm-only):     date, purge, help, setvers
# getvers: built from old-gno/usr.bin/getvers/ (pure asm — already written)
# binprint: built with pure-C doline.c replacing doline.asm
# Complex (deferred):     vi, less
#

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ   ?= $(abspath $(REPO_ROOT)/gno_obj)
GG_ROOT   ?= $(or $(GOLDEN_GATE),$(ORCA_ROOT),$(HOME)/Library/GoldenGate)

BIN_SRC     := $(REPO_ROOT)/bin
USRBIN_SRC  := $(REPO_ROOT)/usr.bin
USRORCA_SRC := $(REPO_ROOT)/usr.orca.bin
SBIN_SRC    := $(REPO_ROOT)/sbin
USRSBIN_SRC := $(REPO_ROOT)/usr.sbin
GAMES_SRC   := $(REPO_ROOT)/games

BIN_OUT      := $(GNO_OBJ)/bin
USRBIN_OUT   := $(GNO_OBJ)/usr/bin
USRORCA_OUT  := $(GNO_OBJ)/usr/orca/bin
SBIN_OUT     := $(GNO_OBJ)/sbin
USRSBIN_OUT  := $(GNO_OBJ)/usr/sbin
USRGAMES_OUT := $(GNO_OBJ)/usr/games

# Temporary object directory (per-utility subdirs created here)
OBJ_BASE    := $(GNO_OBJ)/utils_obj

# ── Helper macros ─────────────────────────────────────────────────────────────

# Compile one C file from a source directory into an obj dir.
# Always cd to srcdir so local .h files resolve.
# After compile, move .a to objdir; move .root only if it exists (some
# files with #pragma noroot don't generate a .root).
# Usage: $(call cc1,srcdir,stem,objdir)
define cc1
cd $(1) && iix --gno compile -P $(2).c && mv $(2).a $(3)/ && { mv $(2).root $(3)/ 2>/dev/null || true; } && { rm -f $(2).sym 2>/dev/null || true; }
endef

# Link all objects in objdir, produce binary in outdir.
# objs = space-separated list of base names (no extension).
# Usage: $(call ld1,objdir,outdir,progname,objs[,extra_libs])
define ld1
rm -f $(2)/$(3); cd $(1) && iix --gno link -P -o $(2)/$(3) $(4) $(5)
endef

# Library paths
LIBTERMCAP  := $(GNO_OBJ)/usr/lib/libtermcap
LIBCURSES   := $(GNO_OBJ)/usr/lib/libcurses
LIBCONTRIB  := $(GNO_OBJ)/usr/lib/libcontrib
LIBCRYPT    := $(GNO_OBJ)/usr/lib/libcrypt
LIBUTIL     := $(GNO_OBJ)/usr/lib/libutil
LIBNETDB    := $(GNO_OBJ)/usr/lib/libnetdb
SYSFLOAT    := $(GG_ROOT)/Libraries/SysFloat

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
	$(foreach s,$(4), cd $(1) && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/$(3)/ && { mv $(s).root $(OBJ_BASE)/$(3)/ 2>/dev/null || true; } && { rm -f $(s).sym 2>/dev/null || true; };)
	$(call ld1,$(OBJ_BASE)/$(3),$(2),$(3),$(4))
endef

# ── Default target ─────────────────────────────────────────────────────────────

.PHONY: all bin usr_bin usr_orca_bin sbin usr_sbin usr_games gsh
all: bin usr_bin usr_orca_bin sbin usr_sbin usr_games gsh

# gsh delegates to its own Makefile (22 ORCA/M assembly modules)
gsh:
	$(MAKE) -f $(REPO_ROOT)/goldengate/build/phase6_gsh.mk REPO_ROOT=$(REPO_ROOT) GNO_OBJ=$(GNO_OBJ)

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
	bin_aroff bin_binprint bin_chmod bin_chtyp bin_cmp bin_compress bin_cp bin_date bin_df bin_echo bin_egrep bin_false bin_fgrep bin_freeze bin_grep bin_hostname bin_less bin_ls bin_more bin_mkdir bin_passwd bin_ps bin_purge bin_rm bin_rmdir bin_tail bin_test bin_tr bin_true bin_uncompress bin_vi

bin: $(BIN_SIMPLE:%=bin_%) \
	bin_aroff bin_binprint bin_chmod bin_chtyp bin_cmp bin_compress bin_cp bin_date bin_df bin_echo bin_egrep bin_false bin_fgrep bin_freeze bin_grep bin_hostname bin_less bin_ls bin_more bin_mkdir bin_passwd bin_ps bin_purge bin_rm bin_rmdir bin_tail bin_test bin_tr bin_true bin_uncompress bin_vi

$(BIN_SIMPLE:%=bin_%):
	$(call build_simple,$(BIN_SRC),$(BIN_OUT),$(@:bin_%=%))

bin_binprint:
	@echo "=== binprint ==="
	@mkdir -p $(OBJ_BASE)/binprint $(BIN_OUT)
	$(foreach s,binprint doline, \
		cd $(BIN_SRC)/binprint && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/binprint/ && { mv $(s).root $(OBJ_BASE)/binprint/ 2>/dev/null || true; } && { rm -f $(s).sym 2>/dev/null || true; };)
	cd $(OBJ_BASE)/binprint && iix --gno link -P -o $(BIN_OUT)/binprint binprint doline

# cp: single-file GNO-native utility (from ksherlock-gno-sources)
# Implements cp, rm, mv via argv[0] detection; only cp is needed here.
bin_cp:
	@echo "=== cp ==="
	@mkdir -p $(OBJ_BASE)/cp $(BIN_OUT)
	cd $(BIN_SRC)/cp && iix --gno compile -P cp.c && mv cp.a $(OBJ_BASE)/cp/ && { mv cp.root $(OBJ_BASE)/cp/ 2>/dev/null || true; } && { rm -f cp.sym 2>/dev/null || true; }
	cd $(OBJ_BASE)/cp && iix --gno link -P -o $(BIN_OUT)/cp cp

# grep/egrep/fgrep/chmod: BSD ports using POSIX regex (grep=4.3BSD Reno, egrep/fgrep=4.3BSD Reno, chmod=4.4BSD-Lite2)
bin_grep:
	$(call build_simple,$(BIN_SRC),$(BIN_OUT),grep)

bin_egrep:
	$(call build_simple,$(BIN_SRC),$(BIN_OUT),egrep)

bin_fgrep:
	$(call build_simple,$(BIN_SRC),$(BIN_OUT),fgrep)

bin_chmod:
	@echo "=== chmod ==="
	@mkdir -p $(OBJ_BASE)/chmod $(BIN_OUT)
	$(foreach s,chmod setmode, \
		cd $(BIN_SRC)/chmod && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/chmod/ && { mv $(s).root $(OBJ_BASE)/chmod/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/chmod && iix --gno link -P -o $(BIN_OUT)/chmod chmod setmode

# compress: LZW compress/decompress (single binary handles both; detect via argv[0])
bin_compress:
	@echo "=== compress ==="
	@mkdir -p $(OBJ_BASE)/compress $(BIN_OUT)
	$(call cc1,$(BIN_SRC)/compress,compress,$(OBJ_BASE)/compress)
	$(call ld1,$(OBJ_BASE)/compress,$(BIN_OUT),compress,compress)

# uncompress: tiny stub that execs compress -d
bin_uncompress:
	@echo "=== uncompress ==="
	@mkdir -p $(OBJ_BASE)/uncompress $(BIN_OUT)
	$(call cc1,$(BIN_SRC)/compress,uncompress,$(OBJ_BASE)/uncompress)
	$(call ld1,$(OBJ_BASE)/uncompress,$(BIN_OUT),uncompress,uncompress)

# freeze: LZH freeze/melt compressor (single binary; detect melt via argv[0])
bin_freeze:
	@echo "=== freeze ==="
	@mkdir -p $(OBJ_BASE)/freeze $(BIN_OUT)
	$(call cc1,$(BIN_SRC)/compress,freeze,$(OBJ_BASE)/freeze)
	$(call ld1,$(OBJ_BASE)/freeze,$(BIN_OUT),freeze,freeze)

# asm utilities: assemble in source dir, patch both .A and .ROOT, link with plain iix link


bin_date:
	@echo "=== date ==="
	@mkdir -p $(OBJ_BASE)/date $(BIN_OUT)
	cd $(BIN_SRC)/date && iix assemble +T date.asm
	iix chtyp -t obj $(BIN_SRC)/date/date.A   
	iix chtyp -t obj $(BIN_SRC)/date/date.ROOT
	mv $(BIN_SRC)/date/date.A    $(OBJ_BASE)/date/date.a
	mv $(BIN_SRC)/date/date.ROOT $(OBJ_BASE)/date/date.root.a
	cd $(OBJ_BASE)/date && iix --gno link -P -o $(BIN_OUT)/date date.root.a date.a

bin_purge:
	@echo "=== purge ==="
	@mkdir -p $(OBJ_BASE)/purge $(BIN_OUT)
	cd $(BIN_SRC)/purge && iix assemble +T purge.asm
	iix chtyp -t obj $(BIN_SRC)/purge/purge.ROOT
	mv $(BIN_SRC)/purge/purge.ROOT $(OBJ_BASE)/purge/purge.root.a
	cd $(OBJ_BASE)/purge && iix --gno link -P -o $(BIN_OUT)/purge purge.root.a

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

# mkdir: pure C implementation (mkdir2.asm startup is provided by ORCALib in GoldenGate)
bin_mkdir:
	@echo "=== mkdir ==="
	@mkdir -p $(OBJ_BASE)/mkdir $(BIN_OUT)
	$(call cc1,$(BIN_SRC)/mkdir,mkdir,$(OBJ_BASE)/mkdir)
	$(call ld1,$(OBJ_BASE)/mkdir,$(BIN_OUT),mkdir,mkdir)

# less: pager; 29 C files adapted for GNO from old-gno/bin/less/
# gsos.c is excluded (GNO libc provides getenv); lesskey.c is a separate tool
LESS_OBJS := brac ch charset cmdbuf command decode edit filename forwback \
             help ifile input jump line linenum lsystem main mark optfunc \
             option opttbl os output position prompt screen search signal \
             tags ttyin version

bin_less:
	@echo "=== less ==="
	@mkdir -p $(OBJ_BASE)/less $(BIN_OUT)
	$(foreach s,$(LESS_OBJS), \
		cd $(BIN_SRC)/less && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/less/ && { mv $(s).root $(OBJ_BASE)/less/ 2>/dev/null || true; };)
	rm -f $(BIN_OUT)/less
	cd $(OBJ_BASE)/less && iix --gno link -P -o $(BIN_OUT)/less $(LESS_OBJS) $(LIBTERMCAP)

# vi: Stevie vi editor, GNO port (Jawaid Bayzar)
# Source files with dots in the name (format.l.c, s.io.c) need explicit handling
VI_PLAIN := alloc charset cmdline dec edit fileio gsos help inc linefunc \
            main mark misccmds mk normal param regexp regsub screen search version
VI_LINK_ORDER := main.a edit.a linefunc.a cmdline.a charset.a mk.a format.l.a \
                 normal.a regexp.a regsub.a version.a misccmds.a help.a dec.a \
                 inc.a search.a alloc.a s.io.a mark.a screen.a fileio.a param.a gsos.a

bin_vi:
	@echo "=== vi ==="
	@mkdir -p $(OBJ_BASE)/vi $(BIN_OUT)
	$(foreach s,$(VI_PLAIN), \
		cd $(BIN_SRC)/vi && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/vi/ && { mv $(s).root $(OBJ_BASE)/vi/ 2>/dev/null || true; };)
	cd $(BIN_SRC)/vi && iix --gno compile -P "format.l.c" && mv "format.l.a" $(OBJ_BASE)/vi/ && { mv "format.l.root" $(OBJ_BASE)/vi/ 2>/dev/null || true; } && { rm -f "format.l.sym" 2>/dev/null || true; }
	cd $(BIN_SRC)/vi && iix --gno compile -P "s.io.c" && mv "s.io.a" $(OBJ_BASE)/vi/ && { mv "s.io.root" $(OBJ_BASE)/vi/ 2>/dev/null || true; } && { rm -f "s.io.sym" 2>/dev/null || true; }
	rm -f $(BIN_OUT)/vi
	cd $(OBJ_BASE)/vi && iix --gno link -P -o $(BIN_OUT)/vi $(VI_LINK_ORDER) $(LIBTERMCAP)

# echo: BSD echo with -n and -e; written from scratch for GNO
bin_echo:
	$(call build_simple,$(BIN_SRC),$(BIN_OUT),echo)

# hostname: gethostname/sethostname wrapper; written from scratch for GNO
bin_hostname:
	@echo "=== hostname ==="
	@mkdir -p $(OBJ_BASE)/hostname $(BIN_OUT)
	$(call cc1,$(BIN_SRC)/hostname,hostname,$(OBJ_BASE)/hostname)
	$(call ld1,$(OBJ_BASE)/hostname,$(BIN_OUT),hostname,hostname,$(GNO_OBJ)/usr/lib/libktrace)

# ps: kernel-dependent at runtime; compiles cleanly for the disk image
bin_ps:
	@echo "=== ps ==="
	@mkdir -p $(OBJ_BASE)/ps $(BIN_OUT)
	$(call cc1,$(BIN_SRC)/ps,ps,$(OBJ_BASE)/ps)
	$(call ld1,$(OBJ_BASE)/ps,$(BIN_OUT),ps,ps)

# false/true/tr: source lives in usr.bin/ but reference disk puts these in /bin/
bin_false:
	$(call build_simple,$(USRBIN_SRC),$(BIN_OUT),false)

bin_true:
	$(call build_simple,$(USRBIN_SRC),$(BIN_OUT),true)

bin_tr:
	@echo "=== tr ==="
	@mkdir -p $(OBJ_BASE)/tr $(BIN_OUT)
	$(foreach s,$(shell ls $(USRBIN_SRC)/tr/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(USRBIN_SRC)/tr && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/tr/ && { mv $(s).root $(OBJ_BASE)/tr/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/tr/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/tr && iix --gno link -P -o $(BIN_OUT)/tr $$allobjs

# ── usr.bin/ ──────────────────────────────────────────────────────────────────

USRBIN_SIMPLE := \
	alarm asa basename cal calendar catrez colcrt compile \
	cut dirname env file2c fold last launch \
	link logger lseg printenv \
	setvers tsort unshar who write

.PHONY: usr_bin $(USRBIN_SIMPLE:%=usrbin_%) \
	usrbin_asml usrbin_assemble usrbin_cmpl \
	usrbin_cksum usrbin_ctags usrbin_fmt usrbin_getvers usrbin_install usrbin_printf usrbin_sed \
	usrbin_sort usrbin_sum usrbin_tput usrbin_removerez \
	usrbin_uptime \
	usrbin_wall usrbin_whereis usrbin_whois \
	usrbin_awk usrbin_cpp usrbin_nroff usrbin_man_suite \
	usrbin_describe usrbin_udl

usr_bin: $(USRBIN_SIMPLE:%=usrbin_%) \
	usrbin_asml usrbin_assemble usrbin_cmpl \
	usrbin_cksum usrbin_ctags usrbin_fmt usrbin_getvers usrbin_install usrbin_printf usrbin_sed \
	usrbin_sort usrbin_sum usrbin_tput usrbin_removerez \
	usrbin_uptime \
	usrbin_wall usrbin_whereis usrbin_whois \
	usrbin_awk usrbin_cpp usrbin_nroff usrbin_man_suite \
	usrbin_describe usrbin_udl

$(USRBIN_SIMPLE:%=usrbin_%):
	$(call build_simple,$(USRBIN_SRC),$(USRBIN_OUT),$(@:usrbin_%=%))

# asml/assemble/cmpl: same binary as compile (same source, ORCA tool front-ends)
# The man page says they are installed by copying the compile binary.
usrbin_asml usrbin_assemble usrbin_cmpl: usrbin_compile
	@mkdir -p $(USRBIN_OUT)
	cp $(USRBIN_OUT)/compile $(USRBIN_OUT)/asml
	cp $(USRBIN_OUT)/compile $(USRBIN_OUT)/assemble
	cp $(USRBIN_OUT)/compile $(USRBIN_OUT)/cmpl

# getvers: pure 65816 assembly; reads resource forks to display version strings
# Source from old-gno/usr.bin/getvers/ — getvers.mac must be in CWD for MCOPY
usrbin_getvers:
	@echo "=== getvers ==="
	@mkdir -p $(OBJ_BASE)/getvers $(USRBIN_OUT)
	cd $(USRBIN_SRC)/getvers && iix assemble +T getvers.asm
	iix chtyp -t obj $(USRBIN_SRC)/getvers/getvers.A
	iix chtyp -t obj $(USRBIN_SRC)/getvers/getvers.ROOT
	mv $(USRBIN_SRC)/getvers/getvers.A $(OBJ_BASE)/getvers/getvers.a
	mv $(USRBIN_SRC)/getvers/getvers.ROOT $(OBJ_BASE)/getvers/getvers.root.a
	cd $(OBJ_BASE)/getvers && iix link -P -o $(USRBIN_OUT)/getvers getvers.root.a getvers.a

# printf uses floating-point format specifiers → needs SysFloat for ~DOUBLEPRECISION
usrbin_printf:
	@echo "=== printf ==="
	@mkdir -p $(OBJ_BASE)/printf $(USRBIN_OUT)
	$(call cc1,$(USRBIN_SRC)/printf,printf,$(OBJ_BASE)/printf)
	$(call ld1,$(OBJ_BASE)/printf,$(USRBIN_OUT),printf,printf,$(SYSFLOAT))

# uptime: uses %.2f for load averages → needs SysFloat
usrbin_uptime:
	@echo "=== uptime ==="
	@mkdir -p $(OBJ_BASE)/uptime $(USRBIN_OUT)
	$(call cc1,$(USRBIN_SRC)/uptime,uptime,$(OBJ_BASE)/uptime)
	$(call ld1,$(OBJ_BASE)/uptime,$(USRBIN_OUT),uptime,uptime,$(SYSFLOAT))

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
	$(foreach s,cksum crc crc32 print sum1 sum2, \
		cd $(USRBIN_SRC)/cksum && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/cksum/ && { mv $(s).root $(OBJ_BASE)/cksum/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/cksum && iix --gno link -P -o $(USRBIN_OUT)/cksum cksum crc crc32 print sum1 sum2

# sum: same objects as cksum; runtime detects argv[0] to select algorithm
usrbin_sum: usrbin_cksum
	@echo "=== sum ==="
	@mkdir -p $(USRBIN_OUT)
	cd $(OBJ_BASE)/cksum && iix --gno link -P -o $(USRBIN_OUT)/sum cksum crc crc32 print sum1 sum2

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

usrbin_wall:
	@echo "=== wall ==="
	@mkdir -p $(OBJ_BASE)/wall $(USRBIN_OUT)
	$(foreach s,$(shell ls $(USRBIN_SRC)/wall/*.c | xargs -n1 basename | sed 's/\.c//'), \
		cd $(USRBIN_SRC)/wall && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/wall/ && { mv $(s).root $(OBJ_BASE)/wall/ 2>/dev/null || true; };)
	@allobjs=$$(ls $(OBJ_BASE)/wall/*.a | xargs -n1 basename | sed 's/\.a//' | tr '\n' ' '); \
	 cd $(OBJ_BASE)/wall && iix --gno link -P -o $(USRBIN_OUT)/wall $$allobjs

# awk: pre-generated ytab.c/proctab.c included; no yacc required
usrbin_awk:
	@echo "=== awk ==="
	@mkdir -p $(OBJ_BASE)/awk $(USRBIN_OUT)
	$(foreach s,main run ytab b lib lex tran parse proctab, \
		cd $(USRBIN_SRC)/awk && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/awk/ && { mv $(s).root $(OBJ_BASE)/awk/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/awk && iix --gno link -P -o $(USRBIN_OUT)/awk main run ytab b lib lex tran parse proctab

# cpp: ORCA/C segment pragmas handled via DO_SEGMENTS define
usrbin_cpp:
	@echo "=== cpp ==="
	@mkdir -p $(OBJ_BASE)/cpp $(USRBIN_OUT)
	$(foreach s,cpp eval getopt hideset include lex macro nlist tokens unix, \
		cd $(USRBIN_SRC)/cpp && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/cpp/ && { mv $(s).root $(OBJ_BASE)/cpp/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/cpp && iix --gno link -P -o $(USRBIN_OUT)/cpp cpp eval getopt hideset include lex macro nlist tokens unix

# nroff: uses #ifdef __GNO__ for termcap/err includes; links libtermcap
usrbin_nroff:
	@echo "=== nroff ==="
	@mkdir -p $(OBJ_BASE)/nroff $(USRBIN_OUT)
	$(foreach s,nroff command escape io low macros chars strings text, \
		cd $(USRBIN_SRC)/nroff && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/nroff/ && { mv $(s).root $(OBJ_BASE)/nroff/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/nroff && iix --gno link -P -o $(USRBIN_OUT)/nroff nroff command escape io low macros chars strings text $(LIBTERMCAP)

# man suite: builds man, apropos, whatis (usr/bin) + catman, makewhatis (usr/sbin)
# All share util.o, globals.o, common.o, apropos2.o; links libcontrib
usrbin_man_suite:
	@echo "=== man suite ==="
	@mkdir -p $(OBJ_BASE)/man $(USRBIN_OUT) $(USRSBIN_OUT)
	$(foreach s,man man2 apropos apropos2 util globals common fillbuffer process catman makewhatis whatis, \
		cd $(USRBIN_SRC)/man && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/man/ && { mv $(s).root $(OBJ_BASE)/man/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/man && iix --gno link -P -o $(USRBIN_OUT)/man man man2 apropos2 util globals common $(LIBCONTRIB)
	cd $(OBJ_BASE)/man && iix --gno link -P -o $(USRBIN_OUT)/apropos apropos apropos2 util globals $(LIBCONTRIB)
	cd $(OBJ_BASE)/man && iix --gno link -P -o $(USRBIN_OUT)/whatis whatis apropos2 util globals $(LIBCONTRIB)
	cd $(OBJ_BASE)/man && iix --gno link -P -o $(USRSBIN_OUT)/catman catman util globals common $(LIBCONTRIB)
	cd $(OBJ_BASE)/man && iix --gno link -P -o $(USRSBIN_OUT)/makewhatis makewhatis fillbuffer process $(LIBCONTRIB)

# describe/descc/descu: source in usr.orca.bin/describe; reference paths are
#   describe → usr/bin/describe, descc → usr/sbin/descc, descu → usr/sbin/descu
usrbin_describe:
	@echo "=== describe/descc/descu ==="
	@mkdir -p $(OBJ_BASE)/describe $(USRBIN_OUT) $(USRSBIN_OUT)
	$(foreach s,describe descc descu, \
		cd $(USRORCA_SRC)/describe && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/describe/ && { mv $(s).root $(OBJ_BASE)/describe/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/describe && iix --gno link -P -o $(USRBIN_OUT)/describe describe
	cd $(OBJ_BASE)/describe && iix --gno link -P -o $(USRSBIN_OUT)/descc descc
	cd $(OBJ_BASE)/describe && iix --gno link -P -o $(USRSBIN_OUT)/descu descu

# udl: source in usr.orca.bin/udl; reference path is usr/bin/udl
usrbin_udl:
	@echo "=== udl ==="
	@mkdir -p $(OBJ_BASE)/udl $(USRBIN_OUT)
	$(foreach s,udlgs udluse common globals, \
		cd $(USRORCA_SRC)/udl && iix --gno compile -P $(s).c && mv $(s).a $(OBJ_BASE)/udl/ && { mv $(s).root $(OBJ_BASE)/udl/ 2>/dev/null || true; };)
	cd $(OBJ_BASE)/udl && iix --gno link -P -o $(USRBIN_OUT)/udl udlgs udluse common globals

# ── usr.orca.bin/ ─────────────────────────────────────────────────────────────
# describe and udl now build to their reference paths (usr/bin, usr/sbin) via
# usrbin_describe and usrbin_udl above. usr_orca_bin is retained as a no-op
# for backward compatibility; usr/orca/bin/occ comes from reference fallback.

.PHONY: usr_orca_bin

usr_orca_bin:

# ── sbin/ ─────────────────────────────────────────────────────────────────────

SBIN_SIMPLE := mkso renram5

# Skipped (missing BSD headers: sys/sysctl.h, sys/reboot.h, sys/resource.h):
#   reboot (sbin/reboot), shutdown (sbin/shutdown)
# initd: reconstructed from disassembly of the reference binary (sbin/init/initd.c)

.PHONY: sbin $(SBIN_SIMPLE:%=sbin_%) sbin_initd
sbin: $(SBIN_SIMPLE:%=sbin_%) sbin_initd

sbin_initd:
	@echo "=== initd ==="
	@mkdir -p $(OBJ_BASE)/initd $(SBIN_OUT) $(USRSBIN_OUT)
	cd $(SBIN_SRC)/init && iix --gno compile -P initd.c && mv initd.a $(OBJ_BASE)/initd/ && { mv initd.root $(OBJ_BASE)/initd/ 2>/dev/null || true; } && { rm -f initd.sym 2>/dev/null || true; }
	cd $(OBJ_BASE)/initd && iix --gno link -P -o $(USRSBIN_OUT)/initd initd.a $(GNO_OBJ)/usr/lib/libktrace
	cp $(USRSBIN_OUT)/initd $(SBIN_OUT)/initd

$(SBIN_SIMPLE:%=sbin_%):
	$(call build_simple,$(SBIN_SRC),$(SBIN_OUT),$(@:sbin_%=%))

# ── usr.sbin/ ─────────────────────────────────────────────────────────────────

USRSBIN_SIMPLE := cron mktmp runover uptimed

.PHONY: usr_sbin $(USRSBIN_SIMPLE:%=usrsbin_%) usrsbin_newuser usrsbin_getty \
	usrsbin_login usrsbin_nogetty

usr_sbin: $(USRSBIN_SIMPLE:%=usrsbin_%) usrsbin_newuser usrsbin_getty \
	usrsbin_login usrsbin_nogetty

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

# login: uses libutil + libcrypt; note catman/makewhatis are built via usrbin_man_suite
usrsbin_login:
	@echo "=== login ==="
	@mkdir -p $(OBJ_BASE)/login $(USRSBIN_OUT)
	$(call cc1,$(USRBIN_SRC)/login,login,$(OBJ_BASE)/login)
	$(call ld1,$(OBJ_BASE)/login,$(USRSBIN_OUT),login,login,$(LIBUTIL) $(LIBCRYPT) $(GNO_OBJ)/usr/lib/libktrace)

usrsbin_nogetty:
	@echo "=== nogetty ==="
	@mkdir -p $(OBJ_BASE)/nogetty $(USRSBIN_OUT)
	$(call cc1,$(USRSBIN_SRC)/nogetty,nogetty,$(OBJ_BASE)/nogetty)
	$(call ld1,$(OBJ_BASE)/nogetty,$(USRSBIN_OUT),nogetty,nogetty)

# ── usr.games/ ────────────────────────────────────────────────────────────────

.PHONY: usr_games usrgames_calendar usrgames_bcd usrgames_caesar usrgames_morse usrgames_pig usrgames_ppt

usr_games: usrgames_calendar usrgames_bcd usrgames_caesar usrgames_morse usrgames_pig usrgames_ppt

usrgames_calendar:
	@echo "=== calendar ==="
	@mkdir -p $(OBJ_BASE)/calendar $(USRGAMES_OUT)
	$(call cc1,$(USRBIN_SRC)/calendar,calendar,$(OBJ_BASE)/calendar)
	$(call ld1,$(OBJ_BASE)/calendar,$(USRGAMES_OUT),calendar,calendar)

usrgames_bcd:
	@echo "=== bcd ==="
	@mkdir -p $(OBJ_BASE)/bcd $(USRGAMES_OUT)
	$(call cc1,$(GAMES_SRC)/bcd,bcd,$(OBJ_BASE)/bcd)
	$(call ld1,$(OBJ_BASE)/bcd,$(USRGAMES_OUT),bcd,bcd)

usrgames_caesar:
	@echo "=== caesar ==="
	@mkdir -p $(OBJ_BASE)/caesar $(USRGAMES_OUT)
	$(call cc1,$(GAMES_SRC)/caesar,caesar,$(OBJ_BASE)/caesar)
	$(call ld1,$(OBJ_BASE)/caesar,$(USRGAMES_OUT),caesar,caesar)

usrgames_morse:
	@echo "=== morse ==="
	@mkdir -p $(OBJ_BASE)/morse $(USRGAMES_OUT)
	$(call cc1,$(GAMES_SRC)/morse,morse,$(OBJ_BASE)/morse)
	$(call ld1,$(OBJ_BASE)/morse,$(USRGAMES_OUT),morse,morse)

usrgames_pig:
	@echo "=== pig ==="
	@mkdir -p $(OBJ_BASE)/pig $(USRGAMES_OUT)
	$(call cc1,$(GAMES_SRC)/pig,pig,$(OBJ_BASE)/pig)
	$(call ld1,$(OBJ_BASE)/pig,$(USRGAMES_OUT),pig,pig)

usrgames_ppt:
	@echo "=== ppt ==="
	@mkdir -p $(OBJ_BASE)/ppt $(USRGAMES_OUT)
	$(call cc1,$(GAMES_SRC)/ppt,ppt,$(OBJ_BASE)/ppt)
	$(call ld1,$(OBJ_BASE)/ppt,$(USRGAMES_OUT),ppt,ppt)

# ── Convenience aliases (build by program name) ───────────────────────────────

$(BIN_SIMPLE): %: bin_%
aroff: bin_aroff
chtyp: bin_chtyp
cmp: bin_cmp
df: bin_df
false: bin_false
ls: bin_ls
more: bin_more
rm: bin_rm
rmdir: bin_rmdir
tail: bin_tail
test: bin_test
tr: bin_tr
true: bin_true

$(USRBIN_SIMPLE): %: usrbin_%
cksum: usrbin_cksum
ctags: usrbin_ctags
fmt: usrbin_fmt
sed: usrbin_sed
sort: usrbin_sort
sum: usrbin_sum
wall: usrbin_wall

asml: usrbin_asml
assemble: usrbin_assemble
cmpl: usrbin_cmpl
setvers: usrbin_setvers
describe: usrbin_describe
udl: usrbin_udl
mkso renram5: %: sbin_%
cron newuser: %: usrsbin_%
getty: usrsbin_getty
login: usrsbin_login
nogetty: usrsbin_nogetty
calendar: usrgames_calendar
bcd: usrgames_bcd
caesar: usrgames_caesar
morse: usrgames_morse
pig: usrgames_pig
ppt: usrgames_ppt
awk: usrbin_awk
cpp: usrbin_cpp
nroff: usrbin_nroff
man apropos whatis catman makewhatis: usrbin_man_suite
mkdir: bin_mkdir
echo: bin_echo
hostname: bin_hostname
mktmp: usrsbin_mktmp
runover: usrsbin_runover
uptimed: usrsbin_uptimed
uptime: usrbin_uptime
ps: bin_ps

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
	rm -rf $(BIN_OUT) $(USRBIN_OUT) $(USRORCA_OUT) $(SBIN_OUT) $(USRSBIN_OUT) $(USRGAMES_OUT)
	@echo "Phase 6 objects and binaries removed."
