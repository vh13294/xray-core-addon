# Xray-core Home Assistant Add-on

Run an Xray-core **VLESS + REALITY** server on Home Assistant. Keys are
generated automatically, and the add-on log shows a QR code you can scan into
Floxcore, v2rayN, Shadowrocket and similar clients.

## Install

1. In Home Assistant go to **Settings → Add-ons → Add-on Store**.
2. Open the **⋮** menu → **Repositories**, add
   `https://github.com/vh13294/xray-core-addon` and click **Add**.
3. Refresh the store, open **Xray-core** and click **Install**. The first
   install builds the image on your machine and takes a few minutes.
4. On the **Configuration** tab, set `server_address` to your DDNS hostname or
   public IP and save.
5. Click **Start**, then open the **Log** tab and scan the QR code.
6. Forward TCP 443 on your router to Home Assistant.

Full option reference and TP-Link Omada router steps:
[xray-core/DOCS.md](xray-core/DOCS.md).

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
