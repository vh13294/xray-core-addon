# Changelog

## 1.0.1

- Default `sni` is now `itc.edu.kh`. `www.metfone.com.kh` only supports
  TLS 1.2, which REALITY can't use.
- Stricter sni check on start: clear ERRORs for no TLS 1.3, no HTTP/2, an
  expired or mismatched certificate, or a hostname that doesn't resolve. Also
  warns when the sni certificate expires within 14 days. Xray still starts, so
  a short outage of the sni site can't take the proxy offline.
- `xray tls ping` result is now checked, not just printed.
- DOCS: list of Cambodian sites already tested and rejected.

## 1.0.0

- New REALITY mode (default): VLESS + REALITY + Vision with an auto-generated
  UUID, X25519 key pair and short ID, saved in `/data`.
- Prints a `vless://` share link and a QR code in the log for Floxcore and
  other clients.
- Xray-core is pinned (v26.11.9), downloaded at build time and checked against
  the official SHA-256 digest, instead of being fetched on every start.
- Fixed the aarch64 download name (`arm64-v8a`).
- Dropped `full_access`, `privileged`, host networking and the Home Assistant /
  Supervisor API access. The add-on now only exposes TCP 443.
- Default `sni` is `www.metfone.com.kh` (matches a Metfone home connection).
- Pre-flight check on each start: TLS 1.3 + HTTP/2 test, `xray tls ping`,
  and a warning for big-brand or `.cn` SNI domains.
- DOCS: how to choose an SNI and avoid IP blocks, based on a previous
  `www.apple.com` setup that was blocked within a day.
- `core_config` still works as an advanced override.
- Supported architectures are now `aarch64` and `amd64`.
