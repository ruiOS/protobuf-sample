#!/bin/sh
# =============================================================================
# download_deps.sh — Download / refresh Buf schema dependencies
#
# What this does:
#   1. Verifies buf is installed
#   2. Runs `buf dep update` from the workspace root (root buf.yaml with modules:)
#      to generate/refresh buf.lock for every module that declares deps
#   3. Runs `buf build` to validate the workspace compiles cleanly
#
# Buf v2 workspace layout:
#   A root buf.yaml with `modules:` is the workspace definition.
#   buf.work.yaml was v1-only and is no longer used.
#   buf.lock is written next to the root buf.yaml when modules declare deps.
#
# Usage (from repo root):
#   sh download_deps.sh
# =============================================================================

set -eu

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { printf "${CYAN}[INFO]${RESET}  %s\n" "$*"; }
success() { printf "${GREEN}[OK]${RESET}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; exit 1; }

# ── Resolve repo root: follow symlinks to the real script location ─────────────
# Handles: sh download_deps.sh (from root), sh scripts/download_deps.sh, symlinks
resolve_real_dir() {
    target="$1"
    while [ -L "$target" ]; do
        link="$(readlink "$target")"
        case "$link" in
            /*) target="$link" ;;
            *)  target="$(dirname "$target")/$link" ;;
        esac
    done
    cd "$(dirname "$target")" && pwd
}

REAL_SCRIPT_DIR="$(resolve_real_dir "$0")"

if [ -f "${REAL_SCRIPT_DIR}/buf.yaml" ]; then
    REPO_ROOT="${REAL_SCRIPT_DIR}"
elif [ -f "${REAL_SCRIPT_DIR}/../buf.yaml" ]; then
    REPO_ROOT="$(cd "${REAL_SCRIPT_DIR}/.." && pwd)"
else
    error "Cannot find root buf.yaml (Buf v2 workspace). Run this script from the repo root."
fi

printf "${BOLD}"
echo "┌─────────────────────────────────────────┐"
echo "│   Protobuf2 — Download Buf Dependencies │"
echo "└─────────────────────────────────────────┘"
printf "${RESET}\n"

# ── 1. Verify buf is available ─────────────────────────────────────────────────
if ! command -v buf >/dev/null 2>&1; then
    error "buf not found. Run 'sh setup.sh' first to install it."
fi
success "Using $(buf --version)"
info "Repo root: ${REPO_ROOT}"

# ── 2. Run buf dep update from workspace root ──────────────────────────────────
# Buf v2: reads root buf.yaml (modules: entries), resolves all deps,
# and writes buf.lock next to it.
echo ""
info "Running buf dep update from workspace root…"
(
    cd "${REPO_ROOT}"
    buf dep update
)
success "buf dep update complete"

# ── 3. Show which lock files were written ─────────────────────────────────────
echo ""
info "Lock files present after update:"
FOUND_LOCK=0

if [ -f "${REPO_ROOT}/buf.lock" ]; then
    success "  → buf.lock"
    FOUND_LOCK=1
fi

# Scan for lock files inside protos/
for lock_file in $(find "${REPO_ROOT}/protos" -name "buf.lock" 2>/dev/null || true); do
    rel="${lock_file#"${REPO_ROOT}/"}"
    success "  → ${rel}"
    FOUND_LOCK=1
done

if [ "$FOUND_LOCK" -eq 0 ]; then
    warn "No buf.lock files were written."
    warn "buf.lock is only generated when a module declares external deps."
    warn ""
    warn "To add a dependency, add a 'deps:' block to the module's buf.yaml, e.g.:"
    warn "  deps:"
    warn "    - buf.build/googleapis/googleapis"
    warn "Then re-run this script."
fi

# ── 4. Validate the whole workspace builds cleanly ─────────────────────────────
echo ""
info "Running buf build to validate workspace…"
(
    cd "${REPO_ROOT}"
    buf build
)
success "Workspace builds successfully — all schemas are valid."

echo ""
success "Done! Run 'buf generate' to produce SDK output."
