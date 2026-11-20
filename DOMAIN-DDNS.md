# Using a domain instead of an IP

Put a **hostname** in `server_address`, not an IP. The QR code contains
whatever you put there, so with a hostname it keeps working when your ISP
changes your IP, and you never have to rescan after a router reboot.

Pick the option that matches your connection:

- **You have a public IP** (no CGNAT): use [DDNS](#option-a-ddns-public-ip).
- **You have no public IP**, for example Ezecom home plans: use the
  [Ezecom hostname](#option-b-ezecom-hostname-no-public-ip).

To check for CGNAT, compare your router's WAN IP with what
https://api.ipify.org shows. If the WAN IP starts with `100.64`–`100.127`,
`10.` or `172.16`–`172.31`, you are behind CGNAT and have no public IP.

## Option A: DDNS (public IP)

1. **Get a DDNS hostname** that follows your IP:
   - TP-Link Omada: **Settings → Services → Dynamic DNS** (No-IP, DynDNS,
     etc.), or
   - the official Home Assistant **Duck DNS** add-on (`yourname.duckdns.org`).
2. **Forward TCP 443** on your router → your Home Assistant IP, port `443`.
   See [xray-core/DOCS.md](xray-core/DOCS.md#router-setup-tp-link-omada).
3. **Configure the add-on:**
   ```yaml
   server_address: yourname.duckdns.org
   public_port: 443
   ```
4. Restart and rescan the QR code from **Open Web UI**.

If your IP gets blocked, reboot the router for a new IP (if your ISP gives
dynamic IPs). The hostname follows the new IP and the same QR code keeps
working.

## Option B: Ezecom hostname (no public IP)

Ezecom home plans usually have no public IP, but Ezecom can give you a
hostname with a few forwarded ports (for example 8081 and 8082), the same
setup used to view CCTV cameras remotely. You can use that hostname instead
of an IP. It also helps if your old IP was blocked, because it's a different
ISP and IP.

1. **Free up one port.** Keep the cameras on one port (for example 8081) and
   use another (for example 8082) for Xray, or ask Ezecom for an extra port.
2. **Check it isn't blocked.** Look up the hostname's IP
   (`nslookup <your-ezecom-hostname>`) and run itdog.cn's TCP ping against it
   on your port.
3. **Forward the port.** On the router the Ezecom line goes through, forward
   TCP `8082` → your Home Assistant IP, port `443`.
4. **Configure the add-on:**
   ```yaml
   server_address: <your-ezecom-hostname>   # the domain, not an IP
   public_port: 8082
   ```
   Use the domain, not the IP it resolves to. Ezecom keeps the domain pointing
   at the right IP, so your QR code keeps working when the IP changes.
5. **Test from outside.** On a phone using mobile data, open
   `https://<your-ezecom-hostname>:8082` in a browser. If you see a
   certificate for your `sni` site (for example `itc.edu.kh`), the forward
   works. A camera page, an Ezecom page or a timeout means Ezecom isn't
   forwarding raw TCP on that port, so ask them.
6. Rescan the QR code from **Open Web UI** in your client app.

Things to know:

- Ezecom's IP may be **shared** with other customers. If it gets blocked
  because of someone else, you lose it too.
- A port other than 443 is slightly easier to spot than 443. Keep usage light.
- `www.ezecom.com.kh` sits behind Akamai (a CDN), so don't use it as `sni`.
  Keep `itc.edu.kh`.
