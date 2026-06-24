#!/usr/bin/env bash
# NetRepair — Linux / macOS Build Script
# VortexDQ Corporation
set -euo pipefail

OS="$(uname -s)"
echo ""
echo "  ====================================================="
echo "    NetRepair v3.0 — Build  |  VortexDQ Corporation"
echo "  ====================================================="
echo ""

# ── Pick compiler ──────────────────────────────────────
CXX=""
if command -v g++ &>/dev/null; then
    CXX=g++
elif command -v clang++ &>/dev/null; then
    CXX=clang++
else
    echo "  [!] No C++ compiler found. Installing..."
    if [[ "$OS" == "Darwin" ]]; then
        echo "  Installing Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        # Wait for install
        until command -v clang++ &>/dev/null; do sleep 5; done
        CXX=clang++
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y g++
        CXX=g++
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y gcc-c++
        CXX=g++
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm gcc
        CXX=g++
    else
        echo "  [!] Cannot install compiler automatically."
        echo "      Install g++ or clang++ with your package manager."
        exit 1
    fi
fi

echo "  [*] Compiler: $CXX ($($CXX --version | head -1))"
echo "  [*] Building src/main.cpp..."

$CXX -std=c++17 -O2 -Wall -o netrepair src/main.cpp

echo "  [OK] Built: ./netrepair"
echo ""
echo "  Run it:"
echo "    ./netrepair              Interactive menu"
echo "    ./netrepair scan         Diagnose only"
echo "    ./netrepair fix          Scan + fix (prompts)"
echo "    ./netrepair auto         Full silent fix"
echo "    ./netrepair backup       Export config"
echo "    ./netrepair help         All commands"
echo ""
echo "  Install globally (optional):"
echo "    sudo make install"
echo ""
