#!/usr/bin/env bash
# ============================================================
# Network Checker — Linux / macOS Launcher
# VortexDQ Corporation — WATERMARK: VDQ-NC-3.1-LAUNCHER
#
# What this does on every launch:
#   1. Checks for updates via git (silent, skips if offline)
#   2. Auto-installs a C++ compiler if one is not found
#   3. Builds the binary if missing or source is newer
#   4. Runs with sudo elevation automatically
#   5. Falls back to Python if build is not possible
# ============================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/netcheck"
SRC="$SCRIPT_DIR/src/main.cpp"
PY_SCRIPT="$SCRIPT_DIR/python/netcheck.py"
VERSION_FILE="$SCRIPT_DIR/VERSION"
NEEDS_BUILD=false
CXX=""

# ── Colors ────────────────────────────────────────────────
R='\033[91m'; G='\033[92m'; Y='\033[93m'
C='\033[96m'; B='\033[1m';  D='\033[2m'; X='\033[0m'

banner() {
    echo ""
    echo -e "${C}  Network Checker — VortexDQ Corporation${X}"
    echo -e "${D}  ─────────────────────────────────────${X}"
}

ok()   { echo -e "  ${G}[OK]${X}  $1"; }
warn() { echo -e "  ${Y}[!]${X}   $1"; }
err()  { echo -e "  ${R}[!!]${X}  $1"; }
info() { echo -e "  ${D}      $1${X}"; }

banner

# ── 1. Auto-update ────────────────────────────────────────
if command -v git &>/dev/null && [[ -d "$SCRIPT_DIR/.git" ]]; then
    echo -e "  ${B}Checking for updates...${X}"

    # Fetch quietly — silently skip if offline
    if git -C "$SCRIPT_DIR" fetch origin --quiet 2>/dev/null; then
        LOCAL=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || echo "")
        REMOTE=$(git -C "$SCRIPT_DIR" rev-parse origin/main 2>/dev/null || echo "")

        if [[ -n "$LOCAL" && -n "$REMOTE" && "$LOCAL" != "$REMOTE" ]]; then
            warn "Update available — pulling..."
            git -C "$SCRIPT_DIR" pull origin main --quiet 2>/dev/null
            NEW_VER=$(cat "$VERSION_FILE" 2>/dev/null || echo "latest")
            ok "Updated to v${NEW_VER}"
            NEEDS_BUILD=true
        else
            CURRENT_VER=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
            ok "Up to date (v${CURRENT_VER})"
        fi
    else
        CURRENT_VER=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
        info "Offline — running local v${CURRENT_VER}"
    fi
else
    CURRENT_VER=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    info "v${CURRENT_VER} (tip: clone with git to enable auto-update)"
fi

# ── 2. Find or install C++ compiler ───────────────────────
for cc in g++ clang++; do
    if command -v $cc &>/dev/null; then CXX=$cc; break; fi
done

if [[ -z "$CXX" ]]; then
    warn "No C++ compiler found — installing..."
    OS="$(uname -s)"
    if [[ "$OS" == "Darwin" ]]; then
        info "Installing Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null; true  # non-zero is normal if already installed
        # Wait for clang++ to appear (install dialog may be open)
        WAIT=0
        until command -v clang++ &>/dev/null || [[ $WAIT -ge 60 ]]; do
            sleep 3; WAIT=$((WAIT+3))
        done
        command -v clang++ &>/dev/null && CXX=clang++ || true
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y --no-install-recommends g++ 2>/dev/null
        command -v g++ &>/dev/null && CXX=g++
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y gcc-c++ 2>/dev/null
        command -v g++ &>/dev/null && CXX=g++
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm gcc 2>/dev/null
        command -v g++ &>/dev/null && CXX=g++
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y gcc-c++ 2>/dev/null
        command -v g++ &>/dev/null && CXX=g++
    fi

    if [[ -n "$CXX" ]]; then
        ok "Compiler installed: $CXX"
    else
        warn "Could not install compiler — will try Python fallback"
    fi
fi

# ── 3. Build if binary missing, outdated, or after update ─
if [[ ! -x "$BINARY" ]]; then
    info "Binary not found"
    NEEDS_BUILD=true
elif [[ -f "$SRC" && "$SRC" -nt "$BINARY" ]]; then
    info "Source is newer than binary"
    NEEDS_BUILD=true
fi

if [[ "$NEEDS_BUILD" == "true" ]]; then
    if [[ -n "$CXX" && -f "$SRC" ]]; then
        echo -e "  ${B}Building...${X}"
        if $CXX -std=c++17 -O2 -o "$BINARY" "$SRC" 2>/dev/null; then
            ok "Built with $CXX"
        else
            err "Build failed — check src/main.cpp"
            BINARY=""
        fi
    else
        warn "Skipping build — no compiler or source not found"
    fi
fi

echo ""

# ── 4. Run binary with elevation ──────────────────────────
if [[ -x "$BINARY" ]]; then
    if [[ "$EUID" -eq 0 ]]; then
        exec "$BINARY" "$@"
    else
        exec sudo "$BINARY" "$@"
    fi
fi

# ── 5. Python fallback ────────────────────────────────────
warn "No binary available — trying Python fallback..."

PY=""
for py in python3 python; do
    if command -v $py &>/dev/null; then
        # Check Python >= 3.8
        if $py -c "import sys; sys.exit(0 if sys.version_info>=(3,8) else 1)" 2>/dev/null; then
            PY=$py; break
        fi
    fi
done

if [[ -z "$PY" ]]; then
    warn "Python 3.8+ not found — installing..."
    OS="$(uname -s)"
    if [[ "$OS" == "Darwin" ]]; then
        if command -v brew &>/dev/null; then
            brew install python3 2>/dev/null && PY=python3
        else
            err "Install Python from https://python.org or install Homebrew first"
            exit 1
        fi
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y python3 2>/dev/null && PY=python3
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y python3 2>/dev/null && PY=python3
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm python 2>/dev/null && PY=python3
    fi
fi

if [[ -n "$PY" && -f "$PY_SCRIPT" ]]; then
    ok "Running Python fallback ($PY)"
    if [[ "$EUID" -eq 0 ]]; then
        exec "$PY" "$PY_SCRIPT" "$@"
    else
        exec sudo "$PY" "$PY_SCRIPT" "$@"
    fi
fi

err "Could not start Network Checker."
echo "      Install g++ (or python3) and try again:"
echo "        sudo apt install g++     # Debian/Ubuntu"
echo "        sudo dnf install gcc-c++ # Fedora"
echo "        xcode-select --install   # macOS"
exit 1
