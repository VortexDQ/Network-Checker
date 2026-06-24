#!/usr/bin/env python3
"""
Network Checker v3.1.0 — Cross-Platform Network Diagnostic & Repair
VortexDQ Corporation
Platforms: Windows · Linux · macOS

Usage:
  python3 netcheck.py          Interactive menu
  python3 netcheck.py --auto   Full scan + auto-fix, no prompts
  python3 netcheck.py --scan   Scan only, no fixes
"""

import os, sys, platform, subprocess, socket, time, re
from datetime import datetime
from typing import Union, Optional

# ═══════════════════════════════════════════════════════
#  OS DETECTION
# ═══════════════════════════════════════════════════════
_OS  = platform.system()   # 'Windows' | 'Linux' | 'Darwin'
WIN  = _OS == "Windows"
LINUX = _OS == "Linux"
MAC  = _OS == "Darwin"

if not (WIN or LINUX or MAC):
    print(f"Unsupported platform: {_OS}")
    sys.exit(1)

OS_LABEL = {"Windows": "Windows", "Linux": "Linux", "Darwin": "macOS"}[_OS]
OS_KEY   = {"Windows": "win",     "Linux": "linux", "Darwin": "mac"}[_OS]

# ═══════════════════════════════════════════════════════
#  ANSI COLORS
# ═══════════════════════════════════════════════════════
if WIN:
    os.system("")           # Enable ANSI in Windows 10+ terminals

R   = "\033[91m"            # Red
G   = "\033[92m"            # Green
Y   = "\033[93m"            # Yellow
CY  = "\033[96m"            # Cyan
B   = "\033[1m"             # Bold
DIM = "\033[2m"             # Dim
X   = "\033[0m"             # Reset
SEV_COL = {"critical": R, "high": Y, "warning": Y, "info": CY}

# ═══════════════════════════════════════════════════════
#  LOGGING
# ═══════════════════════════════════════════════════════
_LOG: list[str] = []
LOG_FILE = f"netcheck_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

def log(msg: str):
    _LOG.append(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")

def save_log():
    with open(LOG_FILE, "w", encoding="utf-8") as f:
        f.write(f"Network Checker v3.1.0 — VortexDQ Corporation\n")
        f.write(f"OS: {platform.platform()}\n")
        f.write(f"Run: {datetime.now()}\n")
        f.write("═" * 54 + "\n\n")
        f.write("\n".join(_LOG))
    print(f"\n{DIM}  Log: {LOG_FILE}{X}")

# ═══════════════════════════════════════════════════════
#  PRIVILEGE CHECK
# ═══════════════════════════════════════════════════════
def is_root() -> bool:
    if WIN:
        try:
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except Exception:
            return False
    return os.geteuid() == 0

# ═══════════════════════════════════════════════════════
#  COMMAND RUNNER
# ═══════════════════════════════════════════════════════
def run(cmd: Union[list, str], timeout: int = 20) -> tuple:
    """Run command silently. Returns (returncode, output_str)."""
    try:
        r = subprocess.run(
            cmd,
            shell=isinstance(cmd, str),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            encoding="utf-8",
            errors="replace"
        )
        out = (r.stdout + r.stderr).strip()
        log(f"RUN {cmd!r} → rc={r.returncode}")
        return r.returncode, out
    except subprocess.TimeoutExpired:
        log(f"TIMEOUT {cmd!r}")
        return 1, "TIMEOUT"
    except FileNotFoundError:
        log(f"NOT FOUND {cmd!r}")
        return 127, "NOT FOUND"
    except Exception as e:
        log(f"ERROR {cmd!r} → {e}")
        return 1, str(e)

def run_live(cmd: Union[list, str], timeout: int = 180) -> int:
    """Run command with output visible in terminal."""
    try:
        r = subprocess.run(cmd, shell=isinstance(cmd, str), timeout=timeout)
        log(f"LIVE {cmd!r} → rc={r.returncode}")
        return r.returncode
    except subprocess.TimeoutExpired:
        return 1
    except Exception as e:
        log(f"LIVE ERROR {cmd!r} → {e}")
        return 1

# ═══════════════════════════════════════════════════════
#  NETWORK INFO COLLECTION
# ═══════════════════════════════════════════════════════
def get_local_ip() -> Optional[str]:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(2)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return None

def get_gateway() -> Optional[str]:
    if WIN:
        rc, out = run("route print 0.0.0.0")
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 3 and parts[0] == "0.0.0.0" and parts[1] == "0.0.0.0":
                gw = parts[2]
                if re.match(r"\d+\.\d+\.\d+\.\d+", gw) and gw != "0.0.0.0":
                    return gw
    elif LINUX:
        rc, out = run("ip route show default")
        if rc == 0 and "via" in out:
            m = re.search(r"via\s+(\d+\.\d+\.\d+\.\d+)", out)
            if m:
                return m.group(1)
        # Fallback: netstat
        rc, out = run("netstat -rn")
        for line in out.splitlines():
            if line.startswith("0.0.0.0"):
                parts = line.split()
                if len(parts) >= 2:
                    return parts[1]
    elif MAC:
        rc, out = run("route -n get default")
        if rc == 0:
            m = re.search(r"gateway:\s+(\d+\.\d+\.\d+\.\d+)", out)
            if m:
                return m.group(1)
        # Fallback: netstat
        rc, out = run("netstat -rn")
        for line in out.splitlines():
            if line.startswith("default"):
                parts = line.split()
                if len(parts) >= 2:
                    gw = parts[1]
                    if re.match(r"\d+\.\d+\.\d+\.\d+", gw):
                        return gw
    return None

def get_interface() -> Optional[str]:
    """Get the active network interface name."""
    if WIN:
        # On Windows, return None — we use PowerShell in fixes instead
        return None
    elif LINUX:
        rc, out = run("ip route show default")
        if rc == 0:
            m = re.search(r"dev\s+(\S+)", out)
            if m:
                return m.group(1)
    elif MAC:
        rc, out = run("route -n get default")
        if rc == 0:
            m = re.search(r"interface:\s+(\S+)", out)
            if m:
                return m.group(1)
        # Fallback: first active interface
        rc, out = run("networksetup -listallhardwareports")
        for line in out.splitlines():
            if "Device:" in line:
                return line.split(":")[1].strip()
    return None

def get_dns_servers() -> list:
    servers = []
    if WIN:
        rc, out = run("ipconfig /all")
        capture = False
        for line in out.splitlines():
            if "DNS Servers" in line:
                capture = True
                parts = line.split(":")
                if len(parts) > 1:
                    ip = parts[-1].strip()
                    if re.match(r"\d+\.\d+\.\d+\.\d+", ip):
                        servers.append(ip)
            elif capture:
                stripped = line.strip()
                if re.match(r"\d+\.\d+\.\d+\.\d+", stripped):
                    servers.append(stripped)
                else:
                    capture = False
    elif LINUX:
        # Try systemd-resolved first
        rc, out = run("resolvectl status")
        if rc == 0:
            for line in out.splitlines():
                if "DNS Servers" in line or "Current DNS Server" in line:
                    m = re.search(r"(\d+\.\d+\.\d+\.\d+)", line)
                    if m:
                        servers.append(m.group(1))
        if not servers:
            try:
                with open("/etc/resolv.conf") as f:
                    for line in f:
                        if line.startswith("nameserver"):
                            parts = line.split()
                            if len(parts) >= 2:
                                servers.append(parts[1])
            except Exception:
                pass
    elif MAC:
        rc, out = run("scutil --dns")
        for line in out.splitlines():
            m = re.search(r"nameserver\[\d+\]\s*:\s*(\d+\.\d+\.\d+\.\d+)", line)
            if m and m.group(1) not in servers:
                servers.append(m.group(1))
    return servers

def get_wifi_name() -> Optional[str]:
    """Get the display name of the Wi-Fi interface (for macOS fixes)."""
    if not MAC:
        return None
    rc, out = run("networksetup -listallhardwareports")
    lines = out.splitlines()
    for i, line in enumerate(lines):
        if "Wi-Fi" in line or "Airport" in line:
            # Next line should be "Device: en0" or similar
            for j in range(i+1, min(i+3, len(lines))):
                if "Device:" in lines[j]:
                    return line.split(":")[-1].strip()
    return "Wi-Fi"

# ═══════════════════════════════════════════════════════
#  CONNECTIVITY TESTS
# ═══════════════════════════════════════════════════════
def ping(host: str, count: int = 3) -> tuple:
    """Returns (success: bool, avg_ms: float)."""
    if WIN:
        cmd = ["ping", "-n", str(count), "-w", "2000", host]
    else:
        cmd = ["ping", "-c", str(count), "-W", "2", host]
    t0 = time.time()
    rc, out = run(cmd, timeout=count * 4)
    ms = int((time.time() - t0) * 1000 / count)
    return rc == 0, ms

def resolve_dns(hostname: str = "google.com") -> bool:
    try:
        socket.setdefaulttimeout(5)
        socket.gethostbyname(hostname)
        return True
    except socket.gaierror:
        return False

def check_https() -> bool:
    try:
        s = socket.create_connection(("1.1.1.1", 443), timeout=5)
        s.close()
        return True
    except Exception:
        return False

def is_apipa(ip: str) -> bool:
    return bool(ip) and ip.startswith("169.254.")

# ═══════════════════════════════════════════════════════
#  FULL DIAGNOSTIC RUN
# ═══════════════════════════════════════════════════════
class State:
    def __init__(self):
        self.local_ip    : Optional[str]  = None
        self.gateway     : Optional[str]  = None
        self.interface   : Optional[str]  = None
        self.dns_servers : list           = []
        self.wifi_name   : Optional[str]  = None

        self.apipa        : bool = False
        self.gw_ok        : bool = False
        self.gw_ms        : int  = 0
        self.internet_ok  : bool = False
        self.internet_ms  : int  = 0
        self.dns_ping_ok  : bool = False
        self.dns_resolve  : bool = False
        self.https_ok     : bool = False
        self.healthy      : bool = False

def run_diagnostics(quiet: bool = False) -> State:
    s = State()

    def step(label: str, fn):
        if not quiet:
            print(f"  {DIM}{label:<22}{X}", end="", flush=True)
        t0 = time.time()
        try:
            result = fn()
        except Exception:
            result = None
        ms = int((time.time() - t0) * 1000)
        if not quiet:
            if result is True or result not in (None, False, ""):
                print(f"{G}OK{X}  {DIM}{ms}ms{X}")
            else:
                print(f"{R}FAIL{X}")
        return result

    if not quiet:
        print(f"\n{CY}  Collecting system info...{X}")

    s.local_ip    = step("Local IP",     get_local_ip)
    s.gateway     = step("Gateway",      get_gateway)
    s.interface   = step("Interface",    get_interface)
    s.dns_servers = step("DNS servers",  get_dns_servers) or []
    if MAC:
        s.wifi_name = get_wifi_name()

    s.apipa = is_apipa(s.local_ip or "")

    if not quiet:
        print(f"\n{CY}  Testing connectivity...{X}")

    if s.gateway:
        ok, ms = step(f"Gateway {s.gateway}", lambda: ping(s.gateway))
        s.gw_ok, s.gw_ms = ok, ms
    else:
        if not quiet:
            print(f"  {DIM}{'Gateway':22}{X}{Y}SKIP  (none found){X}")

    ok, ms = step("Internet 1.1.1.1",   lambda: ping("1.1.1.1"))
    s.internet_ok, s.internet_ms = ok, ms

    ok, ms = step("DNS server 8.8.8.8", lambda: ping("8.8.8.8"))
    s.dns_ping_ok = ok

    s.dns_resolve = step("DNS resolution",   lambda: resolve_dns())
    s.https_ok    = step("HTTPS port 443",   check_https)

    log(f"State: ip={s.local_ip} gw={s.gateway} iface={s.interface} "
        f"gw_ok={s.gw_ok} inet={s.internet_ok} dns={s.dns_resolve} https={s.https_ok}")

    return s

# ═══════════════════════════════════════════════════════
#  ISSUE ANALYSIS
# ═══════════════════════════════════════════════════════
def analyze(s: State) -> list:
    """
    Returns list of issue dicts:
      severity   : critical | high | warning
      title      : short label
      detail     : plain-English explanation
      cause      : most likely root cause
      fix_explain: what the fix does
      auto_fix   : bool  (can we run this automatically?)
      cmds       : { win: [...], linux: [...], mac: [...] }
    """
    issues = []
    iface  = s.interface or ("eth0" if LINUX else "en0")
    wifi   = s.wifi_name  or "Wi-Fi"

    # ── 1. No IP / APIPA ──────────────────────────────
    if not s.local_ip or s.apipa:
        if s.apipa:
            issues.append({
                "severity"   : "critical",
                "title"      : "DHCP failure — APIPA address assigned",
                "detail"     : (
                    f"Your IP is {s.local_ip} (169.254.x.x). This is a self-assigned "
                    "fallback address meaning your router's DHCP server didn't respond. "
                    "Nothing outside your local machine is reachable."
                ),
                "cause"      : "Router DHCP not responding, or adapter didn't request one correctly.",
                "fix_explain": "Flush the bad lease, reset the TCP/IP stack and Winsock catalog, then force a fresh DHCP request.",
                "auto_fix"   : True,
                "cmds": {
                    "win": [
                        "ipconfig /release",
                        "netsh winsock reset",
                        "netsh int ip reset",
                        "ipconfig /flushdns",
                        "ipconfig /renew",
                    ],
                    "linux": [
                        f"sudo ip addr flush dev {iface}",
                        "sudo systemctl restart NetworkManager || sudo dhclient",
                    ],
                    "mac": [
                        f"sudo ipconfig set {iface} DHCP",
                        "sudo dscacheutil -flushcache",
                        "sudo killall -HUP mDNSResponder",
                    ],
                },
            })
        else:
            issues.append({
                "severity"   : "critical",
                "title"      : "No IP address — adapter inactive or no driver",
                "detail"     : (
                    "No active network interface was found. The adapter may be disabled, "
                    "driver missing, or cable/Wi-Fi not connected."
                ),
                "cause"      : "Disabled adapter, missing driver, or no physical connection.",
                "fix_explain": "Enable the adapter and restart the network stack.",
                "auto_fix"   : True,
                "cmds": {
                    "win": [
                        'netsh int set interface "Ethernet" admin=enabled',
                        'netsh int set interface "Wi-Fi" admin=enabled',
                        "ipconfig /renew",
                    ],
                    "linux": [
                        f"sudo ip link set {iface} up",
                        "sudo systemctl restart NetworkManager",
                    ],
                    "mac": [
                        f"networksetup -setnetworkserviceenabled {wifi} on",
                        f"networksetup -setdhcp {wifi}",
                    ],
                },
            })
        return issues  # Nothing else meaningful to test

    # ── 2. No gateway ─────────────────────────────────
    if not s.gateway:
        issues.append({
            "severity"   : "critical",
            "title"      : "No default gateway — routing table empty",
            "detail"     : (
                f"Your IP is {s.local_ip} but no default gateway was found. "
                "You can reach local devices but nothing outside your subnet."
            ),
            "cause"      : "DHCP didn't provide a gateway, or routing table was corrupted.",
            "fix_explain": "Reset the routing table and get a new DHCP lease with gateway.",
            "auto_fix"   : True,
            "cmds": {
                "win": [
                    "netsh int ip reset",
                    "ipconfig /release",
                    "ipconfig /renew",
                ],
                "linux": [
                    "sudo ip route flush table main",
                    "sudo dhclient -r",
                    f"sudo dhclient {iface}",
                ],
                "mac": [
                    "sudo route flush",
                    f"sudo ipconfig set {iface} DHCP",
                ],
            },
        })
        return issues

    # ── 3. Gateway unreachable ─────────────────────────
    if not s.gw_ok:
        issues.append({
            "severity"   : "critical",
            "title"      : f"Router not responding ({s.gateway})",
            "detail"     : (
                f"Your gateway {s.gateway} exists in your routing table but isn't "
                "replying to pings. Most likely: wrong cable port, Wi-Fi disconnected, "
                "router frozen, or ICMP blocked by a host firewall."
            ),
            "cause"      : "Physical connection issue or router is down.",
            "fix_explain": "Clear the ARP cache and re-request DHCP. If still failing, physically check cable or Wi-Fi.",
            "auto_fix"   : True,
            "cmds": {
                "win": [
                    "arp -d *",
                    "ipconfig /release",
                    "ipconfig /renew",
                ],
                "linux": [
                    "sudo ip neigh flush all",
                    "sudo dhclient -r",
                    f"sudo dhclient {iface}",
                ],
                "mac": [
                    "sudo arp -d -a",
                    f"sudo ipconfig set {iface} DHCP",
                ],
            },
        })
        return issues

    # ── 4. Internet ping fails (ISP / WAN down) ────────
    if not s.internet_ok:
        issues.append({
            "severity"   : "critical",
            "title"      : "No internet — router online but WAN is dead",
            "detail"     : (
                f"Gateway {s.gateway} responds but 1.1.1.1 (Cloudflare) doesn't. "
                "Your router has no WAN connection, or a firewall is blocking all "
                "outbound traffic. DNS queries will also fail."
            ),
            "cause"      : "ISP outage, router WAN config issue, or firewall blocking egress.",
            "fix_explain": "Reset the firewall to defaults and clear proxy config. If this doesn't help, restart your router/modem.",
            "auto_fix"   : True,
            "cmds": {
                "win": [
                    "netsh advfirewall reset",
                    "netsh winhttp reset proxy",
                    "ipconfig /flushdns",
                ],
                "linux": [
                    "sudo iptables -F",
                    "sudo iptables -P INPUT ACCEPT",
                    "sudo iptables -P FORWARD ACCEPT",
                    "sudo iptables -P OUTPUT ACCEPT",
                ],
                "mac": [
                    "sudo pfctl -d",
                    "sudo dscacheutil -flushcache",
                    "sudo killall -HUP mDNSResponder",
                ],
            },
        })
        return issues

    # ── 5. DNS resolution broken ───────────────────────
    if not s.dns_resolve:
        dns_str = ", ".join(s.dns_servers) if s.dns_servers else "none detected"
        issues.append({
            "severity"   : "high",
            "title"      : "DNS resolution broken — can't resolve hostnames",
            "detail"     : (
                f"Internet connectivity is fine (1.1.1.1 responds in {s.internet_ms}ms) "
                f"but hostname lookups fail. Current DNS: {dns_str}. "
                "Browsers will show DNS_PROBE_FINISHED_NXDOMAIN or similar."
            ),
            "cause"      : "Corrupted DNS cache, wrong DNS server, or ISP DNS blocking.",
            "fix_explain": "Flush the DNS cache and switch to Cloudflare (1.1.1.1) + Google (8.8.8.8) DNS.",
            "auto_fix"   : True,
            "cmds": {
                "win": [
                    "ipconfig /flushdns",
                    # Use PowerShell to set DNS on all active adapters
                    'powershell -Command "Get-NetAdapter | Where-Object Status -eq Up | Set-DnsClientServerAddress -ServerAddresses 1.1.1.1,8.8.8.8"',
                ],
                "linux": [
                    "sudo resolvectl flush-caches 2>/dev/null || true",
                    "sudo sh -c 'echo nameserver 1.1.1.1 > /etc/resolv.conf'",
                    "sudo sh -c 'echo nameserver 8.8.8.8 >> /etc/resolv.conf'",
                ],
                "mac": [
                    "sudo dscacheutil -flushcache",
                    "sudo killall -HUP mDNSResponder",
                    f"networksetup -setdnsservers {wifi} 1.1.1.1 8.8.8.8",
                ],
            },
        })

    # ── 6. HTTPS blocked ──────────────────────────────
    if s.dns_resolve and not s.https_ok:
        issues.append({
            "severity"   : "high",
            "title"      : "HTTPS (port 443) blocked",
            "detail"     : (
                "DNS resolves and internet pings work, but port 443 (HTTPS) is blocked. "
                "Likely causes: corporate proxy, VPN split-tunnel, antivirus SSL inspection, "
                "or a firewall rule blocking outbound 443."
            ),
            "cause"      : "Proxy config, VPN, or firewall blocking port 443.",
            "fix_explain": "Reset proxy settings and disable system firewall rules blocking 443.",
            "auto_fix"   : True,
            "cmds": {
                "win": [
                    "netsh winhttp reset proxy",
                    'reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /f',
                    'reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyServer /f',
                    'netsh advfirewall firewall add rule name="Allow HTTPS Out" protocol=TCP dir=out remoteport=443 action=allow',
                ],
                "linux": [
                    "unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY",
                    "sudo iptables -I OUTPUT -p tcp --dport 443 -j ACCEPT",
                ],
                "mac": [
                    f"networksetup -setsecurewebproxystate {wifi} off",
                    f"networksetup -setwebproxystate {wifi} off",
                    f"networksetup -setsocksfirewallproxystate {wifi} off",
                ],
            },
        })

    # ── 7. Slow but working ────────────────────────────
    if s.internet_ok and s.internet_ms > 150:
        issues.append({
            "severity"   : "warning",
            "title"      : f"High latency detected ({s.internet_ms}ms to 1.1.1.1)",
            "detail"     : (
                f"Everything works but latency to 1.1.1.1 is {s.internet_ms}ms. "
                "Normal is under 30ms on fibre, under 80ms on 4G/5G. "
                "Possible causes: congested network, distant DNS server, VPN overhead, or Wi-Fi interference."
            ),
            "cause"      : "Network congestion, VPN, or Wi-Fi issues.",
            "fix_explain": "Flush DNS cache. If on Wi-Fi, try moving closer to router or switching to 5GHz band.",
            "auto_fix"   : True,
            "cmds": {
                "win": [
                    "ipconfig /flushdns",
                    'powershell -Command "Get-NetAdapter | Where-Object Status -eq Up | Set-DnsClientServerAddress -ServerAddresses 1.1.1.1,8.8.8.8"',
                ],
                "linux": [
                    "sudo resolvectl flush-caches 2>/dev/null || true",
                ],
                "mac": [
                    "sudo dscacheutil -flushcache",
                    "sudo killall -HUP mDNSResponder",
                ],
            },
        })

    s.healthy = len(issues) == 0
    return issues

# ═══════════════════════════════════════════════════════
#  REPORT PRINTER
# ═══════════════════════════════════════════════════════
def print_report(s: State, issues: list):
    ip_str = s.local_ip or "no IP"
    gw_str = s.gateway  or "no gateway"
    print(f"\n{'═'*54}")
    print(f"{B}  DIAGNOSIS REPORT{X}  —  {OS_LABEL}")
    print(f"  IP: {ip_str}   GW: {gw_str}")
    print(f"{'═'*54}")

    if not issues:
        print(f"\n  {G}✓  No issues found. Network is healthy.{X}\n")
        return

    for i, issue in enumerate(issues, 1):
        col = SEV_COL.get(issue["severity"], Y)
        sev = issue["severity"].upper()
        print(f"\n  {col}┌─ [{sev}] {issue['title']}{X}")
        print(f"  {col}│{X}  {issue['detail']}")
        print(f"  {col}│{X}")
        print(f"  {col}│{X}  {B}Root cause:{X}  {issue['cause']}")
        print(f"  {col}│{X}  {B}Fix:{X}         {issue['fix_explain']}")
        print(f"  {col}│{X}")
        print(f"  {col}│{X}  {CY}Commands to run on {OS_LABEL}:{X}")
        for cmd in issue["cmds"].get(OS_KEY, []):
            if cmd.startswith("#"):
                print(f"  {col}│{X}    {DIM}{cmd}{X}")
            else:
                print(f"  {col}│{X}    {Y}{cmd}{X}")
        print(f"  {col}└{'─'*50}{X}")
        log(f"ISSUE {i}: [{sev}] {issue['title']}")

# ═══════════════════════════════════════════════════════
#  AUTO-FIX RUNNER
# ═══════════════════════════════════════════════════════
def auto_fix(s: State, issues: list):
    if not is_root():
        print(f"\n  {R}[!]{X} Auto-fix needs admin/root privileges.")
        if WIN:
            print("      Right-click → Run as administrator.")
        else:
            print("      Run: sudo python3 netcheck.py")
        return

    fixed_any = False
    for issue in issues:
        if not issue.get("auto_fix"):
            continue

        col = SEV_COL.get(issue["severity"], Y)
        print(f"\n  {col}Fixing:{X} {B}{issue['title']}{X}")
        cmds = issue["cmds"].get(OS_KEY, [])
        if not cmds:
            print(f"  {DIM}No auto-fix available for {OS_LABEL}.{X}")
            continue

        for cmd in cmds:
            if cmd.startswith("#"):
                print(f"  {DIM}{cmd}{X}")
                continue
            # Replace {iface} placeholder
            iface = s.interface or ("eth0" if LINUX else "en0")
            wifi  = s.wifi_name or "Wi-Fi"
            cmd   = cmd.replace("{iface}", iface).replace("{wifi}", wifi)

            print(f"\n  {Y}▶{X} {cmd}")
            rc = run_live(cmd, timeout=180)
            if rc == 0:
                print(f"  {G}[OK]{X}")
            else:
                # Some commands return non-zero even when they work (e.g. arp -d *)
                print(f"  {Y}[done — exit {rc}]{X}")
        fixed_any = True
        print(f"  {G}✓ Applied{X}")

    if fixed_any:
        print(f"\n  {G}All available fixes applied.{X}")
        print(f"  {DIM}A restart may be required for some changes.{X}")
    else:
        print(f"\n  {DIM}Nothing to fix.{X}")

# ═══════════════════════════════════════════════════════
#  BACKUP
# ═══════════════════════════════════════════════════════
BACKUP_CMDS = {
    "win": [
        ("ipconfig /all",                      "IP Configuration"),
        ("route print",                        "Routing Table"),
        ("netsh int ip show config",           "TCP/IP Config"),
        ("netsh winsock show catalog",         "Winsock Catalog"),
        ("netsh advfirewall show allprofiles", "Firewall Profiles"),
        ("ipconfig /displaydns",               "DNS Cache"),
    ],
    "linux": [
        ("ip addr show",                       "Interfaces"),
        ("ip route show",                      "Routes"),
        ("cat /etc/resolv.conf",               "DNS Config"),
        ("ss -tlnp",                           "Listening Ports"),
        ("iptables -L -n 2>/dev/null",         "Firewall Rules"),
    ],
    "mac": [
        ("ifconfig",                           "Interfaces"),
        ("netstat -rn",                        "Routes"),
        ("scutil --dns",                       "DNS Config"),
        ("networksetup -listallhardwareports", "Hardware Ports"),
        ("pfctl -s rules 2>/dev/null",         "Firewall Rules"),
    ],
}

def backup():
    fname = f"netconfig_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    print(f"\n  Exporting to {fname}...")
    with open(fname, "w", encoding="utf-8") as f:
        f.write(f"Network Config Backup — {datetime.now()}\n")
        f.write(f"OS: {platform.platform()}\n")
        f.write("═" * 54 + "\n")
        for cmd, label in BACKUP_CMDS.get(OS_KEY, []):
            f.write(f"\n── {label} ──\n")
            rc, out = run(cmd, timeout=15)
            f.write(out + "\n")
    print(f"  {G}[OK]{X} Saved: {fname}")
    log(f"BACKUP: {fname}")

# ═══════════════════════════════════════════════════════
#  UI
# ═══════════════════════════════════════════════════════
def clear():
    os.system("cls" if WIN else "clear")

def header():
    priv = f"{G}Admin/Root{X}" if is_root() else f"{Y}User (limited){X}"
    print(f"""
{CY}{'═'*54}
  Network Checker v3.1.0  ·  VortexDQ Corporation
  OS: {OS_LABEL:<10}  Privileges: {priv}{CY}
{'═'*54}{X}

  {B}1{X}   Scan          Diagnose and report issues
  {B}2{X}   Scan + Fix    Diagnose then apply all auto-fixes
  {B}3{X}   Fix Now       Skip scan, run all fixes immediately
  {B}4{X}   Backup        Export current network config
  {B}5{X}   Exit
""")

def main():
    # ── CLI flags ─────────────────────────────────────
    args = set(sys.argv[1:])

    if "--auto" in args or "-a" in args:
        print(f"{CY}  Auto mode — scanning and fixing...{X}")
        s = run_diagnostics()
        issues = analyze(s)
        print_report(s, issues)
        if issues:
            auto_fix(s, issues)
        save_log()
        return

    if "--scan" in args:
        s = run_diagnostics()
        issues = analyze(s)
        print_report(s, issues)
        save_log()
        return

    # ── Interactive menu ──────────────────────────────
    while True:
        clear()
        header()
        choice = input("  Choice: ").strip()

        if choice == "1":
            clear()
            s = run_diagnostics()
            issues = analyze(s)
            print_report(s, issues)
            save_log()
            input(f"\n  {DIM}Enter to continue...{X}")

        elif choice == "2":
            clear()
            s = run_diagnostics()
            issues = analyze(s)
            print_report(s, issues)
            if issues:
                print()
                yn = input(f"  {Y}Apply all auto-fixes? (Y/N):{X} ").strip().upper()
                if yn == "Y":
                    auto_fix(s, issues)
            save_log()
            input(f"\n  {DIM}Enter to continue...{X}")

        elif choice == "3":
            clear()
            if not is_root():
                print(f"\n  {R}[!]{X} Requires admin/root. Run with elevated privileges.")
                if not WIN:
                    print("      sudo python3 netcheck.py")
                input("\n  Enter to continue...")
                continue
            s = run_diagnostics()
            issues = analyze(s)
            auto_fix(s, issues)
            save_log()
            input(f"\n  {DIM}Enter to continue...{X}")

        elif choice == "4":
            clear()
            backup()
            input(f"\n  {DIM}Enter to continue...{X}")

        elif choice == "5":
            save_log()
            sys.exit(0)

if __name__ == "__main__":
    main()