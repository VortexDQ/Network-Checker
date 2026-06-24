#!/usr/bin/env bash
# ============================================================
# Network Checker — Manual Update Script
# VortexDQ Corporation
# Run this to force a full update + rebuild at any time.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/netcheck"
SRC="$SCRIPT_DIR/src/main.cpp"
VERSION_FILE="$SCRIPT_DIR/VERSION"

R='\033[91m'; G='\033[92m'; Y='\033[93m'; C='\033[96m'; B='\033[1m'; D='\033[2m'; X='\033[0m'

echo ""
echo -e "${C}  Network Checker — Updater${X}"
echo -e "${D}  ─────────────────────────${X}"

OLD_VER=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
echo -e "  Current version: ${B}v${OLD_VER}${X}"

# ── Git update ────────────────────────────────────────────
if ! command -v git &>/dev/null; then
    echo -e "  ${Y}[!]${X}  git not found — cannot auto-update"
    echo       "       Install git or download manually from GitHub"
    exit 1
fi

if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
    echo -e "  ${Y}[!]${X}  Not a git repository"
    echo       "       Clone with: git clone https://github.com/VortexDQ/Network-Checker"
    exit 1
fi

echo -e "  Fetching latest..."
git -C "$SCRIPT_DIR" fetch origin

LOCAL=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
REMOTE=$(git -C "$SCRIPT_DIR" rev-parse origin/main)

if [[ "$LOCAL" == "$REMOTE" ]]; then
    echo -e "  ${G}[OK]${X}  Already on latest (v${OLD_VER})"
else
    echo -e "  Pulling updates..."
    git -C "$SCRIPT_DIR" pull origin main
    NEW_VER=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    echo -e "  ${G}[OK]${X}  Updated: v${OLD_VER} → v${NEW_VER}"
fi

# ── Rebuild ───────────────────────────────────────────────
echo ""
echo -e "  ${B}Rebuilding binary...${X}"

CXX=""
for cc in g++ clang++; do
    command -v $cc &>/dev/null && CXX=$cc && break
done

if [[ -z "$CXX" ]]; then
    echo -e "  ${R}[!!]${X} No compiler found — cannot rebuild"
    echo       "        The Python fallback is still available: python3 python/netcheck.py"
    exit 1
fi

if $CXX -std=c++17 -O2 -o "$BINARY" "$SRC"; then
    FINAL_VER=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    echo -e "  ${G}[OK]${X}  Binary rebuilt with $CXX"
    echo -e "  ${G}[OK]${X}  Network Checker v${FINAL_VER} is ready"
else
    echo -e "  ${R}[!!]${X} Build failed — check src/main.cpp for errors"
    exit 1
fi

echo ""
