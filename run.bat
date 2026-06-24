@echo off
:: ============================================================
:: Network Checker — Windows Launcher
:: VortexDQ Corporation — WATERMARK: VDQ-NC-3.1-LAUNCHER
::
:: What this does on every launch:
::   1. Checks for updates via git (silent, skips if offline)
::   2. Detects or installs a C++ compiler
::   3. Builds netcheck.exe if missing or source is newer
::   4. Re-launches itself as Admin for the actual run
::   5. Falls back to Python if no compiler is available
:: ============================================================
setlocal enabledelayedexpansion

:: ── Phase routing ─────────────────────────────────────────
:: On the first run we are a normal user — we update and build.
:: Then we re-launch elevated just to RUN the binary.
:: This keeps git pull and compilation in the user context.

if "%~1"=="--elevated" (
    shift
    goto :RUN_ELEVATED
)

:: ── Setup ─────────────────────────────────────────────────
set "DIR=%~dp0"
set "BINARY=%DIR%netcheck.exe"
set "SRC=%DIR%src\main.cpp"
set "VER=%DIR%VERSION"
set "PY_SCRIPT=%DIR%python\netcheck.py"
set "NEEDS_BUILD=0"
set "CXX="

echo.
echo   Network Checker ^| VortexDQ Corporation
echo   ─────────────────────────────────────
echo.

:: ── 1. Auto-update via git ────────────────────────────────
where git >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%DIR%.git\" (
        echo   Checking for updates...
        git -C "%DIR%" fetch origin --quiet 2>nul

        :: Compare local HEAD with origin/main
        for /f %%a in ('git -C "%DIR%" rev-parse HEAD 2^>nul') do set "LOCAL=%%a"
        for /f %%a in ('git -C "%DIR%" rev-parse origin/main 2^>nul') do set "REMOTE=%%a"

        if defined LOCAL if defined REMOTE (
            if "!LOCAL!" neq "!REMOTE!" (
                echo   [!]   Update available -- pulling...
                git -C "%DIR%" pull origin main --quiet 2>nul
                set /p NEW_VER=<"%VER%" 2>nul
                echo   [OK]  Updated to v!NEW_VER!
                set "NEEDS_BUILD=1"
            ) else (
                set /p CURRENT_VER=<"%VER%" 2>nul
                echo   [OK]  Up to date ^(v!CURRENT_VER!^)
            )
        ) else (
            set /p CURRENT_VER=<"%VER%" 2>nul
            echo         Offline -- running local v!CURRENT_VER!
        )
    ) else (
        set /p CURRENT_VER=<"%VER%" 2>nul
        echo         v!CURRENT_VER! ^(clone with git to enable auto-update^)
    )
) else (
    set /p CURRENT_VER=<"%VER%" 2>nul
    echo         v!CURRENT_VER! ^(install git to enable auto-update^)
)

:: ── 2. Find C++ compiler ──────────────────────────────────
where cl >nul 2>&1
if %errorlevel% equ 0 ( set "CXX=cl" & goto :COMPILER_FOUND )

where g++ >nul 2>&1
if %errorlevel% equ 0 ( set "CXX=g++" & goto :COMPILER_FOUND )

:: Try to find MSVC via vswhere
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "!VSWHERE!" (
    for /f "usebackq tokens=*" %%i in (
        `"!VSWHERE!" -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find VC\**\cl.exe 2^>nul`
    ) do (
        set "CXX=%%i"
        goto :COMPILER_FOUND
    )
)

:: Try winget for MinGW if no compiler at all
echo   [!]   No compiler found -- trying to install MinGW via winget...
winget install --id=MSYS2.MSYS2 -e --silent >nul 2>&1
where g++ >nul 2>&1
if %errorlevel% equ 0 ( set "CXX=g++" & goto :COMPILER_FOUND )

echo         No compiler installed. Build manually:
echo           https://www.mingw-w64.org  or  Visual Studio Build Tools
goto :TRY_PYTHON

:COMPILER_FOUND

:: ── 3. Build if binary missing or source is newer ─────────
if not exist "%BINARY%" (
    echo         Binary not found
    set "NEEDS_BUILD=1"
) else (
    :: Check if source is newer than binary using PowerShell
    powershell -NoProfile -Command ^
        "if ((Get-Item '%SRC%').LastWriteTime -gt (Get-Item '%BINARY%').LastWriteTime) { exit 1 } else { exit 0 }" ^
        >nul 2>&1
    if !errorlevel! equ 1 (
        echo         Source is newer than binary
        set "NEEDS_BUILD=1"
    )
)

if "%NEEDS_BUILD%"=="1" (
    echo.
    echo   Building...

    if "!CXX!"=="cl" (
        cl /std:c++17 /O2 /EHsc /W3 "%SRC%" ws2_32.lib iphlpapi.lib /Fe:"%BINARY%" >nul 2>&1
    ) else if "!CXX!"=="g++" (
        g++ -std=c++17 -O2 -o "%BINARY%" "%SRC%" -lws2_32 -liphlpapi >nul 2>&1
    ) else (
        "!CXX!" /std:c++17 /O2 /EHsc "%SRC%" ws2_32.lib iphlpapi.lib /Fe:"%BINARY%" >nul 2>&1
    )

    if exist "%BINARY%" (
        echo   [OK]  Built with !CXX!
    ) else (
        echo   [!!]  Build failed
        goto :TRY_PYTHON
    )
)

echo.

:: ── 4. Re-launch as Admin to run the binary ───────────────
if not exist "%BINARY%" goto :TRY_PYTHON

:: Check if already admin
net session >nul 2>&1
if %errorlevel% equ 0 goto :RUN_ELEVATED

:: Re-launch elevated, passing original args plus --elevated flag
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -ArgumentList '--elevated %*' -Verb RunAs -WorkingDirectory '%DIR%'"
exit /b

:RUN_ELEVATED
:: We are now running as Admin
if exist "%BINARY%" (
    "%BINARY%" %*
    exit /b %errorlevel%
)

:TRY_PYTHON
:: ── 5. Python fallback ────────────────────────────────────
echo   [!]   No binary -- trying Python fallback...
echo.

set "PY="
where python >nul 2>&1 && set "PY=python"
where python3 >nul 2>&1 && set "PY=python3"

if not defined PY (
    echo   [!]   Python not found -- installing via winget...
    winget install --id=Python.Python.3.11 -e --silent >nul 2>&1
    where python >nul 2>&1 && set "PY=python"
)

if defined PY (
    if exist "%PY_SCRIPT%" (
        net session >nul 2>&1
        if !errorlevel! equ 0 (
            %PY% "%PY_SCRIPT%" %*
        ) else (
            powershell -NoProfile -ExecutionPolicy Bypass -Command ^
                "Start-Process -FilePath '%PY%' -ArgumentList '\"%PY_SCRIPT%\" %*' -Verb RunAs -WorkingDirectory '%DIR%'"
        )
        exit /b
    )
)

echo   [!!]  Could not start Network Checker.
echo         Install a C++ compiler or Python 3.8+ and try again.
echo         Compiler: https://www.mingw-w64.org
echo         Python:   https://python.org
pause
exit /b 1
