# Xray-core add-on

Runs an [Xray-core](https://github.com/XTLS/Xray-core) server using
**VLESS + REALITY + Vision**. It needs no domain and no certificate, and it is
the hardest common setup for firewalls to fingerprint.

On first start the add-on generates a client UUID, a REALITY key pair and a
short ID. It keeps them in `/data`, so they survive restarts and updates. It
then prints a `vless://` share link and a **QR code** in the **Log** tab. Scan
that QR code in Floxcore (or v2rayN, Shadowrocket, etc.).

## Options

| Option | Default | What it does |
|---|---|---|
| `server_address` | *(empty)* | Your public hostname (DDNS) or IP, put in the share link. If empty, the add-on detects your public IP. |
| `public_port` | `443` | The port clients connect to, i.e. the **external** port on your router. |
| `sni` | `www.metfone.com.kh` | The site REALITY impersonates. Read **Choosing the SNI** below before changing it. |
| `client_name` | `phone` | Label shown in the client app. |
| `uuid` | *(auto)* | Set it only if you want a specific UUID. |
| `short_id` | *(auto)* | 0–16 hex characters. Auto-generated if empty. |
| `fingerprint` | `chrome` | uTLS fingerprint the client uses. |
| `log_level` | `warning` | Xray log level. |
| `core_config` | *(empty)* | **Advanced.** Paste a full Xray JSON config to bypass REALITY mode. The inbound must listen on port 443 inside the container. |

To rotate all keys (for example after an IP block), **uninstall and reinstall**
the add-on, which clears its `/data`. Then rescan the new QR code.

## Router setup (TP-Link Omada)

1. **Give Home Assistant a fixed IP.** In the Omada Controller go to
   **Clients**, click your HA device, open **Config** and enable
   **Use Fixed IP Address** (for example `192.168.0.10`).
2. **Check you have a real public IP (no CGNAT).** Compare the gateway's WAN
   IP on the Omada **Dashboard** with what https://api.ipify.org shows. If the
   WAN IP starts with `100.64`–`100.127`, `10.` or `172.16`–`172.31`, your ISP
   uses CGNAT. Ask them for a public IP; port forwarding cannot work without one.
3. **Forward the port.** Go to **Settings → Transmission → NAT → Port
   Forwarding** (newer controllers: **Network Config → Transmission → NAT**) and
   create a rule:
   - Interface: your WAN
   - Source IP: Any
   - External port: `443`
   - Internal IP: your HA IP
   - Internal port: `443`
   - Protocol: TCP

   If the gateway's own remote management already uses WAN port 443, either
   turn that off or use another external port (for example `8443`) and set
   `public_port` to match.
4. **Set up dynamic DNS** so the link survives IP changes. Use the gateway's
   **Settings → Services → Dynamic DNS** (No-IP, DynDNS, etc.) or the official
   Home Assistant **Duck DNS** add-on. Put the hostname in `server_address`.

## Testing

From a phone on **mobile data** (not your home Wi-Fi), import the QR code into
Floxcore and connect. Then open https://api.ipify.org: it should show your
home IP.

## Choosing the SNI

REALITY makes your server look like the `sni` site. A firewall can compare
the site's real IPs with yours, so the closer the match, the safer you are.

**What went wrong before:** an earlier setup impersonated `www.apple.com`
(plus `www.apple.com.cn`) from a Metfone home IP and a Vultr IP. Apple's IP
ranges are well known, so a random IP serving an apple.com certificate is an
easy mismatch, and a `.cn` name on a foreign IP is worse. That IP was blocked
within a day.

**The default `www.metfone.com.kh`** suits a server on a **Metfone** home
connection, because your IP and the site are on the same network. On any
other ISP or VPS, pick a site hosted on *that* provider's network instead.

A good `sni` passes all of these checks:

1. **Hosted on your provider's network, not a CDN.**
   ```
   dig +short www.metfone.com.kh
   whois <that IP> | grep -iE 'netname|descr|origin'
   ```
   It should show your ISP or host. Cloudflare, Akamai, AWS and similar
   CDNs are a fail.
2. **Supports TLS 1.3 + HTTP/2.** The add-on log shows this on every start,
   via a `curl` check and `xray tls ping`. The certificate must cover the
   hostname.
3. **Not blocked in China.** Test it on
   https://www.chinafirewalltest.com and on itdog.cn's HTTP test. Most nodes
   should load it.
4. **Not a big brand.** Avoid Apple, Microsoft, Google, Amazon, Cloudflare
   and any `.cn` domain. The add-on log warns if you use one.

## Staying unblocked

- **Unique keys per server.** Never copy the same UUID, private key, short ID
  or path between servers. If one is flagged, the others are easy to link.
  This add-on generates fresh random values for each install.
- **Random short IDs.** Not `00` / `01` / `02`. Leave `short_id` empty to get
  a random 16-hex one.
- **Never share configs.** Treat the share link and QR code like a password.
  If they leak, reinstall the add-on to rotate.
- **Keep usage light.** No long video sessions, and don't share with many
  people.
- **Keep a backup route** on a different network, such as a VPS in Hong Kong
  or Japan, or a Cloudflare-fronted fallback, so one block doesn't cut you off.
- **Test before you travel.** Connect from mobile data a few days before
  flying, and re-check the SNI site on chinafirewalltest.com.
- **If you get blocked:** reboot the router for a new Metfone IP (if your IP
  is dynamic), reinstall the add-on for new keys, and reconsider the SNI.
- **LAN is blocked by default.** The server refuses connections to private IP
  ranges, so the proxy can't be used to reach Home Assistant, your NAS or the
  router.
