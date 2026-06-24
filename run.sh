#!/usr/bin/env bash
# NetRepair — Linux / macOS Launcher
# Tries C++ binary first, falls back to Python
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# ── Try C++ binary first ───────────────────────────────
for BIN in "$DIR/netrepair" "$DIR/build/netrepair"; do
    if [[ -x "$BIN" ]]; then
        if [[ "$EUID" -ne 0 ]]; then
            exec sudo "$BIN" "$@"
        else
            exec "$BIN" "$@"
        fi
    fi
done

# ── No binary — try to build, else use Python ──────────
echo "  [!] netrepair binary not found."
if command -v g++ &>/dev/null || command -v clang++ &>/dev/null; then
    echo "  [*] Compiler found — building now..."
    bash "$DIR/build.sh"
    if [[ -x "$DIR/netrepair" ]]; then
        if [[ "$EUID" -ne 0 ]]; then exec sudo "$DIR/netrepair" "$@"
        else                          exec "$DIR/netrepair" "$@"; fi
    fi
fi

echo "  [*] Falling back to Python version..."
PY=""
command -v python3 &>/dev/null && PY=python3
[[ -z "$PY" ]] && command -v python &>/dev/null && PY=python

if [[ -z "$PY" ]]; then
    echo "  [!] Python 3 not found either."
    echo "      Build the C++ version: bash build.sh"
    echo "      Or install Python: https://python.org"
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
    exec sudo "$PY" "$DIR/python/netrepair.py" "$@"
else
    exec "$PY" "$DIR/python/netrepair.py" "$@"
fi
