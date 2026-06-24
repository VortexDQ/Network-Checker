<div align="center">

```
███╗   ██╗███████╗████████╗██████╗ ███████╗██████╗  █████╗ ██╗██████╗
████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██╔════╝██╔══██╗██╔══██╗██║██╔══██╗
██╔██╗ ██║█████╗     ██║   ██████╔╝█████╗  ██████╔╝███████║██║██████╔╝
██║╚██╗██║██╔══╝     ██║   ██╔══██╗██╔══╝  ██╔═══╝ ██╔══██║██║██╔══██╗
██║ ╚████║███████╗   ██║   ██║  ██║███████╗██║     ██║  ██║██║██║  ██║
╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝
```

**Cross-platform network diagnostic & repair — built in C++**

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-blue?style=flat-square)](.)
[![C++](https://img.shields.io/badge/C%2B%2B-17-00599C?style=flat-square&logo=c%2B%2B)](.)
[![Python](https://img.shields.io/badge/Python-3.8%2B%20fallback-3776AB?style=flat-square&logo=python&logoColor=white)](.)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](.)
[![VortexDQ](https://img.shields.io/badge/by-VortexDQ%20Corporation-8B5CF6?style=flat-square)](.)

</div>

---

## What is this?

NetRepair scans your network stack in seconds, identifies exactly what's broken, explains why in plain English, and either walks you through the fix or runs it for you automatically.

No GUI needed. No dependencies. One binary. Works on Windows, Linux, and macOS — it detects the OS and runs the right commands.

---

## Quick Start

```bash
git clone https://github.com/VortexDQ/NetRepair.git
cd NetRepair
```

<table>
<tr>
<td width="33%">

### 🐧 Linux
```bash
bash build.sh
sudo ./netrepair
```

</td>
<td width="33%">

### 🍎 macOS
```bash
bash build.sh
sudo ./netrepair
```

</td>
<td width="33%">

### 🪟 Windows
```bat
build.bat
run.bat
```
*(auto-elevates to Admin)*

</td>
</tr>
</table>

> **No compiler?** The Python fallback works with zero setup:
> ```bash
> python3 python/netrepair.py
> ```

---

## Commands

```
netrepair                    Interactive menu
netrepair scan               Diagnose — show full report, no changes
netrepair fix                Diagnose then prompt to apply fixes
netrepair auto               Silent full scan + auto-fix (no prompts)
netrepair backup             Export current network config to file
netrepair help               Show this reference
```

### Examples

```bash
# Check what's wrong without changing anything
./netrepair scan

# Fix everything with no prompts — good for scripts
sudo ./netrepair auto

# Pipe output to a log file
sudo ./netrepair auto 2>&1 | tee repair-$(date +%F).log

# Run from anywhere after install
sudo make install
netrepair scan
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Network healthy, or fixes were applied |
| `1` | Issues found — no fix attempted |
| `2` | Unknown command / argument error |

---

## What It Detects

NetRepair runs 7 tests in sequence and stops at the first critical failure to avoid misleading results from cascading errors.

```
Local IP ──► Gateway ──► Router Ping ──► Internet ──► DNS ──► HTTPS
   │             │             │              │          │        │
  FAIL          FAIL          FAIL           FAIL       FAIL    FAIL
   │             │             │              │          │        │
  No          No            Cable /        ISP /      DNS      Proxy /
adapter      route         Wi-Fi /        WAN        broken   Firewall
disabled     table         Router         down
             empty         frozen
```

For every failure it tells you:

- **What broke** — plain English, no jargon
- **Root cause** — most likely reason
- **The fix** — exact commands to run on your OS
- **Auto-fix** — option to run those commands right now

---

## Issue Reference

| # | Issue | Root Cause | Auto-Fix |
|---|-------|-----------|----------|
| 1 | APIPA address (169.254.x.x) | DHCP server not responding | ✅ |
| 2 | No IP address at all | Adapter disabled or driver missing | ✅ |
| 3 | No default gateway | Routing table corrupt or empty | ✅ |
| 4 | Router not responding | Cable/Wi-Fi disconnected, router frozen | ✅ |
| 5 | Internet unreachable (WAN dead) | ISP outage or firewall blocking egress | ✅ |
| 6 | DNS resolution broken | Wrong server, corrupt cache, ISP blocking | ✅ |
| 7 | HTTPS port 443 blocked | Proxy, VPN, antivirus SSL intercept | ✅ |
| 8 | High latency warning | Congestion, VPN overhead, Wi-Fi interference | ✅ |

---

## Sample Output

```
  Collecting system info...
  Local IP              OK  5ms
  Gateway               OK  1ms
  Interface             OK  4ms
  DNS servers           OK  2ms

  Testing connectivity...
  Gateway 192.168.1.1   OK  3ms
  Internet 1.1.1.1      OK  18ms
  DNS server 8.8.8.8    OK  22ms
  DNS resolution        FAIL
  HTTPS port 443        OK  4ms

======================================================
  DIAGNOSIS REPORT  —  Linux
  IP: 192.168.1.105   GW: 192.168.1.1
======================================================

  +- [HIGH] DNS resolution broken — can't resolve hostnames
  |  Internet works (1.1.1.1 replies in 18ms) but hostname
  |  lookups fail. Current DNS: 192.168.1.1.
  |  Browsers show DNS_PROBE_FINISHED_NXDOMAIN.
  |
  |  Root cause:  Corrupted DNS cache, wrong DNS server,
  |               or ISP DNS blocking.
  |  Fix:         Flush cache and switch to Cloudflare +
  |               Google DNS.
  |
  |  Commands (Linux):
  |    sudo resolvectl flush-caches 2>/dev/null || true
  |    sudo sh -c "echo nameserver 1.1.1.1 > /etc/resolv.conf"
  |    sudo sh -c "echo nameserver 8.8.8.8 >> /etc/resolv.conf"
  +--------------------------------------------------

  Apply all auto-fixes? (Y/N):
```

---

## Build

### Requirements

| Platform | Compiler | Minimum Version |
|----------|---------|----------------|
| Linux | g++ | 8.0 |
| macOS | clang++ | Xcode 11 |
| Windows | MSVC | Visual Studio 2019 |
| Windows | MinGW g++ | 8.0 |

C++17 required. No external libraries — stdlib + OS socket APIs only.

### With Make (Linux / macOS)

```bash
make              # build ./netrepair
sudo make install # install to /usr/local/bin/
make clean        # remove binary
```

### With CMake (all platforms)

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
```

### Direct compile

```bash
# Linux / macOS
g++ -std=c++17 -O2 -o netrepair src/main.cpp

# Windows MinGW
g++ -std=c++17 -O2 -o netrepair.exe src/main.cpp -lws2_32 -liphlpapi

# Windows MSVC (Developer Command Prompt)
cl /std:c++17 /O2 /EHsc src/main.cpp ws2_32.lib iphlpapi.lib
```

---

## How It Works

### OS Detection

At compile time, preprocessor macros (`NR_WIN` / `NR_LINUX` / `NR_MAC`) select the right code path. There's zero runtime overhead — each platform's binary contains only its own code.

### Gateway Detection

| Platform | Method | Subprocess? |
|----------|--------|-------------|
| Linux | Read `/proc/net/route` directly | ❌ None |
| macOS | `route -n get default` | ✅ One |
| Windows | `GetIpForwardTable` Win32 API | ❌ None |

Linux and Windows use native kernel interfaces — no subprocess spawning for the most critical piece of info.

### Connectivity Tests

| Test | Method |
|------|--------|
| Local IP | UDP connect trick — `connect()` to 8.8.8.8:80, read `getsockname()` |
| Ping | System `ping` command (ICMP raw sockets need root on all platforms) |
| DNS resolution | `getaddrinfo()` — uses whatever DNS the OS is configured with |
| HTTPS port 443 | Non-blocking TCP `connect()` with `select()` timeout |

### Analysis Logic

Each test result feeds into a decision tree. It stops at the first `critical` issue — there's no point reporting "DNS broken" if the router isn't even responding.

```
CRITICAL path (stops at first hit):
  No IP → APIPA → No Gateway → Router down → WAN dead

HIGH issues (reported independently if past critical):
  DNS broken
  HTTPS blocked

WARNING (reported alongside any other issues):
  High latency
```

### Auto-Fix

Each issue carries three fix command lists (`win` / `linux_c` / `mac`). The platform-selected list is executed live with output visible. Commands are run in order — if one fails it continues rather than aborting, since many network commands return non-zero even when they work (e.g. `arp -d *`).

---

## File Structure

```
NetRepair/
├── src/
│   └── main.cpp          Single-file C++ source (~900 lines)
│                         All platforms, no headers, no deps
│
├── python/
│   └── netrepair.py      Python 3.8+ fallback (stdlib only)
│                         Identical feature set, no build needed
│
├── CMakeLists.txt        CMake build — all platforms
├── Makefile              Quick make — Linux / macOS
├── build.bat             Windows build (MSVC or MinGW)
├── build.sh              Linux/macOS build (auto-installs compiler)
├── run.bat               Windows launcher → C++ → Python fallback
├── run.sh                Linux/macOS launcher → C++ → auto-build → Python
└── README.md             This file
```

---

## Python Fallback

The `python/netrepair.py` script is a full feature-parity fallback for when you can't or don't want to compile. Same commands, same output format, same auto-fix logic.

```bash
# Linux / macOS
sudo python3 python/netrepair.py scan

# Windows
python python\netrepair.py fix
```

The launchers (`run.sh` / `run.bat`) automatically fall back to Python if no compiled binary is found. `run.sh` will even attempt to build the C++ binary first if a compiler is available.

---

## Platform Notes

### Windows
- Requires **Administrator** — `run.bat` triggers a UAC elevation prompt automatically
- ANSI colors work on Windows 10 1903+ and Windows Terminal
- `GetIpForwardTable` is used instead of `route print` for gateway detection

### macOS
- Requires `sudo` for auto-fix commands
- Gateway and interface detection uses `route -n get default`
- DNS server list from `scutil --dns`
- Wi-Fi service name detected via `networksetup -listallhardwareports`

### Linux
- Requires `sudo` or root for auto-fix
- Gateway read from `/proc/net/route` (no subprocess, instant)
- DNS from `resolvectl` (systemd-resolved) with `/etc/resolv.conf` fallback
- Interface from `ip route show default`

### iOS / iPhone
iOS does not allow running arbitrary scripts. For network diagnostics on iPhone:
- **Settings → Wi-Fi** → tap your network → check IP, Subnet Mask, Router, DNS fields
- **Settings → General → Transfer or Reset iPhone → Reset → Reset Network Settings** to nuke and rebuild all network config
- App Store: **Network Analyzer** for a GUI diagnostics tool

---

<div align="center">

Built by **VortexDQ Corporation**  
C++ primary · Python fallback · No BS

</div>
