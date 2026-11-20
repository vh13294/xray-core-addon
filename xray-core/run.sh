#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

STATE_FILE=/data/state.json
XRAY_CONFIG=/data/xray.json
CLIENT_FILE=/data/client.txt
LISTEN_PORT=443
WEB_ROOT=/data/www
WEB_PORT=8099

umask 077
bashio::log.info "$(xray version | head -n1)"

# ---------------------------------------------------------------------------
# Web UI (Home Assistant ingress): a page with a scannable QR code. The log's
# text QR often can't be scanned, because the log viewer adds gaps between
# lines. Ingress pages sit behind Home Assistant's login, and the server only
# accepts connections from the Supervisor's ingress proxy.
# ---------------------------------------------------------------------------
start_web() {
    # $1 = HTML body
    mkdir -p "${WEB_ROOT}"
    cat > "${WEB_ROOT}/index.html" <<EOF
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Xray-core</title>
<style>
  body { font-family: system-ui, sans-serif; background: #fff; color: #111;
         max-width: 520px; margin: 24px auto; padding: 0 16px; }
  .qr svg { width: 100%; height: auto; aspect-ratio: 1; display: block; }
  textarea { width: 100%; height: 7em; font: 12px monospace; }
  .warn { color: #a00; }
</style></head>
<body>
$1
</body></html>
EOF
    printf 'A:172.30.32.2\nD:*\n' > /etc/httpd.conf
    busybox-extras httpd -p "${WEB_PORT}" -h "${WEB_ROOT}" -c /etc/httpd.conf
}

# ---------------------------------------------------------------------------
# Custom mode: if core_config is set, use it as-is.
# ---------------------------------------------------------------------------
if bashio::config.has_value 'core_config'; then
    bashio::log.info "core_config is set, so running your custom Xray config."
    bashio::config 'core_config' > "${XRAY_CONFIG}"
    if ! jq empty "${XRAY_CONFIG}" 2>/dev/null; then
        bashio::log.fatal "core_config is not valid JSON."
        exit 1
    fi
    bashio::log.warning "In custom mode your inbound must listen on port ${LISTEN_PORT} inside the container."
    start_web "<h2>Xray-core</h2><p>Custom mode (<code>core_config</code> is set): no QR code is generated.</p>"
    xray run -test -c "${XRAY_CONFIG}"
    exec xray run -c "${XRAY_CONFIG}"
fi

# ---------------------------------------------------------------------------
# REALITY mode: keys and IDs are generated once and kept in /data.
# ---------------------------------------------------------------------------
[ -f "${STATE_FILE}" ] || echo '{}' > "${STATE_FILE}"

state_get() { jq -r --arg k "$1" '.[$k] // empty' "${STATE_FILE}"; }
state_set() {
    local tmp
    tmp="$(mktemp)"
    jq --arg k "$1" --arg v "$2" '.[$k] = $v' "${STATE_FILE}" > "${tmp}"
    mv "${tmp}" "${STATE_FILE}"
}

# UUID: option > saved > new
if bashio::config.has_value 'uuid'; then
    UUID="$(bashio::config 'uuid')"
else
    UUID="$(state_get uuid)"
    if [ -z "${UUID}" ]; then
        UUID="$(xray uuid)"
        bashio::log.info "Generated a new client UUID."
    fi
fi
state_set uuid "${UUID}"

# X25519 key pair. `xray x25519` prints the private key on line 1 and the
# public key on line 2 (labels differ between versions, so parse by line).
PRIVATE_KEY="$(state_get private_key)"
if [ -z "${PRIVATE_KEY}" ]; then
    PRIVATE_KEY="$(xray x25519 | sed -n '1s/^[^:]*:[[:space:]]*//p')"
    bashio::log.info "Generated a new REALITY key pair."
fi
PUBLIC_KEY="$(xray x25519 -i "${PRIVATE_KEY}" | sed -n '2s/^[^:]*:[[:space:]]*//p')"
if [ -z "${PRIVATE_KEY}" ] || [ -z "${PUBLIC_KEY}" ]; then
    bashio::log.fatal "Could not generate the REALITY key pair."
    exit 1
fi
state_set private_key "${PRIVATE_KEY}"

# Short ID: option > saved > new (16 hex chars)
if bashio::config.has_value 'short_id'; then
    SHORT_ID="$(bashio::config 'short_id')"
else
    SHORT_ID="$(state_get short_id)"
    if [ -z "${SHORT_ID}" ]; then
        SHORT_ID="$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    fi
fi
state_set short_id "${SHORT_ID}"

SNI="$(bashio::config 'sni')"
FINGERPRINT="$(bashio::config 'fingerprint')"
CLIENT_NAME="$(bashio::config 'client_name')"
PUBLIC_PORT="$(bashio::config 'public_port')"
LOG_LEVEL="$(bashio::config 'log_level')"

# Public address used in the share link.
if bashio::config.has_value 'server_address'; then
    SERVER_ADDRESS="$(bashio::config 'server_address')"
else
    SERVER_ADDRESS="$(curl -fsS --max-time 10 https://api.ipify.org || true)"
    if [ -z "${SERVER_ADDRESS}" ]; then
        bashio::log.fatal "Could not detect your public IP. Set server_address (your DDNS name or IP)."
        exit 1
    fi
    bashio::log.warning "server_address is empty, so using detected public IP ${SERVER_ADDRESS}."
    bashio::log.warning "Set server_address to a DDNS hostname so the link survives IP changes."
fi

# ---------------------------------------------------------------------------
# Pre-flight: REALITY needs an sni site with TLS 1.3, HTTP/2 and a valid
# certificate for that exact hostname. Problems are logged as errors but do
# not stop the add-on, so a short outage of the sni site at boot (for example
# after a power cut) cannot take your proxy offline.
# ---------------------------------------------------------------------------
SNI_OK=true
sni_error() { bashio::log.error "$1"; SNI_OK=false; }

case "${SNI}" in
    *apple.com*|*microsoft.com*|*google.com*|*amazon.com*|*cloudflare.com*|*.cn)
        bashio::log.warning "sni ${SNI} is a big-brand or .cn domain. Its IPs are well known and will not match yours, which makes blocking more likely. See the add-on Documentation tab." ;;
esac

CURL_RC=0
HTTP_VERSION="$(curl -s -o /dev/null --max-time 10 --tlsv1.3 --http2 \
    -w '%{http_version}' "https://${SNI}" 2>/dev/null)" || CURL_RC=$?
case "${CURL_RC}" in
    0)
        if [ "${HTTP_VERSION}" = "2" ]; then
            bashio::log.info "SNI target ${SNI} is reachable over TLS 1.3 + HTTP/2."
        else
            sni_error "sni ${SNI} supports TLS 1.3 but not HTTP/2. REALITY needs both: pick a different sni."
        fi ;;
    35)
        sni_error "sni ${SNI} failed the TLS 1.3 handshake. The site probably only supports TLS 1.2: pick a different sni." ;;
    51|60)
        sni_error "sni ${SNI} has an invalid certificate (expired, or not issued for this exact hostname). Pick a different sni, or try it with/without www." ;;
    6)
        sni_error "sni ${SNI} does not resolve. Check the spelling: hostname only, no https:// and no trailing /." ;;
    *)
        bashio::log.warning "Could not check https://${SNI} (curl exit ${CURL_RC}). It may be temporarily down; pick a different sni if clients fail to connect." ;;
esac

# Warn early when the sni site's certificate is about to expire.
if [ "${CURL_RC}" -eq 0 ]; then
    CERT="$(echo | timeout 10 openssl s_client -connect "${SNI}:443" -servername "${SNI}" 2>/dev/null \
        | openssl x509 2>/dev/null || true)"
    if [ -n "${CERT}" ]; then
        CERT_END="$(printf '%s\n' "${CERT}" | openssl x509 -noout -enddate | cut -d= -f2)"
        if printf '%s\n' "${CERT}" | openssl x509 -noout -checkend $((14 * 86400)) >/dev/null; then
            bashio::log.info "sni certificate is valid until ${CERT_END}."
        else
            bashio::log.warning "sni certificate expires soon (${CERT_END}). If the site does not renew it, clients will stop connecting: have a backup sni ready."
        fi
    fi
fi

bashio::log.info "xray tls ping ${SNI} (a failure under 'Pinging without SNI' is normal):"
PING_OUT="$(timeout 20 xray tls ping "${SNI}" 2>&1 || true)"
printf '%s\n' "${PING_OUT}" | sed 's/^/    /'
if ! printf '%s\n' "${PING_OUT}" | sed -n '/Pinging with SNI/,$p' \
        | grep -qE 'TLS Version:[[:space:]]+TLS 1\.3'; then
    sni_error "xray tls ping did not get a TLS 1.3 handshake from ${SNI} with SNI."
fi

if [ "${SNI_OK}" = true ]; then
    bashio::log.info "sni check passed."
else
    bashio::log.error "sni check FAILED (see above). Xray will still start, but clients will most likely not connect until you change sni."
fi

# ---------------------------------------------------------------------------
# Build the Xray server config.
# ---------------------------------------------------------------------------
jq -n \
    --arg loglevel "${LOG_LEVEL}" \
    --argjson port "${LISTEN_PORT}" \
    --arg uuid "${UUID}" \
    --arg email "${CLIENT_NAME}" \
    --arg target "${SNI}:443" \
    --arg sni "${SNI}" \
    --arg pk "${PRIVATE_KEY}" \
    --arg sid "${SHORT_ID}" \
'{
  log: { loglevel: $loglevel },
  inbounds: [{
    tag: "vless-reality",
    listen: "0.0.0.0",
    port: $port,
    protocol: "vless",
    settings: {
      clients: [{ id: $uuid, email: $email, flow: "xtls-rprx-vision" }],
      decryption: "none"
    },
    streamSettings: {
      network: "raw",
      security: "reality",
      realitySettings: {
        show: false,
        target: $target,
        xver: 0,
        serverNames: [$sni],
        privateKey: $pk,
        shortIds: [$sid]
      }
    },
    sniffing: { enabled: true, destOverride: ["http", "tls", "quic"], routeOnly: true }
  }],
  outbounds: [
    { tag: "direct", protocol: "freedom" },
    { tag: "block", protocol: "blackhole" }
  ],
  routing: {
    domainStrategy: "IPIfNonMatch",
    rules: [
      { type: "field", ip: ["geoip:private"], outboundTag: "block" },
      { type: "field", protocol: ["bittorrent"], outboundTag: "block" }
    ]
  }
}' > "${XRAY_CONFIG}"

# ---------------------------------------------------------------------------
# Share link + QR code for Floxcore / v2rayN / Shadowrocket etc.
# ---------------------------------------------------------------------------
HOST="${SERVER_ADDRESS}"
case "${HOST}" in
    *:*) HOST="[${HOST}]" ;;  # bare IPv6 needs brackets
esac
NAME_ENC="$(jq -rn --arg s "${CLIENT_NAME}" '$s|@uri')"
LINK="vless://${UUID}@${HOST}:${PUBLIC_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=${FINGERPRINT}&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#${NAME_ENC}"
echo "${LINK}" > "${CLIENT_FILE}"

QR_SVG="$(qrencode -t SVG -s 8 -m 4 -o - "${LINK}" | sed '/^<?xml/d')"
LINK_HTML="$(jq -rn --arg s "${LINK}" '$s|@html')"
NAME_HTML="$(jq -rn --arg s "${CLIENT_NAME}" '$s|@html')"
SNI_HTML="$(jq -rn --arg s "${SNI}" '$s|@html')"
SNI_NOTE=""
if [ "${SNI_OK}" != true ]; then
    SNI_NOTE="<p class=\"warn\"><b>sni check failed.</b> Clients will most likely not connect until you change <code>sni</code>. See the add-on log.</p>"
fi
start_web "<h2>Xray-core: ${NAME_HTML}</h2>
${SNI_NOTE}
<p>Scan this in Floxcore (or v2rayN, Shadowrocket):</p>
<div class=\"qr\">${QR_SVG}</div>
<p>Or copy the link and use <i>Import from clipboard</i>:</p>
<textarea readonly onclick=\"this.select()\">${LINK_HTML}</textarea>
<p>SNI: <code>${SNI_HTML}</code></p>
<p class=\"warn\">This link is the password to your proxy. Don't share it or post screenshots of it.</p>"

bashio::log.info "-------------------------------------------------------------"
bashio::log.info "Client share link (copy it, then use Import from clipboard in Floxcore):"
echo "${LINK}"
bashio::log.info "For a scannable QR code, click OPEN WEB UI on the add-on page (or the 'Xray QR' sidebar item)."
bashio::log.info "-------------------------------------------------------------"

xray run -test -c "${XRAY_CONFIG}"
bashio::log.info "Starting Xray-core on port ${LISTEN_PORT} (VLESS + REALITY, SNI ${SNI})."
exec xray run -c "${XRAY_CONFIG}"
