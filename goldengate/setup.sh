#!/usr/bin/env bash
#
# goldengate/setup.sh
#
# Environment verification and setup for building GNO/ME using GoldenGate + iix.
#
# Run this once before attempting any builds. It is safe to re-run.
#
# Usage:
#   bash goldengate/setup.sh
#   source goldengate/setup.sh   (to also export env vars into your shell)
#
# Platform support: macOS, Linux, Windows (MSYS2/Git Bash)
#
# GoldenGate is found in this order:
#   1. $GOLDEN_GATE or $ORCA_ROOT environment variable
#   2. ~/Library/GoldenGate (macOS per-user default)
#   3. /usr/local/share/GoldenGate (Linux typical)
#   4. /usr/share/GoldenGate (Linux system)
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${REPO_ROOT}/../gno-dist"
OBJ_DIR="${REPO_ROOT}/../gno-obj"

# ── Detect platform ───────────────────────────────────────────────────────────
PLATFORM="$(uname -s 2>/dev/null || echo Windows)"
case "${PLATFORM}" in
  Darwin)  HOST_OS="macOS" ;;
  Linux)   HOST_OS="Linux" ;;
  MINGW*)  HOST_OS="Windows" ;;
  MSYS*)   HOST_OS="Windows" ;;
  CYGWIN*) HOST_OS="Windows" ;;
  *)       HOST_OS="${PLATFORM}" ;;
esac

# ── Find GoldenGate root ──────────────────────────────────────────────────────
if [[ -n "${GOLDEN_GATE:-}" ]]; then
    GG_ROOT="${GOLDEN_GATE}"
elif [[ -n "${ORCA_ROOT:-}" ]]; then
    GG_ROOT="${ORCA_ROOT}"
elif [[ -d "${HOME}/Library/GoldenGate" ]]; then
    GG_ROOT="${HOME}/Library/GoldenGate"
elif [[ -d "/usr/local/share/GoldenGate" ]]; then
    GG_ROOT="/usr/local/share/GoldenGate"
elif [[ -d "/usr/share/GoldenGate" ]]; then
    GG_ROOT="/usr/share/GoldenGate"
else
    GG_ROOT="${HOME}/Library/GoldenGate"  # fallback (will fail check below)
fi

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC} $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $*"; }
fail() { echo -e "${RED}  ✗${NC} $*"; FAILURES=$((FAILURES+1)); }
FAILURES=0

echo ""
echo "GNO/ME Build Environment Setup"
echo "================================"
echo "Platform: ${HOST_OS}"
echo ""

# ── 1. Verify iix ────────────────────────────────────────────────────────────
echo "Checking iix..."
if command -v iix &>/dev/null; then
    IIX_PATH=$(command -v iix)
    ok "iix found at ${IIX_PATH}"
else
    fail "iix not found. Install GoldenGate from https://juiced.gs/store/golden-gate/"
fi

# ── 2. Verify GoldenGate installation ────────────────────────────────────────
echo "Checking GoldenGate installation..."
if [[ -d "${GG_ROOT}" ]]; then
    ok "GoldenGate root at ${GG_ROOT}"
else
    fail "GoldenGate root not found. Set \$GOLDEN_GATE to your GoldenGate directory."
    case "${HOST_OS}" in
      macOS)   warn "  Default location: ~/Library/GoldenGate" ;;
      Linux)   warn "  Typical location: /usr/local/share/GoldenGate" ;;
      Windows) warn "  Set GOLDEN_GATE=C:/path/to/GoldenGate in your shell" ;;
    esac
fi

# ── 3. Verify ORCA/C compiler ────────────────────────────────────────────────
echo "Checking ORCA/C compiler..."
if [[ -f "${GG_ROOT}/Languages/cc" ]]; then
    CC_VERSION=$(iix "${GG_ROOT}/Languages/cc" 2>&1 | head -1 || true)
    ok "ORCA/C compiler: ${CC_VERSION}"
else
    fail "ORCA/C compiler not found at ${GG_ROOT}/Languages/cc"
fi

# ── 4. Verify Linker ─────────────────────────────────────────────────────────
echo "Checking Linker..."
if [[ -f "${GG_ROOT}/Languages/Linker" ]]; then
    LD_VERSION=$(iix "${GG_ROOT}/Languages/Linker" 2>&1 | head -1 || true)
    ok "Linker: ${LD_VERSION}"
else
    fail "Linker not found at ${GG_ROOT}/Languages/Linker"
fi

# ── 5. Verify MakeLib ────────────────────────────────────────────────────────
echo "Checking MakeLib..."
if [[ -f "${GG_ROOT}/Utilities/MakeLib" ]]; then
    ML_VERSION=$(iix "${GG_ROOT}/Utilities/MakeLib" 2>&1 | head -1 || true)
    ok "MakeLib: ${ML_VERSION}"
else
    fail "MakeLib not found at ${GG_ROOT}/Utilities/MakeLib"
fi

# ── 6. Verify Assembler ──────────────────────────────────────────────────────
echo "Checking Assembler..."
if [[ -f "${GG_ROOT}/Languages/Asm65816" ]]; then
    ok "Asm65816 assembler present"
else
    fail "Assembler not found at ${GG_ROOT}/Languages/Asm65816"
fi

# ── 7. Check iix builtins ────────────────────────────────────────────────────
echo "Checking iix builtin commands..."
iix compile --help 2>&1 | grep -q "compile" && ok "iix compile: accessible" || warn "iix compile: not responding as expected"
iix link    --help 2>&1 | grep -q "link"    && ok "iix link: accessible"    || warn "iix link: not responding as expected"
[[ -f "${GG_ROOT}/Utilities/MakeLib" ]] && ok "iix makelib: accessible" || warn "iix makelib: not found at expected path"

# ── 8. Verify python3 (required for cross-platform FinderInfo + cowrez) ───────
echo "Checking python3..."
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version 2>&1)
    ok "python3: ${PY_VERSION}"
else
    fail "python3 not found — required for set-finder-info.py and cowrez.py"
fi

# ── 9. Check for packaging tools ──────────────────────────────────────────────
echo "Checking packaging tools..."
if command -v nulib2 &>/dev/null; then
    ok "nulib2 (ShrinkIt) found — can create .shk archives"
else
    case "${HOST_OS}" in
      macOS)   warn "nulib2 not found. Build from source: ~/source/nulib2 or brew install nulib2" ;;
      Linux)   warn "nulib2 not found. Install: apt install nulib2 / dnf install nulib2" ;;
      Windows) warn "nulib2 not found. Build from source or download a binary." ;;
    esac
fi

if command -v cadius &>/dev/null; then
    ok "cadius found — can create ProDOS disk images"
elif [[ -f "${HOME}/source/cadius/cadius" ]]; then
    ok "cadius found at ~/source/cadius/cadius"
else
    warn "cadius not found. Build from source:"
    warn "  git clone https://github.com/mach-kernel/cadius.git ~/source/cadius && cd ~/source/cadius && make"
    case "${HOST_OS}" in
      Windows) warn "  On Windows: requires MSYS2 + make + gcc" ;;
    esac
fi

# ── 10. Create output directories ─────────────────────────────────────────────
echo "Creating output directories..."
mkdir -p "${OBJ_DIR}"  && ok "Object output dir: ${OBJ_DIR}"
mkdir -p "${DIST_DIR}" && ok "Distribution dir:  ${DIST_DIR}"

# ── 11. Note about namespace / missing tools ──────────────────────────────────
echo ""
echo "Notes:"
warn "dmake is NOT available in GoldenGate — using GNU make instead (intended)"
warn "catrez is replaced by goldengate/tools/cowrez.py (cross-platform Rez compiler)"
warn "gsh (GNO shell) does not run in GoldenGate — not needed for cross-build"
warn "GNO namespace (/src, /obj, /lang/orca) does NOT work in iix — using host paths"
if [[ "${HOST_OS}" == "Linux" ]]; then
    warn "Linux: set-finder-info.py uses os.setxattr (user.com.apple.FinderInfo namespace)"
elif [[ "${HOST_OS}" == "Windows" ]]; then
    warn "Windows: set-finder-info.py writes AFP_AfpInfo NTFS alternate data streams"
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
if [[ ${FAILURES} -eq 0 ]]; then
    echo -e "${GREEN}Environment is ready for building.${NC}"
else
    echo -e "${RED}${FAILURES} check(s) failed. Resolve issues above before building.${NC}"
    exit 1
fi

# ── Export variables for use when sourced ────────────────────────────────────
export GNO_REPO_ROOT="${REPO_ROOT}"
export GNO_GG_ROOT="${GG_ROOT}"
export GNO_OBJ_DIR="${OBJ_DIR}"
export GNO_DIST_DIR="${DIST_DIR}"
export GOLDEN_GATE="${GG_ROOT}"   # ensure child processes pick up the resolved path
export IIX_CC="iix compile"
export IIX_AS="iix assemble"
export IIX_LD="iix link"
export IIX_AR="iix makelib"

echo ""
echo "Exported variables (when sourced):"
echo "  GNO_REPO_ROOT = ${GNO_REPO_ROOT}"
echo "  GNO_GG_ROOT   = ${GNO_GG_ROOT}"
echo "  GOLDEN_GATE   = ${GOLDEN_GATE}"
echo "  GNO_OBJ_DIR   = ${GNO_OBJ_DIR}"
echo "  GNO_DIST_DIR  = ${GNO_DIST_DIR}"
