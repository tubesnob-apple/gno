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

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GG_ROOT="${HOME}/Library/GoldenGate"
DIST_DIR="${REPO_ROOT}/../gno-dist"
OBJ_DIR="${REPO_ROOT}/../gno-obj"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC} $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $*"; }
fail() { echo -e "${RED}  ✗${NC} $*"; FAILURES=$((FAILURES+1)); }
FAILURES=0

echo ""
echo "GNO/ME Build Environment Setup"
echo "================================"
echo ""

# ── 1. Verify iix ────────────────────────────────────────────────────────────
echo "Checking iix..."
if command -v iix &>/dev/null; then
    IIX_PATH=$(which iix)
    ok "iix found at ${IIX_PATH}"
else
    fail "iix not found. Install GoldenGate from https://juiced.gs/store/golden-gate/"
fi

# ── 2. Verify GoldenGate installation ────────────────────────────────────────
echo "Checking GoldenGate installation..."
if [[ -d "${GG_ROOT}" ]]; then
    ok "GoldenGate root at ${GG_ROOT}"
else
    fail "GoldenGate root not found at ${GG_ROOT}"
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
# Test each builtin by checking its --help/version output (not by feeding it /dev/null)
iix compile --help 2>&1 | grep -q "compile" && ok "iix compile: accessible" || warn "iix compile: not responding as expected"
iix link    --help 2>&1 | grep -q "link"    && ok "iix link: accessible"    || warn "iix link: not responding as expected"
[[ -f "${GG_ROOT}/Utilities/MakeLib" ]] && ok "iix makelib: accessible (${GG_ROOT}/Utilities/MakeLib)" || warn "iix makelib: not found at expected path"

# ── 8. Check for optional macOS packaging tools ──────────────────────────────
echo "Checking packaging tools..."
if command -v nulib2 &>/dev/null; then
    ok "nulib2 (ShrinkIt) found — can create .shk archives"
else
    warn "nulib2 not found. Install with: brew install nulib2"
    warn "  Needed to produce .shk distribution archives"
fi

if command -v cadius &>/dev/null; then
    ok "cadius found — can create ProDOS disk images"
else
    warn "cadius not found. Install with: brew install cadius"
    warn "  Needed to produce .po/.2mg disk images"
fi

# ── 9. Create output directories ─────────────────────────────────────────────
echo "Creating output directories..."
mkdir -p "${OBJ_DIR}"  && ok "Object output dir: ${OBJ_DIR}"
mkdir -p "${DIST_DIR}" && ok "Distribution dir:  ${DIST_DIR}"

# ── 10. Note about namespace / missing tools ──────────────────────────────────
echo ""
echo "Notes:"
warn "dmake is NOT available in GoldenGate — using GNU make instead (intended)"
warn "catrez is NOT available — must be bootstrapped (see TODO in CLAUDE.md)"
warn "gsh (GNO shell) does not run in GoldenGate — not needed for cross-build"
warn "GNO namespace (/src, /obj, /lang/orca) does NOT work in iix — using macOS paths"
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
export IIX_CC="iix compile"
export IIX_AS="iix assemble"
export IIX_LD="iix link"
export IIX_AR="iix makelib"

echo ""
echo "Exported variables (when sourced):"
echo "  GNO_REPO_ROOT = ${GNO_REPO_ROOT}"
echo "  GNO_GG_ROOT   = ${GNO_GG_ROOT}"
echo "  GNO_OBJ_DIR   = ${GNO_OBJ_DIR}"
echo "  GNO_DIST_DIR  = ${GNO_DIST_DIR}"
