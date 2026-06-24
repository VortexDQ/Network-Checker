// ============================================================
// Network Checker v3.0
// Copyright (c) 2026 VortexDQ Corporation
// github.com/VortexDQ/Network-Checker
// Licensed under the MIT License — see LICENSE
//
// WATERMARK: VDQ-NC-3.0-OPENSOURCE
// This identifier must be retained in all copies or
// substantial portions of this software per the MIT License.
// ============================================================
// ─── Platform Detection ───────────────────────────────────────────────────────
#if defined(_WIN32) || defined(_WIN64)
  #define NR_WIN
  #ifndef WIN32_LEAN_AND_MEAN
    #define WIN32_LEAN_AND_MEAN
  #endif
  #include <winsock2.h>
  #include <ws2tcpip.h>
  #include <iphlpapi.h>
  #include <windows.h>
  #pragma comment(lib, "ws2_32.lib")
  #pragma comment(lib, "iphlpapi.lib")
  #define NR_POPEN  _popen
  #define NR_PCLOSE _pclose
  static const char* OS_LABEL = "Windows";
#elif defined(__APPLE__)
  #define NR_MAC
  #include <sys/socket.h>
  #include <sys/types.h>
  #include <netinet/in.h>
  #include <arpa/inet.h>
  #include <netdb.h>
  #include <unistd.h>
  #include <fcntl.h>
  #include <sys/wait.h>
  #define NR_POPEN  popen
  #define NR_PCLOSE pclose
  static const char* OS_LABEL = "macOS";
#else
  #define NR_LINUX
  #include <sys/socket.h>
  #include <sys/types.h>
  #include <netinet/in.h>
  #include <arpa/inet.h>
  #include <netdb.h>
  #include <unistd.h>
  #include <fcntl.h>
  #include <sys/wait.h>
  #define NR_POPEN  popen
  #define NR_PCLOSE pclose
  static const char* OS_LABEL = "Linux";
#endif

#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <fstream>
#include <chrono>
#include <algorithm>
#include <cstring>
#include <cstdio>
#include <ctime>
#include <map>
#include <utility>

// ─── ANSI Colors ──────────────────────────────────────────────────────────────
namespace Col {
  const std::string R   = "\033[91m";
  const std::string G   = "\033[92m";
  const std::string Y   = "\033[93m";
  const std::string CY  = "\033[96m";
  const std::string B   = "\033[1m";
  const std::string DIM = "\033[2m";
  const std::string X   = "\033[0m";
}

void enable_ansi() {
#ifdef NR_WIN
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD mode = 0;
    GetConsoleMode(h, &mode);
    SetConsoleMode(h, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
#endif
}

// ─── Logging ──────────────────────────────────────────────────────────────────
static std::vector<std::string> g_log;
static std::string g_log_file;

static std::string now_str(const char* fmt = "%H:%M:%S") {
    std::time_t t = std::time(nullptr);
    char buf[32];
    std::strftime(buf, sizeof(buf), fmt, std::localtime(&t));
    return std::string(buf);
}

void nlog(const std::string& msg) {
    g_log.push_back("[" + now_str() + "] " + msg);
}

void save_log() {
    std::ofstream f(g_log_file);
    if (!f) return;
    f << "NetRepair v3.0 — VortexDQ Corporation\n"
      << "OS: " << OS_LABEL << "\n"
      << "Run: " << now_str("%Y-%m-%d %H:%M:%S") << "\n"
      << std::string(54, '=') << "\n\n";
    for (const auto& l : g_log) f << l << "\n";
    std::cout << "\n" << Col::DIM << "  Log: " << g_log_file << Col::X << "\n";
}

// ─── String Helpers ───────────────────────────────────────────────────────────
static std::string trim(const std::string& s) {
    size_t a = s.find_first_not_of(" \t\r\n");
    if (a == std::string::npos) return "";
    size_t b = s.find_last_not_of(" \t\r\n");
    return s.substr(a, b - a + 1);
}
static bool starts_with(const std::string& s, const std::string& pre) {
    return s.size() >= pre.size() && s.compare(0, pre.size(), pre) == 0;
}
static bool contains(const std::string& s, const std::string& sub) {
    return s.find(sub) != std::string::npos;
}

// ─── Command Execution ────────────────────────────────────────────────────────
std::string exec_cmd(const std::string& cmd, int* rc_out = nullptr) {
    std::string out;
    char buf[512];
    FILE* pipe = NR_POPEN((cmd + " 2>&1").c_str(), "r");
    if (!pipe) { if (rc_out) *rc_out = -1; return ""; }
    while (fgets(buf, sizeof(buf), pipe)) out += buf;
    int rc = NR_PCLOSE(pipe);
#ifdef NR_WIN
    if (rc_out) *rc_out = rc;
#else
    if (rc_out) *rc_out = WEXITSTATUS(rc);
#endif
    nlog("CMD: " + cmd);
    return out;
}

int exec_live(const std::string& cmd) {
    nlog("LIVE: " + cmd);
    int rc = std::system(cmd.c_str());
#ifndef NR_WIN
    rc = WEXITSTATUS(rc);
#endif
    return rc;
}

// ─── Privilege Check ──────────────────────────────────────────────────────────
bool is_root() {
#ifdef NR_WIN
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
    TOKEN_ELEVATION elev = {};
    DWORD sz = sizeof(elev);
    bool up = GetTokenInformation(token, TokenElevation, &elev, sz, &sz)
              && elev.TokenIsElevated;
    CloseHandle(token);
    return up;
#else
    return geteuid() == 0;
#endif
}

// ─── Socket Init ──────────────────────────────────────────────────────────────
void sock_init() {
#ifdef NR_WIN
    WSADATA wsa;
    WSAStartup(MAKEWORD(2, 2), &wsa);
#endif
}
void sock_cleanup() {
#ifdef NR_WIN
    WSACleanup();
#endif
}

// ─── Network Info ─────────────────────────────────────────────────────────────
std::string get_local_ip() {
#ifdef NR_WIN
    SOCKET s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s == INVALID_SOCKET) return "";
    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons(80);
    inet_pton(AF_INET, "8.8.8.8", &addr.sin_addr);
    if (connect(s, (struct sockaddr*)&addr, sizeof(addr)) != 0) { closesocket(s); return ""; }
    struct sockaddr_in local = {};
    int len = sizeof(local);
    getsockname(s, (struct sockaddr*)&local, &len);
    closesocket(s);
    char buf[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &local.sin_addr, buf, sizeof(buf));
    return std::string(buf);
#else
    int s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) return "";
    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons(80);
    inet_pton(AF_INET, "8.8.8.8", &addr.sin_addr);
    if (connect(s, (struct sockaddr*)&addr, sizeof(addr)) != 0) { close(s); return ""; }
    struct sockaddr_in local = {};
    socklen_t len = sizeof(local);
    getsockname(s, (struct sockaddr*)&local, &len);
    close(s);
    char buf[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &local.sin_addr, buf, sizeof(buf));
    return std::string(buf);
#endif
}

std::string get_gateway() {
#ifdef NR_WIN
    MIB_IPFORWARDTABLE* table = nullptr;
    DWORD size = 0;
    GetIpForwardTable(nullptr, &size, FALSE);
    table = reinterpret_cast<MIB_IPFORWARDTABLE*>(new char[size]);
    std::string gw;
    if (GetIpForwardTable(table, &size, FALSE) == NO_ERROR) {
        for (DWORD i = 0; i < table->dwNumEntries; i++) {
            if (table->table[i].dwForwardDest == 0) {
                char buf[INET_ADDRSTRLEN];
                DWORD a = table->table[i].dwForwardNextHop;
                inet_ntop(AF_INET, &a, buf, sizeof(buf));
                gw = buf;
                break;
            }
        }
    }
    delete[] reinterpret_cast<char*>(table);
    return gw;
#elif defined(NR_LINUX)
    // Read /proc/net/route directly — no subprocess needed, instant
    std::ifstream f("/proc/net/route");
    if (!f) return "";
    std::string line;
    std::getline(f, line); // skip header
    while (std::getline(f, line)) {
        std::istringstream ss(line);
        std::string iface, dest, gw_hex;
        ss >> iface >> dest >> gw_hex;
        if (dest == "00000000") {
            unsigned long v = std::stoul(gw_hex, nullptr, 16);
            struct in_addr a;
            a.s_addr = static_cast<in_addr_t>(v);
            return std::string(inet_ntoa(a));
        }
    }
    return "";
#elif defined(NR_MAC)
    int rc;
    std::string out = exec_cmd("route -n get default", &rc);
    std::istringstream ss(out);
    std::string line;
    while (std::getline(ss, line)) {
        size_t p = line.find("gateway:");
        if (p != std::string::npos) return trim(line.substr(p + 8));
    }
    return "";
#endif
}

std::string get_interface() {
#ifdef NR_WIN
    return "";
#elif defined(NR_LINUX)
    int rc;
    std::string out = exec_cmd("ip route show default", &rc);
    size_t p = out.find("dev ");
    if (p != std::string::npos) {
        std::istringstream ss(out.substr(p + 4));
        std::string iface; ss >> iface;
        return iface;
    }
    return "eth0";
#elif defined(NR_MAC)
    int rc;
    std::string out = exec_cmd("route -n get default", &rc);
    std::istringstream ss(out);
    std::string line;
    while (std::getline(ss, line)) {
        size_t p = line.find("interface:");
        if (p != std::string::npos) return trim(line.substr(p + 10));
    }
    return "en0";
#endif
}

std::string get_wifi_service() {
#ifdef NR_MAC
    int rc;
    std::string out = exec_cmd("networksetup -listallhardwareports", &rc);
    std::istringstream ss(out);
    std::string line;
    while (std::getline(ss, line)) {
        if (contains(line, "Wi-Fi") || contains(line, "AirPort")) {
            size_t p = line.find("Hardware Port:");
            if (p != std::string::npos) return trim(line.substr(p + 14));
        }
    }
    return "Wi-Fi";
#else
    return "";
#endif
}

std::vector<std::string> get_dns_servers() {
    std::vector<std::string> servers;
#ifdef NR_WIN
    int rc;
    std::string out = exec_cmd("ipconfig /all", &rc);
    std::istringstream ss(out);
    std::string line;
    bool cap = false;
    while (std::getline(ss, line)) {
        if (contains(line, "DNS Servers")) {
            cap = true;
            size_t c = line.rfind(':');
            if (c != std::string::npos) {
                std::string ip = trim(line.substr(c + 1));
                if (!ip.empty() && std::isdigit((unsigned char)ip[0])) servers.push_back(ip);
            }
        } else if (cap) {
            std::string t = trim(line);
            if (!t.empty() && std::isdigit((unsigned char)t[0])) servers.push_back(t);
            else cap = false;
        }
    }
#elif defined(NR_LINUX)
    int rc;
    std::string out = exec_cmd("resolvectl status 2>/dev/null", &rc);
    if (rc == 0 && !out.empty()) {
        std::istringstream ss(out);
        std::string line;
        while (std::getline(ss, line)) {
            if (contains(line, "DNS Servers") || contains(line, "Current DNS Server")) {
                for (size_t i = 0; i < line.size(); i++) {
                    if (std::isdigit((unsigned char)line[i])) {
                        size_t e = i;
                        while (e < line.size() && (std::isdigit((unsigned char)line[e]) || line[e] == '.')) e++;
                        std::string ip = line.substr(i, e - i);
                        if (ip.find('.') != std::string::npos) { servers.push_back(ip); break; }
                    }
                }
            }
        }
    }
    if (servers.empty()) {
        std::ifstream f("/etc/resolv.conf");
        std::string line;
        while (std::getline(f, line)) {
            if (starts_with(line, "nameserver")) {
                std::istringstream ss2(line);
                std::string ns, ip; ss2 >> ns >> ip;
                if (!ip.empty()) servers.push_back(ip);
            }
        }
    }
#elif defined(NR_MAC)
    int rc;
    std::string out = exec_cmd("scutil --dns", &rc);
    std::istringstream ss(out);
    std::string line;
    while (std::getline(ss, line)) {
        size_t p = line.find("nameserver[");
        if (p != std::string::npos) {
            size_t c = line.find(':', p);
            if (c != std::string::npos) {
                std::string ip = trim(line.substr(c + 1));
                if (std::find(servers.begin(), servers.end(), ip) == servers.end())
                    servers.push_back(ip);
            }
        }
    }
#endif
    return servers;
}

// ─── Connectivity Tests ───────────────────────────────────────────────────────
std::pair<bool, int> ping_host(const std::string& host, int count = 3) {
#ifdef NR_WIN
    std::string cmd = "ping -n " + std::to_string(count) + " -w 2000 " + host;
#else
    std::string cmd = "ping -c " + std::to_string(count) + " -W 2 " + host;
#endif
    auto t0 = std::chrono::steady_clock::now();
    int rc; exec_cmd(cmd, &rc);
    int ms = (int)std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - t0).count() / count;
    return {rc == 0, ms};
}

bool resolve_dns_test(const std::string& hostname = "google.com") {
    struct addrinfo hints = {}, *res = nullptr;
    hints.ai_family   = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    int rc = getaddrinfo(hostname.c_str(), nullptr, &hints, &res);
    if (rc == 0 && res) freeaddrinfo(res);
    return rc == 0;
}

bool check_https_port(const char* host = "1.1.1.1", int port = 443, int timeout_ms = 5000) {
#ifdef NR_WIN
    SOCKET s = socket(AF_INET, SOCK_STREAM, 0);
    if (s == INVALID_SOCKET) return false;
    u_long nb = 1; ioctlsocket(s, FIONBIO, &nb);
    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons(static_cast<u_short>(port));
    inet_pton(AF_INET, host, &addr.sin_addr);
    connect(s, (struct sockaddr*)&addr, sizeof(addr));
    fd_set wfds; FD_ZERO(&wfds); FD_SET(s, &wfds);
    struct timeval tv = {timeout_ms / 1000, (timeout_ms % 1000) * 1000};
    int r = select(0, nullptr, &wfds, nullptr, &tv);
    closesocket(s); return r > 0;
#else
    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) return false;
    int fl = fcntl(s, F_GETFL, 0);
    fcntl(s, F_SETFL, fl | O_NONBLOCK);
    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons(static_cast<uint16_t>(port));
    inet_pton(AF_INET, host, &addr.sin_addr);
    connect(s, (struct sockaddr*)&addr, sizeof(addr));
    fd_set wfds; FD_ZERO(&wfds); FD_SET(s, &wfds);
    struct timeval tv = {timeout_ms / 1000, (timeout_ms % 1000) * 1000};
    int r = select(s + 1, nullptr, &wfds, nullptr, &tv);
    close(s); return r > 0;
#endif
}

static bool is_apipa(const std::string& ip) {
    return !ip.empty() && starts_with(ip, "169.254.");
}

// ─── State & Issue Structs ────────────────────────────────────────────────────
struct FixSet {
    std::vector<std::string> win;
    std::vector<std::string> linux_c;
    std::vector<std::string> mac;
    const std::vector<std::string>& get() const {
#ifdef NR_WIN
        return win;
#elif defined(NR_MAC)
        return mac;
#else
        return linux_c;
#endif
    }
};

struct Issue {
    std::string severity;
    std::string title;
    std::string detail;
    std::string cause;
    std::string fix_explain;
    bool        auto_fix = false;
    FixSet      cmds;
};

struct NetState {
    std::string              local_ip, gateway, iface, wifi_service;
    std::vector<std::string> dns_servers;
    bool gw_ok=false, internet_ok=false, dns_ping_ok=false,
         dns_resolve=false, https_ok=false, healthy=false;
    int  gw_ms=0, internet_ms=0;
};

// ─── Issue Builder — avoids brace-init ambiguity ──────────────────────────────
static Issue make_issue(
    std::string sev, std::string title, std::string detail,
    std::string cause, std::string fix_expl, bool af,
    std::vector<std::string> win_c,
    std::vector<std::string> linux_c,
    std::vector<std::string> mac_c)
{
    Issue i;
    i.severity    = std::move(sev);
    i.title       = std::move(title);
    i.detail      = std::move(detail);
    i.cause       = std::move(cause);
    i.fix_explain = std::move(fix_expl);
    i.auto_fix    = af;
    i.cmds.win    = std::move(win_c);
    i.cmds.linux_c = std::move(linux_c);
    i.cmds.mac    = std::move(mac_c);
    return i;
}

// ─── Diagnostics ─────────────────────────────────────────────────────────────
static void print_step(const std::string& label, bool ok, int ms = -1) {
    std::string pad = label;
    while (pad.size() < 22) pad += ' ';
    std::cout << "  " << Col::DIM << pad << Col::X;
    if (ok) {
        std::cout << Col::G << "OK" << Col::X;
        if (ms >= 0) std::cout << "  " << Col::DIM << ms << "ms" << Col::X;
    } else {
        std::cout << Col::R << "FAIL" << Col::X;
    }
    std::cout << "\n";
}

NetState run_diagnostics(bool quiet = false) {
    NetState s;
    if (!quiet) std::cout << "\n" << Col::CY << "  Collecting system info..." << Col::X << "\n";

    auto timed = [](auto fn) -> std::pair<decltype(fn()), int> {
        auto t0 = std::chrono::steady_clock::now();
        auto r  = fn();
        int ms  = (int)std::chrono::duration_cast<std::chrono::milliseconds>(
                      std::chrono::steady_clock::now() - t0).count();
        return {r, ms};
    };

    { auto [v,ms] = timed([]{return get_local_ip();});   s.local_ip=v; if(!quiet) print_step("Local IP",   !v.empty(), ms); }
    { auto [v,ms] = timed([]{return get_gateway();});    s.gateway=v;  if(!quiet) print_step("Gateway",    !v.empty(), ms); }
    { auto [v,ms] = timed([]{return get_interface();}); s.iface=v;    if(!quiet) print_step("Interface",  !v.empty(), ms); }
    { auto [v,ms] = timed([]{return get_dns_servers();}); s.dns_servers=v; if(!quiet) print_step("DNS servers", !v.empty(), ms); }

#ifdef NR_MAC
    s.wifi_service = get_wifi_service();
#else
    s.wifi_service = "Wi-Fi";
#endif

    if (!quiet) std::cout << "\n" << Col::CY << "  Testing connectivity..." << Col::X << "\n";

    if (!s.gateway.empty()) {
        auto [ok,ms] = ping_host(s.gateway, 3);
        s.gw_ok=ok; s.gw_ms=ms;
        if (!quiet) print_step("Gateway " + s.gateway, ok, ms);
    } else if (!quiet) {
        std::cout << "  " << Col::DIM << "Gateway               " << Col::X
                  << Col::Y << "SKIP  (none found)" << Col::X << "\n";
    }
    { auto [ok,ms] = ping_host("1.1.1.1", 3); s.internet_ok=ok; s.internet_ms=ms; if(!quiet) print_step("Internet 1.1.1.1", ok, ms); }
    { auto [ok,ms] = ping_host("8.8.8.8", 2); s.dns_ping_ok=ok;                   if(!quiet) print_step("DNS server 8.8.8.8", ok, ms); }

    { auto [v,ms] = timed([]{return resolve_dns_test();}); s.dns_resolve=v; if(!quiet) print_step("DNS resolution", v, ms); }
    { auto [v,ms] = timed([]{return check_https_port();}); s.https_ok=v;    if(!quiet) print_step("HTTPS port 443",  v, ms); }

    nlog("State ip=" + s.local_ip + " gw=" + s.gateway + " gw_ok=" + (s.gw_ok?"1":"0")
         + " inet=" + (s.internet_ok?"1":"0") + " dns=" + (s.dns_resolve?"1":"0")
         + " https=" + (s.https_ok?"1":"0"));
    return s;
}

// ─── Analysis ─────────────────────────────────────────────────────────────────
std::vector<Issue> analyze(NetState& s) {
    std::vector<Issue> issues;
    const std::string iface = s.iface.empty()        ? "eth0"  : s.iface;
    const std::string wifi  = s.wifi_service.empty() ? "Wi-Fi" : s.wifi_service;

    if (s.local_ip.empty() || is_apipa(s.local_ip)) {
        if (is_apipa(s.local_ip)) {
            issues.push_back(make_issue(
                "critical",
                "DHCP failure — APIPA address assigned (" + s.local_ip + ")",
                "Your IP " + s.local_ip + " is a 169.254.x.x self-assigned fallback. "
                "DHCP server (your router) did not respond. Nothing is reachable.",
                "Router DHCP not responding, or adapter didn't request an address correctly.",
                "Release the bad lease, reset Winsock/TCP-IP stack, force fresh DHCP.",
                true,
                {"ipconfig /release", "netsh winsock reset", "netsh int ip reset",
                 "ipconfig /flushdns", "ipconfig /renew"},
                {"sudo ip addr flush dev " + iface,
                 "sudo systemctl restart NetworkManager || sudo dhclient " + iface},
                {"sudo ipconfig set " + iface + " DHCP",
                 "sudo dscacheutil -flushcache",
                 "sudo killall -HUP mDNSResponder"}
            ));
        } else {
            issues.push_back(make_issue(
                "critical",
                "No IP address — adapter inactive or driver missing",
                "No active network interface found. Adapter may be disabled, driver missing, or not connected.",
                "Disabled adapter, missing driver, or no physical connection.",
                "Enable the network adapter and restart the network stack.",
                true,
                {"netsh int set interface \"Ethernet\" admin=enabled",
                 "netsh int set interface \"Wi-Fi\" admin=enabled",
                 "ipconfig /renew"},
                {"sudo ip link set " + iface + " up",
                 "sudo systemctl restart NetworkManager"},
                {"networksetup -setnetworkserviceenabled " + wifi + " on",
                 "networksetup -setdhcp " + wifi}
            ));
        }
        return issues;
    }

    if (s.gateway.empty()) {
        issues.push_back(make_issue(
            "critical",
            "No default gateway — routing table empty",
            "IP is " + s.local_ip + " but no default gateway exists. "
            "Can reach local devices only, nothing outside the subnet.",
            "DHCP didn't provide a gateway, or routing table was corrupted.",
            "Reset routing table and get a new DHCP lease with gateway.",
            true,
            {"netsh int ip reset", "ipconfig /release", "ipconfig /renew"},
            {"sudo ip route flush table main",
             "sudo dhclient -r", "sudo dhclient " + iface},
            {"sudo route flush", "sudo ipconfig set " + iface + " DHCP"}
        ));
        return issues;
    }

    if (!s.gw_ok) {
        issues.push_back(make_issue(
            "critical",
            "Router not responding (" + s.gateway + ")",
            "Gateway " + s.gateway + " is in routing table but doesn't reply to pings. "
            "Likely: wrong cable port, Wi-Fi dropped, router frozen, or ICMP blocked.",
            "Physical connection issue or router is down/frozen.",
            "Clear ARP cache and re-request DHCP. If still failing, check cable or Wi-Fi.",
            true,
            {"arp -d *", "ipconfig /release", "ipconfig /renew"},
            {"sudo ip neigh flush all", "sudo dhclient -r",
             "sudo dhclient " + iface},
            {"sudo arp -d -a", "sudo ipconfig set " + iface + " DHCP"}
        ));
        return issues;
    }

    if (!s.internet_ok) {
        issues.push_back(make_issue(
            "critical",
            "No internet — router up but WAN is dead",
            "Gateway " + s.gateway + " responds but 1.1.1.1 (Cloudflare) doesn't. "
            "Router has no WAN connection, or firewall blocks all outbound traffic.",
            "ISP outage, router WAN config failure, or firewall blocking egress.",
            "Reset firewall to defaults and clear proxy. If persists, restart router/modem.",
            true,
            {"netsh advfirewall reset", "netsh winhttp reset proxy", "ipconfig /flushdns"},
            {"sudo iptables -F", "sudo iptables -P INPUT ACCEPT",
             "sudo iptables -P FORWARD ACCEPT", "sudo iptables -P OUTPUT ACCEPT"},
            {"sudo pfctl -d", "sudo dscacheutil -flushcache",
             "sudo killall -HUP mDNSResponder"}
        ));
        return issues;
    }

    if (!s.dns_resolve) {
        std::string dns_str = s.dns_servers.empty() ? "none detected" : "";
        for (size_t i = 0; i < s.dns_servers.size(); i++) {
            if (i) dns_str += ", ";
            dns_str += s.dns_servers[i];
        }
        issues.push_back(make_issue(
            "high",
            "DNS resolution broken — can't resolve hostnames",
            "Internet works (1.1.1.1 replies in " + std::to_string(s.internet_ms) + "ms) "
            "but hostname lookups fail. DNS: " + dns_str
            + ". Browsers show DNS_PROBE_FINISHED_NXDOMAIN.",
            "Corrupted DNS cache, wrong DNS server, or ISP DNS blocking.",
            "Flush DNS cache and switch to Cloudflare (1.1.1.1) + Google (8.8.8.8).",
            true,
            {"ipconfig /flushdns",
             "powershell -Command \"Get-NetAdapter | Where-Object Status -eq Up | "
             "Set-DnsClientServerAddress -ServerAddresses 1.1.1.1,8.8.8.8\""},
            {"sudo resolvectl flush-caches 2>/dev/null || true",
             "sudo sh -c \"echo nameserver 1.1.1.1 > /etc/resolv.conf\"",
             "sudo sh -c \"echo nameserver 8.8.8.8 >> /etc/resolv.conf\""},
            {"sudo dscacheutil -flushcache", "sudo killall -HUP mDNSResponder",
             "networksetup -setdnsservers " + wifi + " 1.1.1.1 8.8.8.8"}
        ));
    }

    if (s.dns_resolve && !s.https_ok) {
        issues.push_back(make_issue(
            "high",
            "HTTPS (port 443) blocked",
            "DNS and ping work but TCP port 443 is blocked. Likely: corporate proxy, "
            "VPN split-tunnel, antivirus SSL inspection, or firewall blocking 443.",
            "Proxy config, VPN, or firewall blocking outbound port 443.",
            "Reset proxy settings and allow port 443 outbound.",
            true,
            {"netsh winhttp reset proxy",
             "reg delete \"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion"
             "\\Internet Settings\" /v ProxyEnable /f",
             "reg delete \"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion"
             "\\Internet Settings\" /v ProxyServer /f",
             "netsh advfirewall firewall add rule name=\"Allow HTTPS Out\" "
             "protocol=TCP dir=out remoteport=443 action=allow"},
            {"unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY",
             "sudo iptables -I OUTPUT -p tcp --dport 443 -j ACCEPT"},
            {"networksetup -setsecurewebproxystate " + wifi + " off",
             "networksetup -setwebproxystate " + wifi + " off",
             "networksetup -setsocksfirewallproxystate " + wifi + " off"}
        ));
    }

    if (s.internet_ok && s.internet_ms > 150) {
        issues.push_back(make_issue(
            "warning",
            "High latency (" + std::to_string(s.internet_ms) + "ms to 1.1.1.1)",
            "Everything works but latency is " + std::to_string(s.internet_ms)
            + "ms. Normal: <30ms fibre, <80ms mobile. Causes: congestion, VPN, Wi-Fi interference.",
            "Network congestion, VPN overhead, or Wi-Fi issues.",
            "Flush DNS. If on Wi-Fi, move closer to router or switch to 5GHz band.",
            true,
            {"ipconfig /flushdns",
             "powershell -Command \"Get-NetAdapter | Where-Object Status -eq Up | "
             "Set-DnsClientServerAddress -ServerAddresses 1.1.1.1,8.8.8.8\""},
            {"sudo resolvectl flush-caches 2>/dev/null || true"},
            {"sudo dscacheutil -flushcache", "sudo killall -HUP mDNSResponder"}
        ));
    }

    s.healthy = issues.empty();
    return issues;
}

// ─── Report ───────────────────────────────────────────────────────────────────
static const std::map<std::string, std::string> SEV_COL = {
    {"critical", Col::R}, {"high", Col::Y}, {"warning", Col::Y}, {"info", Col::CY}
};

void print_report(const NetState& s, const std::vector<Issue>& issues) {
    std::string ip_str = s.local_ip.empty()  ? "no IP"      : s.local_ip;
    std::string gw_str = s.gateway.empty()   ? "no gateway" : s.gateway;

    std::cout << "\n" << std::string(54, '=') << "\n"
              << Col::B << "  DIAGNOSIS REPORT" << Col::X
              << "  —  " << OS_LABEL << "\n"
              << "  IP: " << ip_str << "   GW: " << gw_str << "\n"
              << std::string(54, '=') << "\n";

    if (issues.empty()) {
        std::cout << "\n  " << Col::G << "v  No issues found. Network is healthy." << Col::X << "\n";
        return;
    }

    for (size_t i = 0; i < issues.size(); i++) {
        const Issue& iss = issues[i];
        std::string col = SEV_COL.count(iss.severity) ? SEV_COL.at(iss.severity) : Col::Y;
        std::string sev = iss.severity;
        std::transform(sev.begin(), sev.end(), sev.begin(), ::toupper);

        std::cout << "\n  " << col << "+- [" << sev << "] " << iss.title << Col::X << "\n"
                  << "  " << col << "|" << Col::X << "  " << iss.detail << "\n"
                  << "  " << col << "|" << Col::X << "\n"
                  << "  " << col << "|" << Col::X << "  " << Col::B << "Root cause:"
                  << Col::X << "  " << iss.cause << "\n"
                  << "  " << col << "|" << Col::X << "  " << Col::B << "Fix:"
                  << Col::X << "         " << iss.fix_explain << "\n"
                  << "  " << col << "|" << Col::X << "\n"
                  << "  " << col << "|" << Col::X << "  "
                  << Col::CY << "Commands (" << OS_LABEL << "):" << Col::X << "\n";

        for (const auto& cmd : iss.cmds.get()) {
            if (!cmd.empty() && cmd[0] == '#')
                std::cout << "  " << col << "|" << Col::X << "    " << Col::DIM << cmd << Col::X << "\n";
            else
                std::cout << "  " << col << "|" << Col::X << "    " << Col::Y << cmd << Col::X << "\n";
        }
        std::cout << "  " << col << "+" << std::string(50, '-') << Col::X << "\n";
        nlog("ISSUE " + std::to_string(i+1) + ": [" + sev + "] " + iss.title);
    }
}

// ─── Auto-Fix ─────────────────────────────────────────────────────────────────
void auto_fix(const std::vector<Issue>& issues) {
    if (!is_root()) {
        std::cout << "\n  " << Col::R << "[!]" << Col::X
                  << " Auto-fix requires admin/root privileges.\n";
#ifdef NR_WIN
        std::cout << "      Right-click -> Run as administrator.\n";
#else
        std::cout << "      Run: sudo netrepair fix\n";
#endif
        return;
    }
    bool fixed_any = false;
    for (const auto& iss : issues) {
        if (!iss.auto_fix) continue;
        const auto& cmds = iss.cmds.get();
        if (cmds.empty()) continue;
        std::string col = SEV_COL.count(iss.severity) ? SEV_COL.at(iss.severity) : Col::Y;
        std::cout << "\n  " << col << "Fixing:" << Col::X
                  << " " << Col::B << iss.title << Col::X << "\n";
        for (const auto& cmd : cmds) {
            if (!cmd.empty() && cmd[0] == '#') {
                std::cout << "  " << Col::DIM << cmd << Col::X << "\n"; continue;
            }
            std::cout << "\n  " << Col::Y << ">" << Col::X << " " << cmd << "\n";
            int rc = exec_live(cmd);
            if (rc == 0) std::cout << "  " << Col::G << "[OK]" << Col::X << "\n";
            else         std::cout << "  " << Col::Y << "[done - exit " << rc << "]" << Col::X << "\n";
        }
        std::cout << "  " << Col::G << "v Applied" << Col::X << "\n";
        fixed_any = true;
    }
    if (fixed_any)
        std::cout << "\n  " << Col::G << "All available fixes applied." << Col::X << "\n"
                  << "  " << Col::DIM << "A restart may be required for some changes." << Col::X << "\n";
    else
        std::cout << "\n  " << Col::DIM << "Nothing to fix." << Col::X << "\n";
}

// ─── Backup ───────────────────────────────────────────────────────────────────
void backup() {
    std::string fname = "netconfig_" + now_str("%Y%m%d_%H%M%S") + ".txt";
    std::cout << "\n  Exporting to " << fname << "...\n";
    std::ofstream f(fname);
    if (!f) { std::cout << "  " << Col::R << "[FAIL]" << Col::X << " Cannot create file.\n"; return; }
    f << "Network Config Backup — " << now_str("%Y-%m-%d %H:%M:%S") << "\nOS: " << OS_LABEL << "\n"
      << std::string(54, '=') << "\n";

    using P = std::pair<std::string,std::string>;
    std::vector<P> cmds;
#ifdef NR_WIN
    cmds = {{"ipconfig /all","IP Config"},{"route print","Routes"},
            {"netsh int ip show config","TCP/IP"},{"netsh winsock show catalog","Winsock"},
            {"netsh advfirewall show allprofiles","Firewall"},{"ipconfig /displaydns","DNS Cache"}};
#elif defined(NR_MAC)
    cmds = {{"ifconfig","Interfaces"},{"netstat -rn","Routes"},
            {"scutil --dns","DNS"},{"networksetup -listallhardwareports","Ports"},
            {"pfctl -s rules 2>/dev/null","Firewall"}};
#else
    cmds = {{"ip addr show","Interfaces"},{"ip route show","Routes"},
            {"cat /etc/resolv.conf","DNS Config"},{"ss -tlnp","Ports"},
            {"iptables -L -n 2>/dev/null","Firewall"}};
#endif
    for (const auto& [cmd, label] : cmds) {
        f << "\n-- " << label << " --\n";
        int rc; f << exec_cmd(cmd, &rc) << "\n";
        std::cout << "  " << Col::DIM << label << Col::X << " ... " << Col::G << "done" << Col::X << "\n";
    }
    std::cout << "  " << Col::G << "[OK]" << Col::X << " " << fname << "\n";
    nlog("BACKUP: " + fname);
}

// ─── Help ─────────────────────────────────────────────────────────────────────
void print_help() {
    std::cout << "\n"
              << Col::CY << "  NetRepair v3.0  —  VortexDQ Corporation\n" << Col::X
              << "  Platforms: Windows  Linux  macOS\n\n"
              << Col::B << "  Usage:\n" << Col::X
              << "    netrepair              Interactive menu\n"
              << "    netrepair scan         Diagnose and show report\n"
              << "    netrepair fix          Scan then apply auto-fixes (prompts)\n"
              << "    netrepair auto         Full silent scan + fix (no prompts)\n"
              << "    netrepair backup       Export current network config\n"
              << "    netrepair help         Show this help\n\n"
              << Col::B << "  Exit codes:\n" << Col::X
              << "    0  Healthy (or fixes applied)\n"
              << "    1  Issues found, no fix attempted\n"
              << "    2  Error / bad arguments\n\n";
}

// ─── Interactive Menu ─────────────────────────────────────────────────────────
void print_menu() {
    std::string priv = is_root()
        ? Col::G + "Admin/Root" + Col::X
        : Col::Y + "User (limited)" + Col::X;
    std::cout << "\n" << Col::CY << std::string(54, '=') << "\n"
              << "  NetRepair v3.0  .  VortexDQ Corporation\n"
              << "  OS: " << OS_LABEL << "   Privileges: " << priv << Col::CY << "\n"
              << std::string(54, '=') << Col::X << "\n\n"
              << "  " << Col::B << "1" << Col::X << "   Scan          Diagnose and report issues\n"
              << "  " << Col::B << "2" << Col::X << "   Scan + Fix    Diagnose then apply auto-fixes\n"
              << "  " << Col::B << "3" << Col::X << "   Fix Now       Skip scan, run all fixes\n"
              << "  " << Col::B << "4" << Col::X << "   Backup        Export network config\n"
              << "  " << Col::B << "5" << Col::X << "   Exit\n\n";
}

void wait_enter() {
    std::cout << "\n  " << Col::DIM << "Press Enter to continue..." << Col::X;
    std::cin.ignore(10000, '\n');
}

// ─── main ─────────────────────────────────────────────────────────────────────
int main(int argc, char* argv[]) {
    enable_ansi();
    sock_init();
    g_log_file = "netrepair_" + now_str("%Y%m%d_%H%M%S") + ".log";

    if (argc >= 2) {
        std::string cmd = argv[1];
        if (cmd == "help" || cmd == "--help" || cmd == "-h") {
            print_help(); sock_cleanup(); return 0;
        }
        if (cmd == "backup") {
            backup(); save_log(); sock_cleanup(); return 0;
        }
        if (cmd == "scan" || cmd == "fix" || cmd == "auto") {
            bool do_fix = (cmd == "fix" || cmd == "auto");
            bool quiet  = (cmd == "auto");
            if (!quiet)
                std::cout << "\n" << Col::CY
                          << "  NetRepair v3.0  —  VortexDQ Corporation" << Col::X << "\n";
            NetState s = run_diagnostics(quiet);
            auto issues = analyze(s);
            print_report(s, issues);
            if (do_fix && !issues.empty()) {
                if (cmd == "fix") {
                    std::cout << "\n  " << Col::Y << "Apply all auto-fixes? (Y/N): " << Col::X;
                    char yn; std::cin >> yn;
                    if (yn == 'Y' || yn == 'y') auto_fix(issues);
                } else {
                    auto_fix(issues);
                }
            }
            save_log(); sock_cleanup();
            return issues.empty() ? 0 : 1;
        }
        std::cerr << "Unknown command: " << cmd << "\n";
        print_help(); sock_cleanup(); return 2;
    }

    while (true) {
#ifdef NR_WIN
        (void)std::system("cls");
#else
        { int _r = std::system("clear"); (void)_r; }
#endif
        print_menu();
        std::cout << "  Choice: ";
        std::string choice;
        std::getline(std::cin, choice);
        choice = trim(choice);

        if (choice == "1") {
            NetState s = run_diagnostics();
            auto issues = analyze(s);
            print_report(s, issues);
            save_log(); wait_enter();
        } else if (choice == "2") {
            NetState s = run_diagnostics();
            auto issues = analyze(s);
            print_report(s, issues);
            if (!issues.empty()) {
                std::cout << "\n  " << Col::Y << "Apply all auto-fixes? (Y/N): " << Col::X;
                std::string yn; std::getline(std::cin, yn);
                if (!yn.empty() && (yn[0]=='Y'||yn[0]=='y')) auto_fix(issues);
            }
            save_log(); wait_enter();
        } else if (choice == "3") {
            if (!is_root()) {
                std::cout << "\n  " << Col::R << "[!]" << Col::X
                          << " Requires admin/root.\n";
#ifndef NR_WIN
                std::cout << "      sudo netrepair fix\n";
#endif
                wait_enter(); continue;
            }
            NetState s = run_diagnostics();
            auto issues = analyze(s);
            auto_fix(issues);
            save_log(); wait_enter();
        } else if (choice == "4") {
            backup(); save_log(); wait_enter();
        } else if (choice == "5" || choice == "q" || choice == "exit") {
            save_log(); sock_cleanup(); return 0;
        }
    }
}
