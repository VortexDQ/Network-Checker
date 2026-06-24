<div align="center">

```
███╗   ██╗███████╗████████╗██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗
████╗  ██║██╔════╝╚══██╔══╝██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝
██╔██╗ ██║█████╗     ██║   ██║ █╗ ██║██║   ██║██████╔╝█████╔╝
██║╚██╗██║██╔══╝     ██║   ██║███╗██║██║   ██║██╔══██╗██╔═██╗
██║ ╚████║███████╗   ██║   ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗
╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝

 ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗███████╗██████╗
██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝██╔════╝██╔══██╗
██║     ███████║█████╗  ██║     █████╔╝ █████╗  ██████╔╝
██║     ██╔══██║██╔══╝  ██║     ██╔═██╗ ██╔══╝  ██╔══██╗
╚██████╗██║  ██║███████╗╚██████╗██║  ██╗███████╗██║  ██║
 ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
```

**Cross-platform network diagnostic and repair tool**

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-0ea5e9?style=flat-square)](.)
[![C++17](https://img.shields.io/badge/C%2B%2B-17-00599C?style=flat-square&logo=c%2B%2B&logoColor=white)](.)
[![Python](https://img.shields.io/badge/Python-3.8%2B-3776AB?style=flat-square&logo=python&logoColor=white)](.)
[![License](https://img.shields.io/badge/license-MIT-22c55e?style=flat-square)](LICENSE)
[![VortexDQ](https://img.shields.io/badge/VortexDQ-Corporation-8b5cf6?style=flat-square)](.)

</div>

---

## About

**Network Checker** is a lightweight, zero-dependency command-line tool that diagnoses your network in seconds, pinpoints what is broken and why, and either tells you the exact commands to fix it or runs them for you.

It detects your operating system at compile time and runs the right native commands automatically — no configuration, no setup, no GUI required. Written in C++ for instant startup and direct access to OS networking APIs, with a Python fallback for machines where compiling is not an option.

### Why Network Checker?

Most network troubleshooting guides walk you through ten steps when only one of them applies to your situation. Network Checker tests your stack in logical order, stops at the actual failure point, and tells you exactly what went wrong — router down, DHCP failed, DNS broken, port blocked — without making you read through irrelevant output.

---

## Quick Start

```bash
git clone https://github.com/VortexDQ/NetworkChecker.git
cd NetworkChecker
```

<table>
<tr>
<td width="33%" valign="top">

### 🐧 Linux
```bash
bash build.sh
sudo ./netcheck
```

</td>
<td width="33%" valign="top">

### 🍎 macOS
```bash
bash build.sh
sudo ./netcheck
```

</td>
<td width="33%" valign="top">

### 🪟 Windows
```bat
build.bat
run.bat
```
*Auto-elevates to Admin*

</td>
</tr>
</table>

> **No compiler?** The Python fallback needs nothing installed beyond Python 3.8:
> ```bash
> python3 python/netcheck.py
> ```

---

## Commands

| Command | Description |
|---------|-------------|
| `netcheck` | Open interactive menu |
| `netcheck scan` | Run diagnostics and show report — no changes made |
| `netcheck fix` | Diagnose then prompt before applying fixes |
| `netcheck auto` | Silent full scan and fix with no prompts |
| `netcheck backup` | Export current network config to a timestamped file |
| `netcheck help` | Show command reference |

### Usage Examples

```bash
# See what is wrong without changing anything
./netcheck scan

# Fully automated fix — good for scripts and remote sessions
sudo ./netcheck auto

# Save a full repair log with timestamp
sudo ./netcheck auto 2>&1 | tee fix-$(date +%F).log

# Install globally then run from anywhere
sudo make install
netcheck scan
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Network healthy, or all available fixes were applied |
| `1` | Issues detected — no fix was attempted |
| `2` | Unknown command or argument error |

---

## How It Works

Network Checker runs seven tests in sequence and stops at the first critical failure. There is no point reporting a DNS issue if the router is not even reachable — every downstream result would be meaningless.

```
  Local IP ──► Gateway ──► Router Ping ──► Internet ──► DNS Resolve ──► HTTPS
      │             │             │              │              │            │
    FAIL          FAIL          FAIL           FAIL           FAIL         FAIL
      │             │             │              │              │            │
  Adapter       Routing       Cable /         ISP /         Cache /       Proxy /
  disabled /    table         Wi-Fi /         WAN           Wrong         VPN /
  no driver     empty         Router          down          server        Firewall
                              frozen
```

For every failure it reports:

- **What is broken** — in plain English
- **Most likely root cause** — not a generic list, one specific cause ranked by probability
- **Commands to fix it** — exact commands for your OS, ready to copy and run
- **Auto-fix** — option to run those commands immediately with live output

### Detection Methods

| Test | Method | Subprocess |
|------|--------|-----------|
| Local IP | UDP connect trick — `connect()` to 8.8.8.8:80, read `getsockname()` | None |
| Gateway — Linux | Read `/proc/net/route` directly | None |
| Gateway — Windows | `GetIpForwardTable` Win32 API | None |
| Gateway — macOS | `route -n get default` | One |
| Ping | System `ping` command | One per host |
| DNS resolution | `getaddrinfo()` — uses OS-configured servers | None |
| HTTPS port 443 | Non-blocking TCP `connect()` + `select()` timeout | None |

Linux and Windows gateway detection uses no subprocesses — pure kernel API or file read.

### Analysis Logic

```
CRITICAL  (stops at first hit — cascading results would be misleading)
  └─ No IP address
  └─ APIPA address (169.254.x.x) — DHCP failure
  └─ No default gateway
  └─ Router not responding
  └─ Internet unreachable

HIGH  (checked independently once past critical)
  └─ DNS resolution broken
  └─ HTTPS port 443 blocked

WARNING  (reported alongside other results)
  └─ High latency (> 150ms to 1.1.1.1)
```

---

## What It Detects and Fixes

| # | Issue | Root Cause | Auto-Fix |
|---|-------|-----------|:--------:|
| 1 | APIPA address (169.254.x.x) | DHCP server not responding | ✅ |
| 2 | No IP address | Adapter disabled or driver missing | ✅ |
| 3 | No default gateway | Routing table empty or corrupt | ✅ |
| 4 | Router not responding | Cable / Wi-Fi disconnected, router frozen | ✅ |
| 5 | Internet unreachable | ISP outage, firewall blocking egress | ✅ |
| 6 | DNS resolution broken | Wrong server, corrupt cache, ISP blocking | ✅ |
| 7 | HTTPS port 443 blocked | Proxy, VPN, antivirus SSL intercept | ✅ |
| 8 | High latency | Congestion, VPN overhead, Wi-Fi interference | ✅ |

---

## Sample Output

```
  Collecting system info...
  Local IP              OK   4ms
  Gateway               OK   1ms
  Interface             OK   3ms
  DNS servers           OK   2ms

  Testing connectivity...
  Gateway 192.168.1.1   OK   2ms
  Internet 1.1.1.1      OK  19ms
  DNS server 8.8.8.8    OK  21ms
  DNS resolution        FAIL
  HTTPS port 443        OK   3ms

======================================================
  DIAGNOSIS REPORT  —  Linux
  IP: 192.168.1.105   GW: 192.168.1.1
======================================================

  +- [HIGH] DNS resolution broken — can't resolve hostnames
  |
  |  Internet is fine (1.1.1.1 replies in 19ms) but hostname
  |  lookups fail. Current DNS: 192.168.1.1. Browsers will
  |  show DNS_PROBE_FINISHED_NXDOMAIN.
  |
  |  Root cause:  ISP DNS blocking or corrupt DNS cache.
  |  Fix:         Flush cache and switch to public DNS servers.
  |
  |  Commands (Linux):
  |    sudo resolvectl flush-caches 2>/dev/null || true
  |    sudo sh -c "echo nameserver 1.1.1.1 > /etc/resolv.conf"
  |    sudo sh -c "echo nameserver 8.8.8.8 >> /etc/resolv.conf"
  +--------------------------------------------------

  Apply all auto-fixes? (Y/N): y

  Fixing: DNS resolution broken — can't resolve hostnames

  > sudo resolvectl flush-caches 2>/dev/null || true
  [OK]
  > sudo sh -c "echo nameserver 1.1.1.1 > /etc/resolv.conf"
  [OK]
  > sudo sh -c "echo nameserver 8.8.8.8 >> /etc/resolv.conf"
  [OK]
  v Applied

  All available fixes applied.
```

---

## Building

### Requirements

| Platform | Compiler | Minimum |
|----------|---------|---------|
| Linux | g++ | 8.0 |
| macOS | clang++ | Xcode 11 |
| Windows | MSVC | VS 2019 |
| Windows | MinGW g++ | 8.0 |

C++17 required. No third-party libraries — only the C++ standard library and OS socket APIs.

### Methods

<details>
<summary><strong>Make (Linux / macOS — quickest)</strong></summary>

```bash
make                # build ./netcheck
sudo make install   # install to /usr/local/bin/
make clean          # remove binary
```
</details>

<details>
<summary><strong>CMake (all platforms)</strong></summary>

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
```
</details>

<details>
<summary><strong>Direct compile</strong></summary>

```bash
# Linux / macOS
g++ -std=c++17 -O2 -o netcheck src/main.cpp

# Windows — MinGW
g++ -std=c++17 -O2 -o netcheck.exe src/main.cpp -lws2_32 -liphlpapi

# Windows — MSVC (Developer Command Prompt)
cl /std:c++17 /O2 /EHsc src/main.cpp ws2_32.lib iphlpapi.lib
```
</details>

---

## File Structure

```
NetworkChecker/
│
├── src/
│   └── main.cpp            C++ source — single file, all platforms (~900 lines)
│
├── python/
│   └── netcheck.py         Python 3.8+ fallback — identical features, no build needed
│
├── CMakeLists.txt          CMake build — cross-platform
├── Makefile                Quick build — Linux / macOS
├── build.bat               Windows build script (MSVC or MinGW)
├── build.sh                Linux / macOS build script (auto-installs compiler)
├── run.bat                 Windows launcher → C++ binary → Python fallback
├── run.sh                  Linux / macOS launcher → C++ binary → auto-build → Python
├── LICENSE                 MIT License
└── README.md               This file
```

---

## Platform Notes

<details>
<summary><strong>Windows</strong></summary>

- Requires **Administrator** — `run.bat` triggers a UAC prompt automatically
- ANSI colors work on Windows 10 1903+, Windows 11, and Windows Terminal
- Gateway detection uses `GetIpForwardTable` (Win32 API, no subprocess)
- DNS fix uses PowerShell's `Set-DnsClientServerAddress` to update all active adapters at once

</details>

<details>
<summary><strong>macOS</strong></summary>

- Requires `sudo` for auto-fix commands
- Gateway and interface detected via `route -n get default`
- DNS servers listed via `scutil --dns`
- Wi-Fi service name detected via `networksetup -listallhardwareports`

</details>

<details>
<summary><strong>Linux</strong></summary>

- Requires `sudo` or root for auto-fix
- Gateway read from `/proc/net/route` directly — zero subprocesses, instant
- DNS from `resolvectl` (systemd-resolved) with `/etc/resolv.conf` as fallback
- Interface name from `ip route show default`

</details>

<details>
<summary><strong>iOS / iPhone</strong></summary>

iOS does not support running scripts. For network diagnostics on iPhone:

- **Settings → Wi-Fi** → tap your network → check IP Address, Subnet Mask, Router, and DNS fields manually
- **Settings → General → Transfer or Reset iPhone → Reset → Reset Network Settings** to rebuild all network configuration from scratch
- App Store: search **Network Analyzer** for a GUI-based diagnostics tool

</details>

---

## Python Fallback

`python/netcheck.py` provides full feature parity with the C++ binary using only the Python standard library. No `pip install` needed.

```bash
# Linux / macOS
sudo python3 python/netcheck.py scan

# Windows
python python\netcheck.py fix
```

The launchers (`run.sh` / `run.bat`) fall back to this automatically if no compiled binary is found. `run.sh` will attempt to build the C++ binary first if a compiler is available on the system.

---

## License

MIT — see [LICENSE](LICENSE) for full terms.

© 2026 VortexDQ Corporation

---

<div align="center">

*Network Checker — Know what is broken. Know how to fix it.*
<!-- WATERMARK: VDQ-NC-3.0 | VortexDQ Corporation | github.com/VortexDQ/Network-Checker -->
</div>
