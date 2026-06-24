@echo off
:: NetRepair — Windows Build Script
:: Tries MSVC (cl.exe) first, falls back to MinGW (g++), then Python fallback

setlocal enabledelayedexpansion
title NetRepair Build

echo.
echo  =====================================================
echo    NetRepair v3.0 — Windows Build
echo    VortexDQ Corporation
echo  =====================================================
echo.

:: ── Try MSVC (cl.exe) ──────────────────────────────────
where cl >nul 2>&1
if %errorlevel% equ 0 (
    echo  [*] Found MSVC — building with cl.exe
    cl /std:c++17 /O2 /EHsc /W3 ^
        src\main.cpp ^
        ws2_32.lib iphlpapi.lib ^
        /Fe:netrepair.exe
    if !errorlevel! equ 0 (
        echo.
        echo  [OK] Built: netrepair.exe  ^(MSVC^)
        goto :DONE
    )
)

:: ── Try MinGW g++ ──────────────────────────────────────
where g++ >nul 2>&1
if %errorlevel% equ 0 (
    echo  [*] Found MinGW g++ — building
    g++ -std=c++17 -O2 -Wall -o netrepair.exe src\main.cpp -lws2_32 -liphlpapi
    if !errorlevel! equ 0 (
        echo.
        echo  [OK] Built: netrepair.exe  ^(MinGW^)
        goto :DONE
    )
)

:: ── No compiler found ──────────────────────────────────
echo.
echo  [!] No C++ compiler found.
echo      Options to install:
echo        MSVC  : https://visualstudio.microsoft.com/downloads/
echo        MinGW : https://www.mingw-w64.org/
echo        winget: winget install -e --id=MSYS2.MSYS2
echo.
echo  Falling back to Python version...
python --version >nul 2>&1 || py --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Python also not found. Install from: https://python.org
    pause & exit /b 1
)
echo  Use run.bat to launch the Python version.
pause
exit /b 1

:DONE
echo.
echo  Run it:
echo    netrepair.exe              ^(interactive menu^)
echo    netrepair.exe scan         ^(diagnose only^)
echo    netrepair.exe fix          ^(scan + fix^)
echo    netrepair.exe auto         ^(full silent fix^)
echo    netrepair.exe help         ^(show all commands^)
echo.
pause
