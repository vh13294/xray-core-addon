# V2Box settings for China (iPhone)

Recommended V2Box settings for this add-on (VLESS + REALITY + Vision) when
travelling in mainland China. Most defaults are fine. Option names can differ
slightly between V2Box versions.

## Import the config

1. In the add-on, click **Open Web UI**.
2. In V2Box, scan the QR code, or copy the `vless://` link and use
   **+ → Import from clipboard**.
3. Install V2Box **before** you travel: VPN apps aren't available in Chinese
   app stores.

## Must change

### Routing rules

**Settings → Routing**. The rules below come with V2Box but are switched off
by default. Turn them on, and add two China rules, in this order:

| # | Rule | Match | Action | Why |
|---|---|---|---|---|
| 1 | 阻断 udp443 | UDP port 443 | **block** | Blocks QUIC so apps fall back to TCP. Vision is built for TCP, and QUIC through the proxy is slow or fails. |
| 2 | 绕过局域网 IP | `geoip:private` | **direct** | The server refuses LAN traffic on purpose. Without this, local network access breaks while the VPN is on. |
| 3 | 绕过局域网域名 | `geosite:private` | **direct** | Same as above, for local hostnames. |
| 4 | *(add)* | `geosite:cn` | **direct** | Chinese sites skip the proxy. |
| 5 | *(add)* | `geoip:cn` | **direct** | Chinese IPs skip the proxy. |

Rules 4 and 5 send WeChat, Alipay, Didi, Baidu and maps direct. That makes
them faster, avoids problems some Chinese apps have with foreign IPs, and
keeps traffic through your home server light, which lowers the risk of a
block. Everything else (Google, YouTube, WhatsApp) still goes through the
proxy.

### Mux: keep OFF

**Settings → Tunnel Settings → Mux** must stay **off**. Mux doesn't work with
the `xtls-rprx-vision` flow this server uses.

## Recommended

**Settings → DNS**:

- **DNS server:** select **`DoH: 1.1.1.1`** instead of `DoU: 1.1.1.1`. Plain
  UDP DNS is easy for the firewall to tamper with; DoH is encrypted.
- **Remote/Domestic Servers:** if offered:
  - **Remote:** `DoH: 1.1.1.1`, encrypted, for foreign sites.
  - **Domestic:** `DoU: 223.5.5.5` (AliDNS, plain UDP) so Chinese sites
    resolve correctly. Lookups for Chinese domains aren't tampered with, and
    UDP is fastest. `DoH: https://223.5.5.5/dns-query` also works.
  - **Avoid DoT.** It uses port 853, which is easy to spot and often blocked
    or throttled in China. DoH looks like normal HTTPS.
- **Query Strategy:** `UseIPv4`. The server is IPv4-only, so this avoids
  wasted IPv6 attempts.
- **FakeDNS:** on is fine.

## Leave as default

| Setting | Value | Note |
|---|---|---|
| Domain Strategy | `AsIs` | Fine with Route Only on. |
| Route Only | on | Fine. |
| Apple on direct | either | Optional. On sends App Store and iCloud direct, which works in China and saves proxy traffic. |
| Enable Fragmentation | off | REALITY doesn't need it. |
| AllowInsecure | off | Never turn this on. |
| Prefer IPv6 | off | The server is IPv4-only. |
| Use Xray TUN | off | Not needed. |
| XHTTP Optimization | any | Not used: this server uses TCP + Vision, not XHTTP. |
| Memory limit | 30 MB | Lower it only if V2Box keeps stopping. |
| Stop on sleep | off | Keeps the VPN up when the screen locks. |
| Kill Switch | off | In China it would also cut WeChat and Alipay whenever the VPN drops, and those work without a VPN. |
| Include All / Local Networks, Enforce Routes, APNs | default | Fine. |

## Test

**Before you travel** (Cambodia, on mobile data, not home Wi-Fi):

1. Connect in V2Box.
2. Open https://api.ipify.org. It should show your **home** IP, which means
   traffic is going through the proxy.

**In China:**

- Baidu and WeChat should load fast (direct).
- Google and YouTube should work (through the proxy).

If nothing connects, the server's IP may be blocked. See
[DOMAIN-DDNS.md](DOMAIN-DDNS.md) for using a hostname, and
[README.MD](README.MD#rotating-keys-if-the-qr-code-leaks) for rotating keys.
