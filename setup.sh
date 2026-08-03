#!/bin/sh
# =============================================================================
# setup.sh — Initialise all toolchain dependencies
#
# Usage (always from the repo root):
#   sh scripts/setup.sh          # install Homebrew + Buf only
#   sh scripts/setup.sh -f       # also install Flutter + Dart
#
# Flags:
#   -f    Install Flutter (needed for Dart/Flutter SDK generation in buf.gen.yaml)
# =============================================================================

# ==============================================================================
# ── Configuration — edit defaults here, then commit ───────────────────────────
# ==============================================================================

# Buf CLI version.
# "latest" → always track the newest release via Homebrew
# Pinned  → e.g. "1.47.2"
BUF_VERSION="latest"

# Flutter version (only used when -f flag is passed).
# "latest" → always track the newest release
# Pinned  → e.g. "3.24.0"  (note: Homebrew Cask doesn't support all past versions)
FLUTTER_VERSION="latest"

# ==============================================================================
# ── Script internals — do not edit below this line ────────────────────────────
# ==============================================================================

set -eu

# ── Parse flags ───────────────────────────────────────────────────────────────
INSTALL_FLUTTER="false"
while getopts "f" opt 2>/dev/null; do
    case "$opt" in
        f) INSTALL_FLUTTER="true" ;;
        *) ;;
    esac
done

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
skip()    { printf "${YELLOW}[SKIP]${RESET}  %s\n" "$*"; }

printf "${BOLD}"
echo "┌─────────────────────────────────────────┐"
echo "│   Protobuf2 — Dependency Setup          │"
echo "└─────────────────────────────────────────┘"
printf "${RESET}\n"
info "Flutter install: ${INSTALL_FLUTTER} (pass -f to enable)"
echo ""

# ── Helper: install or upgrade a Homebrew formula (never reinstalls if current) ─
# $1 = formula   e.g. "bufbuild/buf/buf"
# $2 = list name e.g. "buf"  (the short name brew list uses)
brew_formula() {
    formula="$1"
    name="$2"

    if brew list "$name" >/dev/null 2>&1; then
        if brew outdated "$name" >/dev/null 2>&1; then
            info "$name is outdated — upgrading…"
            brew upgrade "$name"
            success "$name upgraded to $(brew info --json "$name" 2>/dev/null | grep '"version"' | head -1 | sed 's/[^0-9.]//g')"
        else
            skip "$name is already up-to-date"
        fi
    else
        info "Installing $name…"
        brew install "$formula"
        success "$name installed"
    fi
}

# ── Helper: install or upgrade a Homebrew Cask ────────────────────────────────
# $1 = cask name  e.g. "flutter"
brew_cask() {
    name="$1"

    if brew list --cask "$name" >/dev/null 2>&1; then
        if brew outdated --cask "$name" >/dev/null 2>&1; then
            info "$name is outdated — upgrading…"
            brew upgrade --cask "$name"
            success "$name upgraded"
        else
            skip "$name is already up-to-date"
        fi
    else
        info "Installing $name…"
        brew install --cask "$name"
        success "$name installed"
    fi
}

# ── 1. Homebrew ────────────────────────────────────────────────────────────────
if command -v brew >/dev/null 2>&1; then
    skip "Homebrew already installed ($(brew --version | head -1))"
    brew update --quiet
else
    info "Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    success "Homebrew installed"
fi

# ── 2. Buf CLI ─────────────────────────────────────────────────────────────────
info "Checking Buf CLI (requested: ${BUF_VERSION})…"
brew_formula "bufbuild/buf/buf" "buf"

# ── 3. Flutter + Dart (opt-in via -f flag) ────────────────────────────────────
# Flutter bundles Dart and is required for gen/dart output from buf.gen.yaml.
if [ "$INSTALL_FLUTTER" = "true" ]; then
    info "Checking Flutter (requested: ${FLUTTER_VERSION})…"
    brew_cask "flutter"
else
    skip "Flutter skipped — run 'sh scripts/setup.sh -f' to install it"
fi

# ── 4. Sanity checks ───────────────────────────────────────────────────────────
echo ""
info "Verifying tools on PATH…"

check_tool() {
    tool="$1"
    if command -v "$tool" >/dev/null 2>&1; then
        success "$tool → $(command -v "$tool")"
    else
        warn "$tool not found on PATH — restart your shell or add it to PATH manually."
    fi
}

check_tool buf

if [ "$INSTALL_FLUTTER" = "true" ]; then
    check_tool flutter
    check_tool dart
fi

echo ""
success "Setup complete!"
info "Next: sh scripts/download_deps.sh   — pull Buf schema dependencies"
