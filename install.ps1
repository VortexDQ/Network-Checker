# ============================================================
# Network Checker — One-Click Installer
# VortexDQ Corporation — WATERMARK: VDQ-NC-3.1-INSTALLER
#
# Run via Windows+R (paste this entire line):
#   powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/VortexDQ/Network-Checker/main/install.ps1 | iex"
#
# Or download and double-click install.ps1
# ============================================================

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ── Speed up downloads massively (progress bar ironically slows PS downloads) ─
$ProgressPreference    = "SilentlyContinue"
$ConfirmPreference     = "None"

# ── Self-elevate to Admin if not already ──────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal]
         [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    $args_str = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if (-not $PSCommandPath) {
        # Running via iex pipe — save to temp and re-run elevated
        $tmp = "$env:TEMP\nc_install.ps1"
        $MyInvocation.ScriptName | Out-Null
        (Invoke-WebRequest "https://raw.githubusercontent.com/VortexDQ/Network-Checker/main/install.ps1" -UseBasicParsing).Content | Out-File $tmp -Encoding UTF8
        Start-Process PowerShell "-ExecutionPolicy Bypass -File `"$tmp`"" -Verb RunAs
        exit
    }
    Start-Process PowerShell $args_str -Verb RunAs
    exit
}

# ── Config ────────────────────────────────────────────────────────────────────
$INSTALL_DIR = "$env:LOCALAPPDATA\NetworkChecker"
$BINARY      = "$INSTALL_DIR\netcheck.exe"
$PY_SCRIPT   = "$INSTALL_DIR\python\netcheck.py"
$ZIP_URL     = "https://github.com/VortexDQ/Network-Checker/archive/refs/heads/main.zip"
$ZIP_TMP     = "$env:TEMP\NetworkChecker.zip"
$EXTRACT_TMP = "$env:TEMP\nc_extract"

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-OK   { param($m) Write-Host "  [OK]  $m" -ForegroundColor Green  }
function Write-Warn { param($m) Write-Host "  [!]   $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "  [!!]  $m" -ForegroundColor Red    }
function Write-Step { param($m) Write-Host "`n  $m..." -ForegroundColor White   }
function Write-Info { param($m) Write-Host "        $m" -ForegroundColor DarkGray }

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
}

function Has-Command { param($cmd) return !!(Get-Command $cmd -ErrorAction SilentlyContinue) }

# ── Banner ────────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  =================================================" -ForegroundColor Cyan
Write-Host "    Network Checker  -  Installer" -ForegroundColor Cyan
Write-Host "    VortexDQ Corporation" -ForegroundColor DarkCyan
Write-Host "  =================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Download repo ZIP (no git required) ────────────────────────────────────
Write-Step "Downloading Network Checker"
try {
    Invoke-WebRequest -Uri $ZIP_URL -OutFile $ZIP_TMP -UseBasicParsing
    Write-OK "Download complete"
} catch {
    Write-Err "Download failed. Check your internet connection."
    Write-Info "URL: $ZIP_URL"
    Read-Host "`n  Press Enter to exit"
    exit 1
}

# ── 2. Extract ────────────────────────────────────────────────────────────────
Write-Step "Extracting"
if (Test-Path $INSTALL_DIR) { Remove-Item $INSTALL_DIR -Recurse -Force }
if (Test-Path $EXTRACT_TMP) { Remove-Item $EXTRACT_TMP -Recurse -Force }

Expand-Archive -Path $ZIP_TMP -DestinationPath $EXTRACT_TMP -Force

$extracted = Get-ChildItem $EXTRACT_TMP -Directory | Select-Object -First 1
if (-not $extracted) {
    Write-Err "Extraction failed — archive may be corrupt"
    exit 1
}
Move-Item $extracted.FullName $INSTALL_DIR -Force
Remove-Item $ZIP_TMP    -Force -ErrorAction SilentlyContinue
Remove-Item $EXTRACT_TMP -Recurse -Force -ErrorAction SilentlyContinue
Write-OK "Extracted to $INSTALL_DIR"

# ── 3. Find C++ compiler ──────────────────────────────────────────────────────
Write-Step "Detecting compiler"
$cxx     = $null
$cxxPath = $null

# Check MSVC via vswhere
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $clFound = & $vswhere -latest `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -find "VC\**\cl.exe" 2>$null | Select-Object -First 1
    if ($clFound) {
        $cxx     = "cl"
        $cxxPath = Split-Path $clFound
        $env:PATH = "$cxxPath;$env:PATH"
        Write-OK "Found MSVC: $clFound"
    }
}

# Check g++ in PATH
if (-not $cxx -and (Has-Command "g++")) {
    $cxx = "g++"
    Write-OK "Found g++: $(& g++ --version | Select-Object -First 1)"
}

# ── 4. Auto-install compiler if missing ───────────────────────────────────────
if (-not $cxx) {
    Write-Warn "No C++ compiler found"
    Write-Step "Installing MinGW-w64 via winget (this may take a minute)"

    $wingetOk = $false
    if (Has-Command "winget") {
        try {
            winget install --id=Gccteam.GccWin -e --silent `
                --accept-package-agreements --accept-source-agreements 2>$null
            Refresh-Path
            if (Has-Command "g++") { $cxx = "g++"; $wingetOk = $true }
        } catch {}

        # Try MSYS2 MinGW as alternate if above fails
        if (-not $wingetOk) {
            try {
                winget install --id=MSYS2.MSYS2 -e --silent `
                    --accept-package-agreements --accept-source-agreements 2>$null
                # MSYS2 installs to C:\msys64 — add mingw64 bin to PATH
                $mingwBin = "C:\msys64\mingw64\bin"
                if (Test-Path "$mingwBin\g++.exe") {
                    $env:PATH = "$mingwBin;$env:PATH"
                    [System.Environment]::SetEnvironmentVariable(
                        "PATH", "$mingwBin;" + [System.Environment]::GetEnvironmentVariable("PATH","User"), "User")
                    $cxx = "g++"
                    $wingetOk = $true
                    Write-OK "MinGW installed via MSYS2"
                }
            } catch {}
        }
    }

    if (-not $wingetOk) {
        Write-Warn "Could not install compiler automatically"
        Write-Info "Switching to Python fallback (no build required)"
    }
}

# ── 5. Build binary ───────────────────────────────────────────────────────────
$built = $false
if ($cxx) {
    Write-Step "Building netcheck.exe with $cxx"
    $src = "$INSTALL_DIR\src\main.cpp"

    try {
        if ($cxx -eq "g++") {
            & g++ -std=c++17 -O2 -o $BINARY $src -lws2_32 -liphlpapi 2>&1 | Out-Null
        } else {
            # Set up MSVC environment
            $vcvars = Join-Path $cxxPath "..\..\..\..\..\..\VC\Auxiliary\Build\vcvars64.bat"
            if (Test-Path $vcvars) {
                cmd /c "`"$vcvars`" && cl /std:c++17 /O2 /EHsc `"$src`" ws2_32.lib iphlpapi.lib /Fe:`"$BINARY`"" 2>&1 | Out-Null
            }
        }
        if (Test-Path $BINARY) {
            $built = $true
            Write-OK "Build successful"
        } else {
            Write-Warn "Build failed — falling back to Python"
        }
    } catch {
        Write-Warn "Build error — falling back to Python"
    }
}

# ── 6. Python fallback ────────────────────────────────────────────────────────
$pyExe = $null
if (-not $built) {
    Write-Step "Setting up Python fallback"

    # Find existing Python
    foreach ($cmd in @("python","python3","py")) {
        if (Has-Command $cmd) {
            $ver = & $cmd --version 2>&1
            if ($ver -match "3\.[89]|3\.1[0-9]") { $pyExe = $cmd; break }
        }
    }

    # Install Python via winget if not found
    if (-not $pyExe) {
        Write-Warn "Python not found — installing via winget"
        if (Has-Command "winget") {
            try {
                winget install --id=Python.Python.3.11 -e --silent `
                    --accept-package-agreements --accept-source-agreements
                Refresh-Path
                if (Has-Command "python") { $pyExe = "python" }
            } catch {}
        }

        # Last resort — download Python installer directly
        if (-not $pyExe) {
            Write-Warn "winget unavailable — downloading Python installer"
            $pyInstaller = "$env:TEMP\python_installer.exe"
            Invoke-WebRequest "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" `
                -OutFile $pyInstaller -UseBasicParsing
            Start-Process $pyInstaller "/quiet InstallAllUsers=0 PrependPath=1" -Wait
            Remove-Item $pyInstaller -Force -ErrorAction SilentlyContinue
            Refresh-Path
            if (Has-Command "python") { $pyExe = "python" }
        }
    }

    if ($pyExe) {
        Write-OK "Python ready: $pyExe"
    } else {
        Write-Err "Could not set up Python. Visit https://python.org"
        Read-Host "`n  Press Enter to exit"
        exit 1
    }
}

# ── 7. Create launcher batch file ─────────────────────────────────────────────
# This lets users just type 'netcheck' from any terminal after PATH is set
$launcherPath = "$INSTALL_DIR\netcheck.cmd"
if ($built) {
    @"
@echo off
"%~dp0netcheck.exe" %*
"@ | Out-File $launcherPath -Encoding ASCII
} else {
    @"
@echo off
$pyExe "%~dp0python\netcheck.py" %*
"@ | Out-File $launcherPath -Encoding ASCII
}

# ── 8. Add install dir to user PATH ───────────────────────────────────────────
Write-Step "Adding to PATH"
$userPath = [System.Environment]::GetEnvironmentVariable("PATH","User")
if ($userPath -notlike "*$INSTALL_DIR*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$INSTALL_DIR;$userPath", "User")
    Write-OK "Added — open a new terminal to use 'netcheck' anywhere"
} else {
    Write-OK "Already in PATH"
}

# ── 9. Desktop shortcut ───────────────────────────────────────────────────────
Write-Step "Creating desktop shortcut"
try {
    $shortcutPath = "$env:USERPROFILE\Desktop\Network Checker.lnk"
    $wsh      = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    if ($built) {
        $shortcut.TargetPath       = "powershell.exe"
        $shortcut.Arguments        = "-ExecutionPolicy Bypass -Command `"Start-Process '$BINARY' -Verb RunAs`""
    } else {
        $shortcut.TargetPath       = "powershell.exe"
        $shortcut.Arguments        = "-ExecutionPolicy Bypass -Command `"Start-Process '$pyExe' -ArgumentList '$PY_SCRIPT' -Verb RunAs`""
    }
    $shortcut.WorkingDirectory = $INSTALL_DIR
    $shortcut.Description      = "Network Checker - VortexDQ Corporation"
    $shortcut.Save()
    Write-OK "Shortcut created on Desktop"
} catch {
    Write-Warn "Could not create shortcut (non-critical)"
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  =================================================" -ForegroundColor Green
Write-Host "    Network Checker installed successfully!" -ForegroundColor Green
Write-Host "  =================================================" -ForegroundColor Green
Write-Host ""
if ($built) {
    Write-Info "Mode: C++ binary (fastest)"
} else {
    Write-Info "Mode: Python fallback"
}
Write-Info "Location: $INSTALL_DIR"
Write-Info ""
Write-Info "How to run:"
Write-Info "  - Double-click 'Network Checker' on your Desktop"
Write-Info "  - Open new terminal, type: netcheck"
Write-Info "  - Or: netcheck scan / netcheck fix / netcheck auto"
Write-Host ""

$run = Read-Host "  Launch Network Checker now? (Y/N)"
if ($run -match "^[Yy]") {
    Write-Host ""
    if ($built) {
        Start-Process $BINARY -Verb RunAs
    } else {
        Start-Process "powershell" "-ExecutionPolicy Bypass -Command `"& $pyExe '$PY_SCRIPT'`"" -Verb RunAs
    }
}
