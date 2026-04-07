#
# goldengate/build/phase8_rez.mk
#
# Phase 8a: Attach resource forks to all built GNO binaries.
#
# Usage (run from REPO_ROOT):
#   make -f goldengate/build/phase8_rez.mk          # attach all resource forks
#   make -f goldengate/build/phase8_rez.mk kern      # single target by name
#   make -f goldengate/build/phase8_rez.mk validate  # dry-run verify all
#   make -f goldengate/build/phase8_rez.mk clean      # remove sentinel files
#
# How it works:
#   For each binary that has a .rez source file, cowrez.py parses the .rez and
#   writes the Apple IIgs resource fork as the com.apple.ResourceFork xattr on
#   the built binary.  A small sentinel file (<binary>.rsrc.done) is written
#   alongside the binary to allow make dependency tracking.
#
# Skipped (no built binary):
#   binprint, rcp                   — C+asm mixed / network
#   ftp, rlogin, rsh, inetd, syslogd — network daemons, not built
#   getvers, help, date, purge      — asm-only
#   init, reboot, shutdown          — missing BSD headers (sys/sysctl.h, sys/reboot.h)
#   modem, printer (drivers)        — not built in Phase 7
#   sys/sim/sim                     — GNO SIM driver, not built (kernel module)
#   rinclude/, goldengate/orca-m/   — include files / external tool

REPO_ROOT ?= $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))/../.." && pwd)
OBJ_BASE  := $(abspath $(REPO_ROOT)/gno_obj)
COWREZ    := python3 $(REPO_ROOT)/goldengate/tools/cowrez.py

# ── Helper macro ──────────────────────────────────────────────────────────────
# REZ(rezfile, binary)  →  attach resource fork; write sentinel
define REZ
	$(COWREZ) $(REPO_ROOT)/$(1) $(OBJ_BASE)/$(2) -v
	touch $(OBJ_BASE)/$(2).rsrc.done
endef

# ── Kernel + drivers ─────────────────────────────────────────────────────────

.PHONY: kern drivers
kern:    $(OBJ_BASE)/kern.rsrc.done
drivers: $(OBJ_BASE)/dev/null.rsrc.done \
         $(OBJ_BASE)/dev/zero.rsrc.done \
         $(OBJ_BASE)/dev/full.rsrc.done \
         $(OBJ_BASE)/dev/console.rsrc.done

$(OBJ_BASE)/kern.rsrc.done: $(REPO_ROOT)/kern/gno/kern.rez $(OBJ_BASE)/kern
	$(call REZ,kern/gno/kern.rez,kern)

$(OBJ_BASE)/dev/null.rsrc.done: $(REPO_ROOT)/kern/drivers/null.rez $(OBJ_BASE)/dev/null
	$(call REZ,kern/drivers/null.rez,dev/null)

$(OBJ_BASE)/dev/zero.rsrc.done: $(REPO_ROOT)/kern/drivers/zero.rez $(OBJ_BASE)/dev/zero
	$(call REZ,kern/drivers/zero.rez,dev/zero)

$(OBJ_BASE)/dev/full.rsrc.done: $(REPO_ROOT)/kern/drivers/full.rez $(OBJ_BASE)/dev/full
	$(call REZ,kern/drivers/full.rez,dev/full)

$(OBJ_BASE)/dev/console.rsrc.done: $(REPO_ROOT)/kern/drivers/console.rez $(OBJ_BASE)/dev/console
	$(call REZ,kern/drivers/console.rez,dev/console)

# ── Libraries ────────────────────────────────────────────────────────────────

.PHONY: libs
libs: $(OBJ_BASE)/lib/libc.rsrc.done \
      $(OBJ_BASE)/lib/lsaneglue.rsrc.done \
      $(OBJ_BASE)/usr/lib/libcontrib.rsrc.done \
      $(OBJ_BASE)/usr/lib/libcrypt.rsrc.done \
      $(OBJ_BASE)/usr/lib/libsim.rsrc.done \
      $(OBJ_BASE)/usr/lib/libtermcap.rsrc.done \
      $(OBJ_BASE)/usr/lib/libutil.rsrc.done \
      $(OBJ_BASE)/usr/lib/liby.rsrc.done \
      $(OBJ_BASE)/usr/lib/libnetdb.rsrc.done

$(OBJ_BASE)/lib/libc.rsrc.done: $(REPO_ROOT)/lib/libc/libc.rez $(OBJ_BASE)/lib/libc
	$(call REZ,lib/libc/libc.rez,lib/libc)

$(OBJ_BASE)/lib/lsaneglue.rsrc.done: $(REPO_ROOT)/lib/lsaneglue/lsaneglue.rez $(OBJ_BASE)/lib/lsaneglue
	$(call REZ,lib/lsaneglue/lsaneglue.rez,lib/lsaneglue)

$(OBJ_BASE)/usr/lib/libcontrib.rsrc.done: $(REPO_ROOT)/lib/libcontrib/libcontrib.rez $(OBJ_BASE)/usr/lib/libcontrib
	$(call REZ,lib/libcontrib/libcontrib.rez,usr/lib/libcontrib)

$(OBJ_BASE)/usr/lib/libcrypt.rsrc.done: $(REPO_ROOT)/lib/libcrypt/libcrypt.rez $(OBJ_BASE)/usr/lib/libcrypt
	$(call REZ,lib/libcrypt/libcrypt.rez,usr/lib/libcrypt)

$(OBJ_BASE)/usr/lib/libsim.rsrc.done: $(REPO_ROOT)/lib/libsim/simlib.rez $(OBJ_BASE)/usr/lib/libsim
	$(call REZ,lib/libsim/simlib.rez,usr/lib/libsim)

$(OBJ_BASE)/usr/lib/libtermcap.rsrc.done: $(REPO_ROOT)/lib/libtermcap/libtermcap.rez $(OBJ_BASE)/usr/lib/libtermcap
	$(call REZ,lib/libtermcap/libtermcap.rez,usr/lib/libtermcap)

$(OBJ_BASE)/usr/lib/libutil.rsrc.done: $(REPO_ROOT)/lib/libutil/libutil.rez $(OBJ_BASE)/usr/lib/libutil
	$(call REZ,lib/libutil/libutil.rez,usr/lib/libutil)

$(OBJ_BASE)/usr/lib/liby.rsrc.done: $(REPO_ROOT)/lib/liby/liby.rez $(OBJ_BASE)/usr/lib/liby
	$(call REZ,lib/liby/liby.rez,usr/lib/liby)

$(OBJ_BASE)/usr/lib/libnetdb.rsrc.done: $(REPO_ROOT)/lib/netdb/libnetdb.rez $(OBJ_BASE)/usr/lib/libnetdb
	$(call REZ,lib/netdb/libnetdb.rez,usr/lib/libnetdb)

# ── bin/ ─────────────────────────────────────────────────────────────────────

.PHONY: bin
bin: $(OBJ_BASE)/bin/gsh.rsrc.done \
     $(OBJ_BASE)/bin/aroff.rsrc.done \
     $(OBJ_BASE)/bin/cat.rsrc.done \
     $(OBJ_BASE)/bin/compress.rsrc.done \
     $(OBJ_BASE)/bin/freeze.rsrc.done \
     $(OBJ_BASE)/bin/uncompress.rsrc.done \
     $(OBJ_BASE)/bin/center.rsrc.done \
     $(OBJ_BASE)/bin/chtyp.rsrc.done \
     $(OBJ_BASE)/bin/cmp.rsrc.done \
     $(OBJ_BASE)/bin/df.rsrc.done \
     $(OBJ_BASE)/bin/head.rsrc.done \
     $(OBJ_BASE)/bin/kill.rsrc.done \
     $(OBJ_BASE)/bin/ls.rsrc.done \
     $(OBJ_BASE)/bin/more.rsrc.done \
     $(OBJ_BASE)/bin/pwd.rsrc.done \
     $(OBJ_BASE)/bin/rm.rsrc.done \
     $(OBJ_BASE)/bin/rmdir.rsrc.done \
     $(OBJ_BASE)/bin/sleep.rsrc.done \
     $(OBJ_BASE)/bin/split.rsrc.done \
     $(OBJ_BASE)/bin/strings.rsrc.done \
     $(OBJ_BASE)/bin/stty.rsrc.done \
     $(OBJ_BASE)/bin/tail.rsrc.done \
     $(OBJ_BASE)/bin/tee.rsrc.done \
     $(OBJ_BASE)/bin/test.rsrc.done \
     $(OBJ_BASE)/bin/uname.rsrc.done \
     $(OBJ_BASE)/bin/uniq.rsrc.done \
     $(OBJ_BASE)/bin/false.rsrc.done \
     $(OBJ_BASE)/bin/tr.rsrc.done \
     $(OBJ_BASE)/bin/true.rsrc.done \
     $(OBJ_BASE)/bin/wc.rsrc.done \
     $(OBJ_BASE)/bin/yes.rsrc.done \
     $(OBJ_BASE)/bin/vi.rsrc.done

$(OBJ_BASE)/bin/gsh.rsrc.done:     $(REPO_ROOT)/bin/gsh/gsh.rez       $(OBJ_BASE)/bin/gsh
	$(call REZ,bin/gsh/gsh.rez,bin/gsh)
$(OBJ_BASE)/bin/aroff.rsrc.done:   $(REPO_ROOT)/bin/aroff/aroff.rez   $(OBJ_BASE)/bin/aroff
	$(call REZ,bin/aroff/aroff.rez,bin/aroff)
$(OBJ_BASE)/bin/cat.rsrc.done:     $(REPO_ROOT)/bin/cat/cat.rez        $(OBJ_BASE)/bin/cat
	$(call REZ,bin/cat/cat.rez,bin/cat)
$(OBJ_BASE)/bin/compress.rsrc.done:  $(REPO_ROOT)/bin/compress/compress.rez   $(OBJ_BASE)/bin/compress
	$(call REZ,bin/compress/compress.rez,bin/compress)
$(OBJ_BASE)/bin/freeze.rsrc.done:    $(REPO_ROOT)/bin/compress/freeze.rez     $(OBJ_BASE)/bin/freeze
	$(call REZ,bin/compress/freeze.rez,bin/freeze)
$(OBJ_BASE)/bin/uncompress.rsrc.done: $(REPO_ROOT)/bin/compress/uncompress.rez $(OBJ_BASE)/bin/uncompress
	$(call REZ,bin/compress/uncompress.rez,bin/uncompress)
$(OBJ_BASE)/bin/center.rsrc.done:  $(REPO_ROOT)/bin/center/center.rez  $(OBJ_BASE)/bin/center
	$(call REZ,bin/center/center.rez,bin/center)
$(OBJ_BASE)/bin/chtyp.rsrc.done:   $(REPO_ROOT)/bin/chtyp/chtyp.rez   $(OBJ_BASE)/bin/chtyp
	$(call REZ,bin/chtyp/chtyp.rez,bin/chtyp)
$(OBJ_BASE)/bin/cmp.rsrc.done:     $(REPO_ROOT)/bin/cmp/cmp.rez        $(OBJ_BASE)/bin/cmp
	$(call REZ,bin/cmp/cmp.rez,bin/cmp)
$(OBJ_BASE)/bin/df.rsrc.done:      $(REPO_ROOT)/bin/df/df.rez          $(OBJ_BASE)/bin/df
	$(call REZ,bin/df/df.rez,bin/df)
$(OBJ_BASE)/bin/head.rsrc.done:    $(REPO_ROOT)/bin/head/head.rez      $(OBJ_BASE)/bin/head
	$(call REZ,bin/head/head.rez,bin/head)
$(OBJ_BASE)/bin/kill.rsrc.done:    $(REPO_ROOT)/bin/kill/kill.rez      $(OBJ_BASE)/bin/kill
	$(call REZ,bin/kill/kill.rez,bin/kill)
$(OBJ_BASE)/bin/ls.rsrc.done:      $(REPO_ROOT)/bin/ls/ls.rez          $(OBJ_BASE)/bin/ls
	$(call REZ,bin/ls/ls.rez,bin/ls)
$(OBJ_BASE)/bin/more.rsrc.done:    $(REPO_ROOT)/bin/more/more.rez      $(OBJ_BASE)/bin/more
	$(call REZ,bin/more/more.rez,bin/more)
$(OBJ_BASE)/bin/pwd.rsrc.done:     $(REPO_ROOT)/bin/pwd/pwd.rez        $(OBJ_BASE)/bin/pwd
	$(call REZ,bin/pwd/pwd.rez,bin/pwd)
$(OBJ_BASE)/bin/rm.rsrc.done:      $(REPO_ROOT)/bin/rm/rm.rez          $(OBJ_BASE)/bin/rm
	$(call REZ,bin/rm/rm.rez,bin/rm)
$(OBJ_BASE)/bin/rmdir.rsrc.done:   $(REPO_ROOT)/bin/rmdir/rmdir.rez   $(OBJ_BASE)/bin/rmdir
	$(call REZ,bin/rmdir/rmdir.rez,bin/rmdir)
$(OBJ_BASE)/bin/sleep.rsrc.done:   $(REPO_ROOT)/bin/sleep/sleep.rez   $(OBJ_BASE)/bin/sleep
	$(call REZ,bin/sleep/sleep.rez,bin/sleep)
$(OBJ_BASE)/bin/split.rsrc.done:   $(REPO_ROOT)/bin/split/split.rez   $(OBJ_BASE)/bin/split
	$(call REZ,bin/split/split.rez,bin/split)
$(OBJ_BASE)/bin/strings.rsrc.done: $(REPO_ROOT)/bin/strings/strings.rez $(OBJ_BASE)/bin/strings
	$(call REZ,bin/strings/strings.rez,bin/strings)
$(OBJ_BASE)/bin/stty.rsrc.done:    $(REPO_ROOT)/bin/stty/stty.rez     $(OBJ_BASE)/bin/stty
	$(call REZ,bin/stty/stty.rez,bin/stty)
$(OBJ_BASE)/bin/tail.rsrc.done:    $(REPO_ROOT)/bin/tail/tail.rez     $(OBJ_BASE)/bin/tail
	$(call REZ,bin/tail/tail.rez,bin/tail)
$(OBJ_BASE)/bin/tee.rsrc.done:     $(REPO_ROOT)/bin/tee/tee.rez       $(OBJ_BASE)/bin/tee
	$(call REZ,bin/tee/tee.rez,bin/tee)
$(OBJ_BASE)/bin/test.rsrc.done:    $(REPO_ROOT)/bin/test/test.rez     $(OBJ_BASE)/bin/test
	$(call REZ,bin/test/test.rez,bin/test)
$(OBJ_BASE)/bin/uname.rsrc.done:   $(REPO_ROOT)/bin/uname/uname.rez   $(OBJ_BASE)/bin/uname
	$(call REZ,bin/uname/uname.rez,bin/uname)
$(OBJ_BASE)/bin/uniq.rsrc.done:    $(REPO_ROOT)/bin/uniq/uniq.rez     $(OBJ_BASE)/bin/uniq
	$(call REZ,bin/uniq/uniq.rez,bin/uniq)
$(OBJ_BASE)/bin/wc.rsrc.done:      $(REPO_ROOT)/bin/wc/wc.rez         $(OBJ_BASE)/bin/wc
	$(call REZ,bin/wc/wc.rez,bin/wc)
$(OBJ_BASE)/bin/false.rsrc.done:   $(REPO_ROOT)/usr.bin/false/false.rez $(OBJ_BASE)/bin/false
	$(call REZ,usr.bin/false/false.rez,bin/false)
$(OBJ_BASE)/bin/tr.rsrc.done:      $(REPO_ROOT)/usr.bin/tr/tr.rez       $(OBJ_BASE)/bin/tr
	$(call REZ,usr.bin/tr/tr.rez,bin/tr)
$(OBJ_BASE)/bin/true.rsrc.done:    $(REPO_ROOT)/usr.bin/true/true.rez   $(OBJ_BASE)/bin/true
	$(call REZ,usr.bin/true/true.rez,bin/true)
$(OBJ_BASE)/bin/yes.rsrc.done:     $(REPO_ROOT)/bin/yes/yes.rez       $(OBJ_BASE)/bin/yes
	$(call REZ,bin/yes/yes.rez,bin/yes)
$(OBJ_BASE)/bin/vi.rsrc.done:      $(REPO_ROOT)/bin/vi/vi.rez          $(OBJ_BASE)/bin/vi
	$(call REZ,bin/vi/vi.rez,bin/vi)

# ── sbin/ ────────────────────────────────────────────────────────────────────

.PHONY: sbin
sbin: $(OBJ_BASE)/sbin/mkso.rsrc.done \
      $(OBJ_BASE)/sbin/renram5.rsrc.done

$(OBJ_BASE)/sbin/mkso.rsrc.done:    $(REPO_ROOT)/sbin/mkso/mkso.rez       $(OBJ_BASE)/sbin/mkso
	$(call REZ,sbin/mkso/mkso.rez,sbin/mkso)
$(OBJ_BASE)/sbin/renram5.rsrc.done: $(REPO_ROOT)/sbin/renram5/renram5.rez $(OBJ_BASE)/sbin/renram5
	$(call REZ,sbin/renram5/renram5.rez,sbin/renram5)

# ── usr/bin/ ─────────────────────────────────────────────────────────────────

.PHONY: usr_bin
usr_bin: \
     $(OBJ_BASE)/usr/bin/apropos.rsrc.done \
     $(OBJ_BASE)/usr/bin/awk.rsrc.done \
     $(OBJ_BASE)/usr/bin/basename.rsrc.done \
     $(OBJ_BASE)/usr/bin/calendar.rsrc.done \
     $(OBJ_BASE)/usr/bin/catrez.rsrc.done \
     $(OBJ_BASE)/usr/bin/cksum.rsrc.done \
     $(OBJ_BASE)/usr/bin/colcrt.rsrc.done \
     $(OBJ_BASE)/usr/bin/compile.rsrc.done \
     $(OBJ_BASE)/usr/bin/cpp.rsrc.done \
     $(OBJ_BASE)/usr/bin/ctags.rsrc.done \
     $(OBJ_BASE)/usr/bin/cut.rsrc.done \
     $(OBJ_BASE)/usr/bin/describe.rsrc.done \
     $(OBJ_BASE)/usr/bin/dirname.rsrc.done \
     $(OBJ_BASE)/usr/bin/env.rsrc.done \
     $(OBJ_BASE)/usr/bin/fmt.rsrc.done \
     $(OBJ_BASE)/usr/bin/install.rsrc.done \
     $(OBJ_BASE)/usr/bin/last.rsrc.done \
     $(OBJ_BASE)/usr/bin/link.rsrc.done \
     $(OBJ_BASE)/usr/bin/logger.rsrc.done \
     $(OBJ_BASE)/usr/bin/lseg.rsrc.done \
     $(OBJ_BASE)/usr/bin/man.rsrc.done \
     $(OBJ_BASE)/usr/bin/nroff.rsrc.done \
     $(OBJ_BASE)/usr/bin/printenv.rsrc.done \
     $(OBJ_BASE)/usr/bin/removerez.rsrc.done \
     $(OBJ_BASE)/usr/bin/sed.rsrc.done \
     $(OBJ_BASE)/usr/bin/udl.rsrc.done \
     $(OBJ_BASE)/usr/bin/wall.rsrc.done \
     $(OBJ_BASE)/usr/bin/whatis.rsrc.done \
     $(OBJ_BASE)/usr/bin/whereis.rsrc.done \
     $(OBJ_BASE)/usr/bin/uptime.rsrc.done \
     $(OBJ_BASE)/usr/bin/who.rsrc.done \
     $(OBJ_BASE)/usr/bin/whois.rsrc.done

$(OBJ_BASE)/usr/bin/apropos.rsrc.done:   $(REPO_ROOT)/usr.bin/man/apropos.rez        $(OBJ_BASE)/usr/bin/apropos
	$(call REZ,usr.bin/man/apropos.rez,usr/bin/apropos)
$(OBJ_BASE)/usr/bin/awk.rsrc.done:       $(REPO_ROOT)/usr.bin/awk/awk.rez             $(OBJ_BASE)/usr/bin/awk
	$(call REZ,usr.bin/awk/awk.rez,usr/bin/awk)
$(OBJ_BASE)/usr/bin/basename.rsrc.done:  $(REPO_ROOT)/usr.bin/basename/basename.rez   $(OBJ_BASE)/usr/bin/basename
	$(call REZ,usr.bin/basename/basename.rez,usr/bin/basename)
$(OBJ_BASE)/usr/bin/calendar.rsrc.done:  $(REPO_ROOT)/usr.bin/calendar/calendar.rez   $(OBJ_BASE)/usr/bin/calendar
	$(call REZ,usr.bin/calendar/calendar.rez,usr/bin/calendar)
$(OBJ_BASE)/usr/bin/catrez.rsrc.done:    $(REPO_ROOT)/usr.bin/catrez/catrez.rez       $(OBJ_BASE)/usr/bin/catrez
	$(call REZ,usr.bin/catrez/catrez.rez,usr/bin/catrez)
$(OBJ_BASE)/usr/bin/cksum.rsrc.done:     $(REPO_ROOT)/usr.bin/cksum/cksum.rez         $(OBJ_BASE)/usr/bin/cksum
	$(call REZ,usr.bin/cksum/cksum.rez,usr/bin/cksum)
$(OBJ_BASE)/usr/bin/colcrt.rsrc.done:    $(REPO_ROOT)/usr.bin/colcrt/colcrt.rez       $(OBJ_BASE)/usr/bin/colcrt
	$(call REZ,usr.bin/colcrt/colcrt.rez,usr/bin/colcrt)
$(OBJ_BASE)/usr/bin/compile.rsrc.done:   $(REPO_ROOT)/usr.bin/compile/compile.rez     $(OBJ_BASE)/usr/bin/compile
	$(call REZ,usr.bin/compile/compile.rez,usr/bin/compile)
$(OBJ_BASE)/usr/bin/cpp.rsrc.done:       $(REPO_ROOT)/usr.bin/cpp/cpp.rez             $(OBJ_BASE)/usr/bin/cpp
	$(call REZ,usr.bin/cpp/cpp.rez,usr/bin/cpp)
$(OBJ_BASE)/usr/bin/ctags.rsrc.done:     $(REPO_ROOT)/usr.bin/ctags/ctags.rez         $(OBJ_BASE)/usr/bin/ctags
	$(call REZ,usr.bin/ctags/ctags.rez,usr/bin/ctags)
$(OBJ_BASE)/usr/bin/cut.rsrc.done:       $(REPO_ROOT)/usr.bin/cut/cut.rez             $(OBJ_BASE)/usr/bin/cut
	$(call REZ,usr.bin/cut/cut.rez,usr/bin/cut)
$(OBJ_BASE)/usr/bin/describe.rsrc.done:  $(REPO_ROOT)/usr.orca.bin/describe/describe.rez $(OBJ_BASE)/usr/bin/describe
	$(call REZ,usr.orca.bin/describe/describe.rez,usr/bin/describe)
$(OBJ_BASE)/usr/bin/dirname.rsrc.done:   $(REPO_ROOT)/usr.bin/dirname/dirname.rez     $(OBJ_BASE)/usr/bin/dirname
	$(call REZ,usr.bin/dirname/dirname.rez,usr/bin/dirname)
$(OBJ_BASE)/usr/bin/env.rsrc.done:       $(REPO_ROOT)/usr.bin/env/env.rez             $(OBJ_BASE)/usr/bin/env
	$(call REZ,usr.bin/env/env.rez,usr/bin/env)
$(OBJ_BASE)/usr/bin/fmt.rsrc.done:       $(REPO_ROOT)/usr.bin/fmt/fmt.rez             $(OBJ_BASE)/usr/bin/fmt
	$(call REZ,usr.bin/fmt/fmt.rez,usr/bin/fmt)
$(OBJ_BASE)/usr/bin/install.rsrc.done:   $(REPO_ROOT)/usr.bin/install/inst.rez        $(OBJ_BASE)/usr/bin/install
	$(call REZ,usr.bin/install/inst.rez,usr/bin/install)
$(OBJ_BASE)/usr/bin/last.rsrc.done:      $(REPO_ROOT)/usr.bin/last/last.rez           $(OBJ_BASE)/usr/bin/last
	$(call REZ,usr.bin/last/last.rez,usr/bin/last)
$(OBJ_BASE)/usr/bin/link.rsrc.done:      $(REPO_ROOT)/usr.bin/link/link.rez           $(OBJ_BASE)/usr/bin/link
	$(call REZ,usr.bin/link/link.rez,usr/bin/link)
$(OBJ_BASE)/usr/bin/logger.rsrc.done:    $(REPO_ROOT)/usr.bin/logger/logger.rez       $(OBJ_BASE)/usr/bin/logger
	$(call REZ,usr.bin/logger/logger.rez,usr/bin/logger)
$(OBJ_BASE)/usr/bin/lseg.rsrc.done:      $(REPO_ROOT)/usr.bin/lseg/lseg.rez           $(OBJ_BASE)/usr/bin/lseg
	$(call REZ,usr.bin/lseg/lseg.rez,usr/bin/lseg)
$(OBJ_BASE)/usr/bin/man.rsrc.done:       $(REPO_ROOT)/usr.bin/man/man.rez             $(OBJ_BASE)/usr/bin/man
	$(call REZ,usr.bin/man/man.rez,usr/bin/man)
$(OBJ_BASE)/usr/bin/nroff.rsrc.done:     $(REPO_ROOT)/usr.bin/nroff/nroff.rez         $(OBJ_BASE)/usr/bin/nroff
	$(call REZ,usr.bin/nroff/nroff.rez,usr/bin/nroff)
$(OBJ_BASE)/usr/bin/printenv.rsrc.done:  $(REPO_ROOT)/usr.bin/printenv/printenv.rez   $(OBJ_BASE)/usr/bin/printenv
	$(call REZ,usr.bin/printenv/printenv.rez,usr/bin/printenv)
$(OBJ_BASE)/usr/bin/removerez.rsrc.done: $(REPO_ROOT)/usr.bin/removerez/removerez.rez $(OBJ_BASE)/usr/bin/removerez
	$(call REZ,usr.bin/removerez/removerez.rez,usr/bin/removerez)
$(OBJ_BASE)/usr/bin/sed.rsrc.done:       $(REPO_ROOT)/usr.bin/sed/sed.rez             $(OBJ_BASE)/usr/bin/sed
	$(call REZ,usr.bin/sed/sed.rez,usr/bin/sed)
$(OBJ_BASE)/usr/bin/udl.rsrc.done:       $(REPO_ROOT)/usr.orca.bin/udl/udl.rez        $(OBJ_BASE)/usr/bin/udl
	$(call REZ,usr.orca.bin/udl/udl.rez,usr/bin/udl)
$(OBJ_BASE)/usr/bin/wall.rsrc.done:      $(REPO_ROOT)/usr.bin/wall/wall.rez           $(OBJ_BASE)/usr/bin/wall
	$(call REZ,usr.bin/wall/wall.rez,usr/bin/wall)
$(OBJ_BASE)/usr/bin/whatis.rsrc.done:    $(REPO_ROOT)/usr.bin/man/whatis.rez          $(OBJ_BASE)/usr/bin/whatis
	$(call REZ,usr.bin/man/whatis.rez,usr/bin/whatis)
$(OBJ_BASE)/usr/bin/whereis.rsrc.done:   $(REPO_ROOT)/usr.bin/whereis/whereis.rez     $(OBJ_BASE)/usr/bin/whereis
	$(call REZ,usr.bin/whereis/whereis.rez,usr/bin/whereis)
$(OBJ_BASE)/usr/bin/uptime.rsrc.done:    $(REPO_ROOT)/usr.bin/uptime/uptime.rez      $(OBJ_BASE)/usr/bin/uptime
	$(call REZ,usr.bin/uptime/uptime.rez,usr/bin/uptime)
$(OBJ_BASE)/usr/bin/who.rsrc.done:       $(REPO_ROOT)/usr.bin/who/who.rez             $(OBJ_BASE)/usr/bin/who
	$(call REZ,usr.bin/who/who.rez,usr/bin/who)
$(OBJ_BASE)/usr/bin/whois.rsrc.done:     $(REPO_ROOT)/usr.bin/whois/whois.rez         $(OBJ_BASE)/usr/bin/whois
	$(call REZ,usr.bin/whois/whois.rez,usr/bin/whois)

# ── usr/orca/bin/ ────────────────────────────────────────────────────────────
# describe/descc/descu/udl moved to usr/bin and usr/sbin to match reference paths;
# handled in usr_bin and usr_sbin sections above.

.PHONY: usr_orca_bin
usr_orca_bin:

# ── usr/sbin/ ────────────────────────────────────────────────────────────────

.PHONY: usr_sbin
usr_sbin: \
     $(OBJ_BASE)/usr/sbin/catman.rsrc.done \
     $(OBJ_BASE)/usr/sbin/descc.rsrc.done \
     $(OBJ_BASE)/usr/sbin/descu.rsrc.done \
     $(OBJ_BASE)/usr/sbin/getty.rsrc.done \
     $(OBJ_BASE)/usr/sbin/login.rsrc.done \
     $(OBJ_BASE)/usr/sbin/makewhatis.rsrc.done \
     $(OBJ_BASE)/usr/sbin/newuser.rsrc.done \
     $(OBJ_BASE)/usr/sbin/uptimed.rsrc.done

$(OBJ_BASE)/usr/sbin/catman.rsrc.done:     $(REPO_ROOT)/usr.bin/man/catman.rez              $(OBJ_BASE)/usr/sbin/catman
	$(call REZ,usr.bin/man/catman.rez,usr/sbin/catman)
$(OBJ_BASE)/usr/sbin/descc.rsrc.done:      $(REPO_ROOT)/usr.orca.bin/describe/descc.rez     $(OBJ_BASE)/usr/sbin/descc
	$(call REZ,usr.orca.bin/describe/descc.rez,usr/sbin/descc)
$(OBJ_BASE)/usr/sbin/descu.rsrc.done:      $(REPO_ROOT)/usr.orca.bin/describe/descu.rez     $(OBJ_BASE)/usr/sbin/descu
	$(call REZ,usr.orca.bin/describe/descu.rez,usr/sbin/descu)
$(OBJ_BASE)/usr/sbin/getty.rsrc.done:      $(REPO_ROOT)/usr.sbin/getty/getty.rez             $(OBJ_BASE)/usr/sbin/getty
	$(call REZ,usr.sbin/getty/getty.rez,usr/sbin/getty)
$(OBJ_BASE)/usr/sbin/login.rsrc.done:      $(REPO_ROOT)/usr.bin/login/login.rez             $(OBJ_BASE)/usr/sbin/login
	$(call REZ,usr.bin/login/login.rez,usr/sbin/login)
$(OBJ_BASE)/usr/sbin/makewhatis.rsrc.done: $(REPO_ROOT)/usr.bin/man/makewhatis.rez          $(OBJ_BASE)/usr/sbin/makewhatis
	$(call REZ,usr.bin/man/makewhatis.rez,usr/sbin/makewhatis)
$(OBJ_BASE)/usr/sbin/newuser.rsrc.done:    $(REPO_ROOT)/usr.sbin/newuser/newuser.rez        $(OBJ_BASE)/usr/sbin/newuser
	$(call REZ,usr.sbin/newuser/newuser.rez,usr/sbin/newuser)
$(OBJ_BASE)/usr/sbin/uptimed.rsrc.done:    $(REPO_ROOT)/usr.sbin/uptimed/uptimed.rez        $(OBJ_BASE)/usr/sbin/uptimed
	$(call REZ,usr.sbin/uptimed/uptimed.rez,usr/sbin/uptimed)

# ── usr/games/ ───────────────────────────────────────────────────────────────

.PHONY: usr_games
usr_games: $(OBJ_BASE)/usr/games/calendar.rsrc.done

$(OBJ_BASE)/usr/games/calendar.rsrc.done: $(REPO_ROOT)/usr.bin/calendar/calendar.rez $(OBJ_BASE)/usr/games/calendar
	$(call REZ,usr.bin/calendar/calendar.rez,usr/games/calendar)

# ── Top-level targets ─────────────────────────────────────────────────────────

ALL_TARGETS := kern drivers libs bin sbin usr_bin usr_orca_bin usr_sbin usr_games

.PHONY: all
all: $(ALL_TARGETS)

# validate: dry-run all .rez files without touching binaries
.PHONY: validate
validate:
	@echo "=== Validating all .rez files (dry-run) ==="
	@fail=0; for rez in \
	    kern/gno/kern.rez \
	    kern/drivers/null.rez kern/drivers/zero.rez \
	    kern/drivers/full.rez kern/drivers/console.rez \
	    lib/libc/libc.rez lib/lsaneglue/lsaneglue.rez \
	    lib/libcontrib/libcontrib.rez lib/libcrypt/libcrypt.rez \
	    lib/libsim/simlib.rez \
	    lib/libtermcap/libtermcap.rez lib/libutil/libutil.rez \
	    lib/liby/liby.rez lib/netdb/libnetdb.rez \
	    bin/gsh/gsh.rez \
	    bin/aroff/aroff.rez bin/cat/cat.rez bin/center/center.rez \
	    bin/chtyp/chtyp.rez bin/cmp/cmp.rez bin/df/df.rez \
	    bin/head/head.rez bin/kill/kill.rez bin/ls/ls.rez \
	    bin/more/more.rez bin/pwd/pwd.rez bin/rm/rm.rez \
	    bin/rmdir/rmdir.rez bin/sleep/sleep.rez bin/split/split.rez \
	    bin/strings/strings.rez bin/stty/stty.rez bin/tail/tail.rez \
	    bin/tee/tee.rez bin/test/test.rez bin/uname/uname.rez \
	    bin/uniq/uniq.rez bin/wc/wc.rez bin/yes/yes.rez bin/vi/vi.rez \
	    sbin/mkso/mkso.rez sbin/renram5/renram5.rez \
	    usr.bin/awk/awk.rez usr.bin/basename/basename.rez \
	    usr.bin/calendar/calendar.rez \
	    usr.bin/catrez/catrez.rez usr.bin/cksum/cksum.rez \
	    usr.bin/colcrt/colcrt.rez usr.bin/compile/compile.rez \
	    usr.bin/cpp/cpp.rez usr.bin/ctags/ctags.rez usr.bin/cut/cut.rez \
	    usr.bin/dirname/dirname.rez usr.bin/env/env.rez \
	    usr.bin/false/false.rez usr.bin/fmt/fmt.rez \
	    usr.bin/install/inst.rez usr.bin/last/last.rez \
	    usr.bin/link/link.rez usr.bin/logger/logger.rez \
	    usr.bin/login/login.rez \
	    usr.bin/lseg/lseg.rez \
	    usr.bin/man/apropos.rez usr.bin/man/catman.rez \
	    usr.bin/man/makewhatis.rez usr.bin/man/man.rez \
	    usr.bin/man/whatis.rez \
	    usr.bin/nroff/nroff.rez \
	    usr.bin/printenv/printenv.rez \
	    usr.bin/removerez/removerez.rez usr.bin/sed/sed.rez \
	    usr.bin/tr/tr.rez usr.bin/true/true.rez \
	    usr.bin/wall/wall.rez usr.bin/whereis/whereis.rez \
	    usr.bin/who/who.rez usr.bin/whois/whois.rez \
	    usr.orca.bin/describe/describe.rez \
	    usr.orca.bin/describe/descc.rez \
	    usr.orca.bin/describe/descu.rez \
	    usr.orca.bin/udl/udl.rez \
	    usr.sbin/getty/getty.rez \
	    usr.sbin/newuser/newuser.rez; \
	do \
	    printf "  %-50s " "$$rez"; \
	    if $(COWREZ) $(REPO_ROOT)/$$rez --dry-run --verify 2>&1 | grep -q "verify: OK\|would write"; then \
	        echo "OK"; \
	    else \
	        echo "FAIL"; fail=1; \
	    fi; \
	done; \
	test $$fail -eq 0 && echo "=== All OK ===" || (echo "=== FAILURES ===" && exit 1)

.PHONY: clean
clean:
	find $(OBJ_BASE) -name '*.rsrc.done' -delete
