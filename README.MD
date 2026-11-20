# Xray-core Home Assistant Add-on

Run an Xray-core **VLESS + REALITY** server on Home Assistant. Keys are
generated automatically, and the add-on's **Open Web UI** page shows a QR code you can scan into
V2Box (iPhone), v2rayNG (Android), Shadowrocket and similar clients. See
[Client apps](#client-apps).

## Install

1. In Home Assistant go to **Settings → Add-ons → Add-on Store**.
2. Open the **⋮** menu → **Repositories**, add
   `https://github.com/vh13294/xray-core-addon` and click **Add**.
3. Refresh the store, open **Xray-core** and click **Install**. The first
   install builds the image on your machine and takes a few minutes.
4. On the **Configuration** tab, set `server_address` to a hostname (DDNS or
   your ISP's) and save. See [DOMAIN-DDNS.md](DOMAIN-DDNS.md).
5. Click **Start**, then **Open Web UI** and scan the QR code.
6. Forward TCP 443 on your router to Home Assistant.

**Use a domain, not an IP.** A hostname keeps your QR code working when your
IP changes. [DOMAIN-DDNS.md](DOMAIN-DDNS.md) covers both cases:

- **Public IP:** DDNS (Omada or Duck DNS) with port 443.
- **No public IP (Ezecom):** Ezecom's hostname with a forwarded port such as
  8082.

Full option reference and TP-Link Omada router steps:
[xray-core/DOCS.md](xray-core/DOCS.md).

## Client apps

| Phone | App | Notes |
|---|---|---|
| iPhone | **V2Box** (free) | Tested: imports the link and connects. Recommended settings for China: [V2BOX.md](V2BOX.md). |
| iPhone | Shadowrocket (paid) | Popular, supports REALITY. |
| Android | **v2rayNG** (free) | The standard Android Xray client. |
| Any | Hiddify (free) | iPhone, Android, Windows and Mac. |

Floxcore rejected these links in testing, both by QR code and clipboard, so
use one of the apps above.

Import by scanning the QR code on **Open Web UI**, or copy the `vless://`
link and use the app's **Import from clipboard**. Install the app **before**
travelling to China: VPN apps aren't available in Chinese app stores.

## Rotating keys (if the QR code leaks)

Your keys are saved in the add-on's private storage. Restarting the add-on,
restarting Home Assistant, rebooting or updating does **not** change them.
Treat the QR code and `vless://` link like a password: anyone who has them
can use your proxy.

**Rotate (recommended).** Gives you a new UUID, REALITY key pair and short ID
and keeps all your settings.

1. On the add-on's **Configuration** tab, turn on `rotate_keys`, then
   **Save** and **Restart** the add-on.
2. The add-on generates new keys and switches `rotate_keys` back off by
   itself. Reload the Configuration tab to see it off.
3. Open **Web UI**, rescan the new QR code, and delete the old profile from
   your phone.

Keys are rotated only **once** each time you switch the option on. If the
add-on can't switch it back off, later restarts keep the new keys, and the
log asks you to turn `rotate_keys` off. If `uuid` or `short_id` are filled in
on the Configuration tab, those values are kept, so clear them first.

**Full reset (reinstall).** Gives the same new keys but also clears every
setting. Only needed if something is broken.

1. Note your settings (`server_address`, `public_port`, `sni`). Uninstalling
   deletes them.
2. **Uninstall** the add-on, then **Install** it again.
3. Re-enter your settings, start it, and rescan the QR code from **Open Web
   UI**.

Avoid leaks in the first place. Don't post screenshots of the QR code or the
add-on log (the log also shows the link), and remember that anyone with admin
access to Home Assistant can see both.

## Avoiding blocks (lessons learned)

A previous setup that impersonated `www.apple.com` from a Metfone home IP was
blocked within a day. In short:

- **SNI should be close to your network.** The default `itc.edu.kh` is a
  Cambodian site on its own Cambodian network, chosen for a Cambodian home
  connection. Metfone's own sites only support TLS 1.2, so they can't be
  used. Pick a site hosted in your own country, not on a CDN and not a big
  brand or `.cn` domain.
- **Check the SNI** isn't blocked on https://www.chinafirewalltest.com. The
  add-on log checks TLS 1.3, HTTP/2 and the certificate on every start, and
  prints an ERROR if the SNI can't work.
- **Unique, random keys per server**, never shared or reused.
- **Light usage**, a **backup route**, and **test before you travel**.

The full checklist is in [xray-core/DOCS.md](xray-core/DOCS.md#choosing-the-sni).

## Advanced

Paste a complete Xray JSON config into `core_config` to skip REALITY mode.
See [example.config.yaml](example.config.yaml).
