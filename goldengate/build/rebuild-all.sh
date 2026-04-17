#!/usr/bin/env bash
#
# goldengate/build/rebuild-all.sh
#
# Full clean + rebuild of GNO/ME from source using the GoldenGate/iix toolchain.
#
# Usage:
#   bash goldengate/build/rebuild-all.sh               # full clean rebuild
#   bash goldengate/build/rebuild-all.sh --no-clean    # rebuild without clean
#   bash goldengate/build/rebuild-all.sh phase7        # single phase only
#   bash goldengate/build/rebuild-all.sh phase6 phase7 # specific phases
#
# Phases (in order):
#   headers   -- install GNO headers to /Library/GoldenGate/lib/ORCACDefs/
#   phase3    -- libc
#   phase5    -- support libraries (lsaneglue, libcrypt, libutil, libtermcap,
#                libcurses, liby, libnetdb, libcontrib)
#   phase6    -- 100+ utilities (bin, sbin, usr.bin, usr.sbin, usr.games)
#   phase7    -- kernel + device drivers (kern, dev/null/zero/full/console)
#   phase8a   -- resource forks (cowrez.py attaches .rez data to binaries)
#   phase8c   -- ProDOS 32MB .2mg disk image (diskImages/gno-built.2mg)
#
# Prerequisites: iix, python3, GoldenGate installation.
# Run goldengate/setup.sh first to verify the environment.
#
# By default each linker invocation emits a <target>.symbols JSON file next
# to the binary/kernel/driver (consumed by the GSplus emulator for symbolic
# debugging). Set GSPLUS_SYMBOLS= (empty) to suppress emission if you need
# byte-identical output to pre-symbol-table builds.
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OBJ_DIR="${REPO_ROOT}/gno_obj"
DIST_DIR="${REPO_ROOT}/../gno-dist"
BUILD="${REPO_ROOT}/goldengate/build"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC} $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $*"; }
die()  { echo -e "${RED}  ✗ FATAL:${NC} $*" >&2; exit 1; }
step() { echo -e "\n${BOLD}=== $* ===${NC}"; }

# ── Parse arguments ───────────────────────────────────────────────────────────

CLEAN=1
PHASES=()

for arg in "$@"; do
    case "$arg" in
        --no-clean) CLEAN=0 ;;
        --help|-h)
            sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        headers|phase3|libc|phase5|libs|phase6|utils|phase7|kern|kernel|phase8a|rez|phase8c|image)
            PHASES+=("$arg") ;;
        *)
            die "Unknown argument: $arg  (try --help)" ;;
    esac
done

# Default: all phases in dependency order
[[ ${#PHASES[@]} -eq 0 ]] && PHASES=(headers phase3 phase5 phase6 phase7 phase8a phase8c)

# ── Quick sanity check ────────────────────────────────────────────────────────

command -v iix &>/dev/null     || die "iix not found — run bash goldengate/setup.sh"
command -v python3 &>/dev/null || die "python3 not found"

# ── Clean ─────────────────────────────────────────────────────────────────────

if [[ $CLEAN -eq 1 ]]; then
    step "Clean"
    if [[ -d "$OBJ_DIR" ]]; then
        rm -rf "$OBJ_DIR"
        ok "Removed $OBJ_DIR"
    fi
    [[ -f "${REPO_ROOT}/diskImages/gno-built.2mg" ]] && rm -f "${REPO_ROOT}/diskImages/gno-built.2mg"
    mkdir -p "$OBJ_DIR" "$DIST_DIR"
    ok "Output directories ready"
fi

# ── Phase runner ──────────────────────────────────────────────────────────────

FAILED=()
T_START=$(date +%s)

run_phase() {
    local label="$1"; shift
    step "$label"
    if "$@"; then
        ok "$label done"
        return 0
    else
        local code=$?
        warn "$label FAILED (exit $code) — continuing with remaining phases"
        FAILED+=("$label")
        return 0   # don't abort the script
    fi
}

# ── Build phases ──────────────────────────────────────────────────────────────

for phase in "${PHASES[@]}"; do
    case "$phase" in
        headers)
            run_phase "GNO headers → GoldenGate" \
                make -f "${REPO_ROOT}/goldengate/install-gno-headers.mk"
            ;;
        phase3|libc)
            run_phase "Phase 3 — libc" \
                make -f "${BUILD}/libc.mk"
            GG_ROOT_INSTALL="${GOLDEN_GATE:-${ORCA_ROOT:-/Library/GoldenGate}}"
            if [[ -f "${OBJ_DIR}/lib/libc" && -d "${GG_ROOT_INSTALL}/lib" ]]; then
                cp "${OBJ_DIR}/lib/libc" "${GG_ROOT_INSTALL}/lib/libc"
                ok "Installed libc → ${GG_ROOT_INSTALL}/lib/libc"
            else
                die "libc install failed: source or destination missing"
            fi
            ;;
        phase5|libs)
            run_phase "Phase 5 — support libraries" \
                make -f "${BUILD}/phase5.mk"
            run_phase "Phase 5b — libktrace" \
                make -f "${BUILD}/ktrace.mk"
            ;;
        phase6|utils)
            # -k: keep going on individual utility failures
            run_phase "Phase 6 — utilities" \
                make -k -f "${BUILD}/phase6.mk"
            run_phase "Phase 6b — hush shell" \
                make -f "${BUILD}/hush.mk"
            ;;
        phase7|kern|kernel)
            run_phase "Phase 7 — kernel + drivers" \
                make -f "${BUILD}/phase7.mk"
            ;;
        phase8a|rez)
            run_phase "Phase 8a — resource forks" \
                make -f "${BUILD}/phase8_rez.mk"
            ;;
        phase8c|image)
            # --warn-missing: treat missing-source binaries as warnings so the
            # build completes even while Phase 9 porting work is in progress.
            # Remove --warn-missing once all 53 missing binaries are sourced.
            run_phase "Phase 8c — disk image" \
                python3 "${BUILD}/phase8c_image.py" --warn-missing
            ;;
    esac
done

# ── Summary ────────────────────────────────────────────────────────────────────

T_END=$(date +%s)
ELAPSED=$(( T_END - T_START ))

echo ""
echo "──────────────────────────────────────────"
printf "Elapsed: %dm %ds\n" $(( ELAPSED / 60 )) $(( ELAPSED % 60 ))

if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo -e "${GREEN}All phases succeeded.${NC}"
else
    echo -e "${YELLOW}Failed phases: ${FAILED[*]}${NC}"
fi

# Show output sizes for key artifacts
echo ""
echo "Key outputs:"
for f in \
    "${OBJ_DIR}/lib/libc" \
    "${OBJ_DIR}/kern" \
    "${OBJ_DIR}/dev/null" \
    "${OBJ_DIR}/dev/console" \
    "${OBJ_DIR}/usr/lib/libcurses" \
    "${REPO_ROOT}/diskImages/gno-built.2mg"
do
    if [[ -f "$f" ]]; then
        size=$(wc -c < "$f")
        printf "  %-50s %d bytes\n" "${f##*/Users/smentzer/source/}" "$size"
    fi
done

[[ ${#FAILED[@]} -eq 0 ]]  # exit 1 if any phase failed
