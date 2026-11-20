#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

STATE_FILE=/data/state.json
XRAY_CONFIG=/data/xray.json
CLIENT_FILE=/data/client.txt
LISTEN_PORT=443

umask 077
bashio::log.info "$(xray version | head -n1)"

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

# Pre-flight: the camouflage site must support TLS 1.3 + HTTP/2 (REALITY needs this).
case "${SNI}" in
    *apple.com*|*microsoft.com*|*google.com*|*amazon.com*|*cloudflare.com*|*.cn)
        bashio::log.warning "sni ${SNI} is a big-brand or .cn domain. Its IPs are well known and will not match yours, which makes blocking more likely. See the add-on Documentation tab." ;;
esac
if curl -fsS -o /dev/null --max-time 10 --tlsv1.3 --http2 "https://${SNI}"; then
    bashio::log.info "SNI target ${SNI} is reachable over TLS 1.3 + HTTP/2."
else
    bashio::log.warning "Could not reach https://${SNI} over TLS 1.3 + HTTP/2. Pick a different sni if clients fail to connect."
fi
bashio::log.info "xray tls ping ${SNI}:"
timeout 20 xray tls ping "${SNI}" 2>&1 | sed 's/^/    /' || bashio::log.warning "xray tls ping failed for ${SNI}."

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

bashio::log.info "-------------------------------------------------------------"
bashio::log.info "Client share link (import into Floxcore):"
echo "${LINK}"
bashio::log.info "QR code:"
qrencode -t ANSIUTF8 -m 2 "${LINK}" || bashio::log.warning "Could not render QR code."
bashio::log.info "-------------------------------------------------------------"

xray run -test -c "${XRAY_CONFIG}"
bashio::log.info "Starting Xray-core on port ${LISTEN_PORT} (VLESS + REALITY, SNI ${SNI})."
exec xray run -c "${XRAY_CONFIG}"
