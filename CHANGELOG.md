# Changelog

All notable changes to Network Checker are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [3.1.0] — 2026-06-24

### Changed
- Project renamed from **NetRepair** to **Network Checker**
- Binary renamed from `netrepair` to `netcheck`
- Python fallback renamed from `netrepair.py` to `netcheck.py`
- README fully rewritten with new name, description, and collapsible sections
- Description trimmed to fit GitHub 350-character repo description field

### Added
- MIT License file (`LICENSE`) — copyright VortexDQ Corporation
- Watermark identifiers embedded in source header, help output, and README
  - Source: `WATERMARK: VDQ-NC-3.0-OPENSOURCE`
  - README: hidden HTML comment in raw file
  - Binary output: shown in `netcheck help`
- `.gitignore` covering compiled binaries, build dirs, runtime logs, Python cache

### Security
- No personal identifiers in any file — only `VortexDQ Corporation` as copyright entity

---

## [3.0.0] — 2026-06-24

### Added
- **C++ rewrite** — single-file cross-platform binary (`src/main.cpp`)
  - C++17, zero external dependencies
  - ~10ms startup vs ~400ms Python
  - Linux gateway detection reads `/proc/net/route` directly (no subprocess)
  - Windows gateway detection via `GetIpForwardTable` Win32 API (no subprocess)
  - Non-blocking TCP `connect()` + `select()` for HTTPS port check
- **Platform support** — Windows, Linux, macOS in one codebase
  - Compile-time OS selection via preprocessor (`NR_WIN` / `NR_LINUX` / `NR_MAC`)
  - Each binary contains only its platform's code
- **CLI commands** — `scan`, `fix`, `auto`, `backup`, `help` with exit codes
- **`netcheck auto`** — fully silent scan + fix, no prompts, exit 0/1 for scripting
- **7-test diagnostic chain** — stops at first critical failure to avoid misleading cascades
- **8 detectable issues** with specific root cause analysis and auto-fix for every one
- **`make_issue()` helper** — fixes C++17 aggregate init ambiguity in push_back
- **Python fallback** (`python/netcheck.py`) — identical features, stdlib only, no pip
- **`run.sh`** — auto-builds C++ if compiler found, falls back to Python
- **`run.bat`** — auto-elevates to Admin, falls back to Python if no binary
- **`build.sh`** — auto-installs g++ / clang++ if missing (apt / dnf / pacman / brew)
- **`build.bat`** — tries MSVC first, then MinGW, explains install options if neither found
- **CMakeLists.txt** — cross-platform CMake build with Release optimizations
- **Makefile** — quick `make` / `sudo make install` / `make clean` for Linux and macOS
- **Timestamped logs** — `netcheck_YYYYMMDD_HHMMSS.log` per run, never overwritten
- **ANSI color output** — enabled via `SetConsoleMode` on Windows 10+

### Issues Detected (new in 3.0)
| # | Issue | Fix |
|---|-------|-----|
| 1 | APIPA address 169.254.x.x | DHCP lease release + stack reset + renew |
| 2 | No IP address | Enable adapter + restart network service |
| 3 | No default gateway | Flush routing table + DHCP renew |
| 4 | Router not responding | Clear ARP cache + DHCP renew |
| 5 | Internet unreachable (WAN dead) | Reset firewall + clear proxy |
| 6 | DNS resolution broken | Flush cache + set Cloudflare/Google DNS |
| 7 | HTTPS port 443 blocked | Reset proxy + firewall rule for 443 |
| 8 | High latency warning | Flush DNS + switch to faster DNS servers |

---

## [2.0.0] — 2026-06-24

### Added
- Per-run timestamped log files — no overwriting previous sessions
- Per-command `[OK]` / `[FAIL]` status with errorlevel checking
- Diagnose mode — ping gateway (auto-detected), 1.1.1.1, 8.8.8.8, DNS resolution, HTTPS
- Backup mode — full `ipconfig /all`, routing table, Winsock catalog, firewall profiles, DNS cache
- View Log — opens current session log in Notepad from the menu
- Confirmation prompt before Advanced repair (type `YES`, warns about time)
- Restart prompt uses `shutdown /r /t 10` with cancellable countdown
- `:RUNCMD` helper subroutine — eliminates duplicated echo + redirect boilerplate
- Color coding — cyan for normal, yellow for Advanced warning, red for admin check
- ARP and `netcfg -d` handled separately with `[WARN]` instead of false `[FAIL]`

### Changed
- `NetworkFixTool.bat` rebuilt as `NetworkChecker.bat`
- Admin check moved to top of file, exits cleanly with clear message
- Log now records start/finish timestamps for Basic and Advanced modes

### Fixed
- `ipconfig /renew` previously ran before `netsh int ip reset` — order corrected
- Missing `2>&1` redirect on several commands meant failures were not logged

---

## [1.0.0] — 2026-06-23

### Added
- Initial Windows batch file (`NetworkFixTool.bat`)
- Administrator privilege check via `net session`
- Single log file (`network_fix_log.txt`) written per run
- Menu with three options: Basic Repair, Advanced Repair, Exit
- Basic repair: Winsock reset, TCP/IP reset, DNS flush, IP release/renew
- Advanced repair: Basic + ARP clear, firewall reset, WinHTTP proxy reset,
  `netcfg -d`, `sfc /scannow`, `DISM /RestoreHealth`
- Restart prompt after each repair mode

---

*Network Checker — VortexDQ Corporation*
*WATERMARK: VDQ-NC-3.0-OPENSOURCE*
