#
# goldengate/build/hush.mk
#
# Build hush shell (sheumann GNO port) from bin/hush/
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/hush.mk          # build hush
#   make -f goldengate/build/hush.mk clean    # remove objects + binary
#
# Source:  bin/hush/  (https://github.com/sheumann/hush)
# Output:  gno_obj/bin/hush
#
# Compiler: ORCA/C 2.2.4 via iix --gno compile
# Pragmas: memorymodel 1, optimize 78, lint 0 (set in bin/hush/include/platform.h)
# Segments: hush.c contains its own segment "HUSH_x____" directives (lines 1124,3610,5842,7835)
# libtermcap: linked from gno_obj/usr/lib/libtermcap (built from source; getcap.c present
#   and functional — 2.0.6 "broken" issue was a missing-symbol problem in the pre-built
#   binary, not our source-built version)
#

REPO_ROOT  ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
GNO_OBJ    ?= $(abspath $(REPO_ROOT)/gno_obj)

SRC        := $(REPO_ROOT)/bin/hush
OBJ        := $(GNO_OBJ)/hush_obj
BIN_OUT    := $(GNO_OBJ)/bin
LIBTERMCAP := $(GNO_OBJ)/usr/lib/libtermcap
LIBKTRACE  := $(GNO_OBJ)/usr/lib/libktrace

# Include paths via ORCA/C iString injection (cc= parameter):
# iix's own -I flag (no .sym file) conflicts with ORCA/C's -I path flag.
# Solution: pass include dirs via cc=-I<path> which iix injects into the
# ORCA/C iString (auto-quoted as -I"path"). ORCA/C scanner processes these
# to call AddPath() before compiling each file. No header symlinks needed.
# Note: -D not supported by iix; hush_main=main and NDEBUG defined in autoconf.h
IIX_FLAGS  := -I -P
IIX_CC     := cc=-I$(SRC)/include cc=-I$(SRC)/shell cc=-I$(SRC)/libbb cc=-I$(REPO_ROOT)/lib/ktrace

# Source file lists (from Makefile.mk, GNO version — includes GNO-specific files)
SHELL_SRCS      := shell/hush.c \
                   shell/match.c \
                   shell/math.c \
                   shell/random.c \
                   shell/shell.common.c \
                   shell/glob.c \
                   shell/fnmatch.c

COREUTILS_SRCS  := coreutils/echo.c \
                   coreutils/test.c \
                   coreutils/test.ptr.hack.c

LIBBB_A_SRCS    := libbb/lineedit.c

LIBBB_B_SRCS    := libbb/appletlib.c \
                   libbb/getopt32.c \
                   libbb/error.retval.c \
                   libbb/endofname.c \
                   libbb/bb.strtonum.c \
                   libbb/full.write.c \
                   libbb/bb.qsort.c \
                   libbb/get.line.c \
                   libbb/conc.pathfile.c \
                   libbb/last.char.is.c \
                   libbb/cmp.str.array.c \
                   libbb/llist.c \
                   libbb/escape.seq.c \
                   libbb/messages.c \
                   libbb/bb.basename.c \
                   libbb/get.exec.path.c \
                   libbb/exec.gno.c

LIBBB_C_SRCS    := libbb/perror.msg.c \
                   libbb/signal.names.c \
                   libbb/safe.strncpy.c \
                   libbb/platform.c \
                   libbb/signals.c \
                   libbb/printable.str.c \
                   libbb/read.key.c \
                   libbb/safe.write.c \
                   libbb/read.c \
                   libbb/s.gethostname.c \
                   libbb/safe.poll.c \
                   libbb/parse.mode.c \
                   libbb/poll.c \
                   libbb/pgrp.c \
                   libbb/qsort.c \
                   libbb/auto.string.c

LIBBB_D_SRCS    := libbb/xfuncs.printf.c \
                   libbb/xfuncs.c \
                   libbb/xgetcwd.c \
                   libbb/xatonum.c \
                   libbb/xfunc.die.c \
                   libbb/skip.whitespc.c \
                   libbb/wfopen.c \
                   libbb/verror.msg.c \
                   libbb/time.c \
                   libbb/xrealloc.vec.c \
                   libbb/unicode.c \
                   libbb/vfork.and.run.c \
                   libbb/waitpid.emul.c

ALL_SRCS := $(SHELL_SRCS) $(COREUTILS_SRCS) $(LIBBB_A_SRCS) \
            $(LIBBB_B_SRCS) $(LIBBB_C_SRCS) $(LIBBB_D_SRCS)

# Derive .a module names (basenames without extension, for linker)
ALL_MODS := $(notdir $(ALL_SRCS:.c=))

# Batched makelib inputs (+name.a format)
LIBBB_A_MODS  := $(notdir $(LIBBB_A_SRCS:.c=))
LIBBB_B_MODS  := $(notdir $(LIBBB_B_SRCS:.c=))
LIBBB_C_MODS  := $(notdir $(LIBBB_C_SRCS:.c=))
LIBBB_D_MODS  := $(notdir $(LIBBB_D_SRCS:.c=))
SHELL_MODS    := $(notdir $(SHELL_SRCS:.c=))
COREUTILS_MODS:= $(notdir $(COREUTILS_SRCS:.c=))

.PHONY: hush clean

hush: $(BIN_OUT)/hush

$(BIN_OUT)/hush: $(OBJ)/.objs_done | $(BIN_OUT) $(OBJ)
	@echo "=== hush: linking ==="
	@# Build intermediate library from all non-hush modules (batched, <=20 per call)
	@rm -f $(OBJ)/hush_lib
	cd $(OBJ) && iix makelib hush_lib \
	    +match.a +math.a +random.a +shell.common.a +glob.a +fnmatch.a
	cd $(OBJ) && iix makelib hush_lib \
	    +echo.a +test.a +test.ptr.hack.a
	cd $(OBJ) && iix makelib hush_lib \
	    +lineedit.a
	cd $(OBJ) && iix makelib hush_lib \
	    +appletlib.a +getopt32.a +error.retval.a +endofname.a \
	    +bb.strtonum.a +full.write.a +bb.qsort.a +get.line.a \
	    +conc.pathfile.a +last.char.is.a +cmp.str.array.a +llist.a \
	    +escape.seq.a +messages.a +bb.basename.a +get.exec.path.a \
	    +exec.gno.a
	cd $(OBJ) && iix makelib hush_lib \
	    +perror.msg.a +signal.names.a +safe.strncpy.a +platform.a \
	    +signals.a +printable.str.a +read.key.a +safe.write.a \
	    +read.a +s.gethostname.a +safe.poll.a +parse.mode.a \
	    +poll.a +pgrp.a +qsort.a +auto.string.a
	cd $(OBJ) && iix makelib hush_lib \
	    +xfuncs.printf.a +xfuncs.a +xgetcwd.a +xatonum.a +xfunc.die.a \
	    +skip.whitespc.a +wfopen.a +verror.msg.a +time.a +xrealloc.vec.a \
	    +unicode.a +vfork.and.run.a +waitpid.emul.a
	@echo "=== hush: final link ==="
	cd $(OBJ) && iix --gno link -P -o $(BIN_OUT)/hush hush hush_lib $(LIBTERMCAP) $(LIBKTRACE)
	@echo "=== hush: done ===" && ls -l $(BIN_OUT)/hush

# Segment layout (each source file has segment "SEGNAME"; prepended):
#   shell/hush.c   → internal segment "HUSH_A/B/C/D____" pragmas
#   lineedit.c     → internal segment "HUSH_E____" pragma
#   SHELL_OTHER + COREUTILS → HUSH_F____ (added to each source file)
#   LIBBB_B        → HUSH_G____ (added to each source file)
#   LIBBB_C        → HUSH_H____ (added to each source file)
#   LIBBB_D        → HUSH_I____ (added to each source file)
$(OBJ)/.objs_done: | $(OBJ)
	@echo "=== hush: compiling $(words $(ALL_SRCS)) source files ==="
	$(foreach s,$(ALL_SRCS), \
	    cd $(OBJ) && iix --gno compile $(IIX_FLAGS) $(IIX_CC) $(SRC)/$(s) \
	    && echo "  OK: $(s)" || exit 1;)
	@touch $@

$(OBJ) $(BIN_OUT):
	@mkdir -p $@

clean:
	@echo "=== hush: clean ==="
	rm -rf $(OBJ)
	rm -f $(BIN_OUT)/hush
