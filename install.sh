#!/usr/bin/env bash
# ============================================================
# Network Checker — One-Command Installer
# VortexDQ Corporation — WATERMARK: VDQ-NC-3.1-INSTALLER
#
# Run via:
#   curl -fsSL https://raw.githubusercontent.com/VortexDQ/Network-Checker/main/install.sh | bash
#   or
#   wget -qO- https://raw.githubusercontent.com/VortexDQ/Network-Checker/main/install.sh | bash
# ============================================================

set -u

OS="$(uname -s)"
INSTALL_DIR="$HOME/.local/share/NetworkChecker"
BIN_LINK="/usr/local/bin/netcheck"
ZIP_URL="https://github.com/VortexDQ/Network-Checker/archive/refs/heads/main.zip"

# ── Colors ────────────────────────────────────────────────
R='\033[91m'; G='\033[92m'; Y='\033[93m'
C='\033[96m'; B='\033[1m';  D='\033[2m'; X='\033[0m'

ok()   { echo -e "  ${G}[OK]${X}  $1"; }
warn() { echo -e "  ${Y}[!]${X}   $1"; }
err()  { echo -e "  ${R}[!!]${X}  $1"; exit 1; }
step() { echo -e "\n  ${B}$1${X}"; }

# ── Banner ────────────────────────────────────────────────
clear 2>/dev/null || true
echo ""
echo -e "${C}  =================================================${X}"
echo -e "${C}    Network Checker  —  Installer${X}"
echo -e "${C}    VortexDQ Corporation${X}"
echo -e "${C}  =================================================${X}"
echo ""

# ── 1. Check download tool ────────────────────────────────
step "Checking requirements"
if command -v curl &>/dev/null; then
    DL="curl -fsSL"
    DL_OUT="curl -fsSL -o"
elif command -v wget &>/dev/null; then
    DL="wget -qO-"
    DL_OUT="wget -qO"
else
    err "curl or wget required. Install one and retry."
fi
ok "Download tool ready"

# ── 2. Install unzip if needed ────────────────────────────
if ! command -v unzip &>/dev/null; then
    warn "unzip not found — installing"
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y unzip -qq
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y unzip -q
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm unzip
    elif command -v brew &>/dev/null; then
        brew install unzip
    fi
fi
command -v unzip &>/dev/null || err "Could not install unzip"

# ── 3. Download repo ZIP ──────────────────────────────────
step "Downloading Network Checker"
mkdir -p "$INSTALL_DIR"
TMP_ZIP="/tmp/NetworkChecker_$$.zip"
TMP_EXT="/tmp/nc_extract_$$"

$DL_OUT "$TMP_ZIP" "$ZIP_URL" || err "Download failed — check your internet connection"
ok "Downloaded"

# ── 4. Extract ────────────────────────────────────────────
step "Extracting"
rm -rf "$TMP_EXT"
mkdir -p "$TMP_EXT"
unzip -q "$TMP_ZIP" -d "$TMP_EXT"
rm -f "$TMP_ZIP"

# Move extracted folder contents to INSTALL_DIR
EXTRACTED=$(find "$TMP_EXT" -maxdepth 1 -mindepth 1 -type d | head -1)
if [[ -z "$EXTRACTED" ]]; then err "Extraction failed"; fi
rm -rf "$INSTALL_DIR"
mv "$EXTRACTED" "$INSTALL_DIR"
rm -rf "$TMP_EXT"
ok "Extracted to $INSTALL_DIR"

# ── 5. Find or install C++ compiler ───────────────────────
step "Detecting compiler"
CXX=""
for cc in g++ clang++; do
    command -v $cc &>/dev/null && CXX=$cc && break
done

if [[ -n "$CXX" ]]; then
    ok "Found: $CXX ($($CXX --version 2>&1 | head -1))"
else
    warn "No compiler found — installing"
    if [[ "$OS" == "Darwin" ]]; then
        echo -e "  ${D}  Installing Xcode Command Line Tools...${X}"
        xcode-select --install 2>/dev/null; true
        # Wait up to 120s
        for i in $(seq 1 40); do
            command -v clang++ &>/dev/null && CXX=clang++ && break
            sleep 3
        done
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
    elif command -v brew &>/dev/null; then
        brew install gcc 2>/dev/null
        command -v g++ &>/dev/null && CXX=g++
    fi

    if [[ -n "$CXX" ]]; then
        ok "Installed: $CXX"
    else
        warn "Could not install compiler — will use Python fallback"
    fi
fi

# ── 6. Build binary ───────────────────────────────────────
BUILT=false
BINARY="$INSTALL_DIR/netcheck"

if [[ -n "$CXX" ]]; then
    step "Building netcheck"
    if $CXX -std=c++17 -O2 -o "$BINARY" "$INSTALL_DIR/src/main.cpp" 2>/dev/null; then
        chmod +x "$BINARY"
        BUILT=true
        ok "Built successfully"
    else
        warn "Build failed — using Python fallback"
    fi
fi

# ── 7. Python fallback if no build ────────────────────────
PY=""
if [[ "$BUILT" != "true" ]]; then
    step "Setting up Python fallback"

    for py in python3 python; do
        if command -v $py &>/dev/null; then
            if $py -c "import sys; sys.exit(0 if sys.version_info>=(3,8) else 1)" 2>/dev/null; then
                PY=$py; break
            fi
        fi
    done

    if [[ -z "$PY" ]]; then
        warn "Python not found — installing"
        if [[ "$OS" == "Darwin" ]]; then
            command -v brew &>/dev/null && brew install python3
        elif command -v apt-get &>/dev/null; then
            sudo apt-get install -y python3 2>/dev/null
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y python3 2>/dev/null
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm python 2>/dev/null
        fi
        command -v python3 &>/dev/null && PY=python3
    fi

    [[ -n "$PY" ]] && ok "Python ready: $PY" || err "Could not set up Python. Visit https://python.org"
fi

# ── 8. Create launcher in /usr/local/bin ─────────────────
step "Installing netcheck command"
LAUNCHER="$INSTALL_DIR/netcheck_run.sh"

if [[ "$BUILT" == "true" ]]; then
    cat > "$LAUNCHER" << LAUNCHEOF
#!/usr/bin/env bash
exec sudo "$BINARY" "\$@"
LAUNCHEOF
else
    cat > "$LAUNCHER" << LAUNCHEOF
#!/usr/bin/env bash
exec sudo $PY "$INSTALL_DIR/python/netcheck.py" "\$@"
LAUNCHEOF
fi
chmod +x "$LAUNCHER"

# Try to symlink to /usr/local/bin
if sudo ln -sf "$LAUNCHER" "$BIN_LINK" 2>/dev/null; then
    ok "Installed: netcheck command available system-wide"
else
    # Fallback: add to ~/.local/bin
    mkdir -p "$HOME/.local/bin"
    ln -sf "$LAUNCHER" "$HOME/.local/bin/netcheck"
    # Add to PATH in shell rc files
    for rc in ~/.bashrc ~/.zshrc ~/.profile; do
        if [[ -f "$rc" ]] && ! grep -q ".local/bin" "$rc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
        fi
    done
    ok "Installed: netcheck available in new terminals (~/.local/bin)"
fi

# ── 9. Done ───────────────────────────────────────────────
echo ""
echo -e "${G}  =================================================${X}"
echo -e "${G}    Network Checker installed successfully!${X}"
echo -e "${G}  =================================================${X}"
echo ""
if [[ "$BUILT" == "true" ]]; then
    echo -e "  ${D}Mode: C++ binary (fastest)${X}"
else
    echo -e "  ${D}Mode: Python fallback${X}"
fi
echo -e "  ${D}Location: $INSTALL_DIR${X}"
echo ""
echo -e "  ${B}How to run:${X}"
echo    "    netcheck              Interactive menu"
echo    "    netcheck scan         Diagnose only"
echo    "    netcheck fix          Scan + fix"
echo    "    netcheck auto         Silent full fix"
echo ""
read -r -p "  Launch Network Checker now? (Y/N): " launch
if [[ "$launch" =~ ^[Yy]$ ]]; then
    echo ""
    if [[ "$BUILT" == "true" ]]; then
        sudo "$BINARY"
    else
        sudo $PY "$INSTALL_DIR/python/netcheck.py"
    fi
fi
