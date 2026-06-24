@echo off
:: ============================================================
:: Network Checker — Manual Update Script (Windows)
:: VortexDQ Corporation
:: Run this to force a full update + rebuild at any time.
:: Does NOT require admin — builds in user context.
:: ============================================================
setlocal enabledelayedexpansion

set "DIR=%~dp0"
set "BINARY=%DIR%netcheck.exe"
set "SRC=%DIR%src\main.cpp"
set "VER=%DIR%VERSION"

echo.
echo   Network Checker -- Updater
echo   ──────────────────────────

:: Show current version
set /p CURRENT_VER=<"%VER%" 2>nul || set "CURRENT_VER=unknown"
echo   Current version: v!CURRENT_VER!
echo.

:: ── Git update ────────────────────────────────────────────
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo   [!]   git not found -- cannot auto-update
    echo         Install git from: https://git-scm.com
    goto :BUILD
)

if not exist "%DIR%.git\" (
    echo   [!]   Not a git repository
    echo         Clone with: git clone https://github.com/VortexDQ/Network-Checker
    goto :BUILD
)

echo   Fetching latest...
git -C "%DIR%" fetch origin 2>nul

for /f %%a in ('git -C "%DIR%" rev-parse HEAD 2^>nul') do set "LOCAL=%%a"
for /f %%a in ('git -C "%DIR%" rev-parse origin/main 2^>nul') do set "REMOTE=%%a"

if "!LOCAL!"=="!REMOTE!" (
    echo   [OK]  Already on latest ^(v!CURRENT_VER!^)
) else (
    echo   Pulling updates...
    git -C "%DIR%" pull origin main
    set /p NEW_VER=<"%VER%" 2>nul
    echo   [OK]  Updated: v!CURRENT_VER! -^> v!NEW_VER!
)

:: ── Build ─────────────────────────────────────────────────
:BUILD
echo.
echo   Rebuilding binary...

set "CXX="
where cl  >nul 2>&1 && set "CXX=cl"
where g++ >nul 2>&1 && set "CXX=g++"

if not defined CXX (
    echo   [!!]  No compiler found
    echo         Install MinGW: https://www.mingw-w64.org
    echo         Or Visual Studio Build Tools
    echo         The Python fallback still works: python python\netcheck.py
    pause
    exit /b 1
)

if "!CXX!"=="cl" (
    cl /std:c++17 /O2 /EHsc /W3 "%SRC%" ws2_32.lib iphlpapi.lib /Fe:"%BINARY%" >nul 2>&1
) else (
    g++ -std=c++17 -O2 -o "%BINARY%" "%SRC%" -lws2_32 -liphlpapi >nul 2>&1
)

if exist "%BINARY%" (
    set /p FINAL_VER=<"%VER%" 2>nul
    echo   [OK]  Binary rebuilt with !CXX!
    echo   [OK]  Network Checker v!FINAL_VER! is ready
    echo.
    echo   Run it with: run.bat
) else (
    echo   [!!]  Build failed
    echo         Check src\main.cpp for errors
)

echo.
pause
