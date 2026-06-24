@echo off
:: NetRepair — Windows Launcher
:: Tries C++ binary first, falls back to Python
setlocal enabledelayedexpansion
title NetRepair v3.0

set "DIR=%~dp0"
set "ARGS=%*"

:: ── Try C++ binary first (fastest) ────────────────────
if exist "%DIR%netrepair.exe" (
    net session >nul 2>&1
    if !errorlevel! neq 0 (
        powershell -Command "Start-Process '%DIR%netrepair.exe' -ArgumentList '%ARGS%' -Verb RunAs -WorkingDirectory '%DIR%'"
    ) else (
        "%DIR%netrepair.exe" %*
    )
    exit /b
)

if exist "%DIR%build\netrepair.exe" (
    net session >nul 2>&1
    if !errorlevel! neq 0 (
        powershell -Command "Start-Process '%DIR%build\netrepair.exe' -ArgumentList '%ARGS%' -Verb RunAs -WorkingDirectory '%DIR%'"
    ) else (
        "%DIR%build\netrepair.exe" %*
    )
    exit /b
)

:: ── No binary — offer to build or use Python ──────────
echo.
echo  [!] netrepair.exe not found.
echo      Run build.bat first to compile the C++ binary.
echo      Falling back to Python version...
echo.

set PYTHON=
python --version >nul 2>&1 && set PYTHON=python
if not defined PYTHON (
    py --version >nul 2>&1 && set PYTHON=py
)
if not defined PYTHON (
    echo  [!] Python not found either.
    echo      Build the C++ version: build.bat
    echo      Or install Python: https://python.org
    pause & exit /b 1
)

net session >nul 2>&1
if !errorlevel! neq 0 (
    powershell -Command "Start-Process '%PYTHON%' -ArgumentList '\"%DIR%python\netrepair.py\" %ARGS%' -Verb RunAs -WorkingDirectory '%DIR%'"
) else (
    %PYTHON% "%DIR%python\netrepair.py" %*
)
