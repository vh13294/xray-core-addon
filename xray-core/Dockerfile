ARG BUILD_FROM
FROM $BUILD_FROM

ARG BUILD_ARCH
ARG XRAY_VERSION=26.11.9

# Download a pinned Xray-core release at build time (not on every start)
# and verify it against the official SHA-256 digest.
RUN set -eux; \
    apk add --no-cache ca-certificates curl jq libqrencode-tools openssl busybox-extras; \
    apk add --no-cache --virtual .build-deps unzip; \
    case "${BUILD_ARCH}" in \
      amd64)   XRAY_ARCH="64" ;; \
      aarch64) XRAY_ARCH="arm64-v8a" ;; \
      armv7)   XRAY_ARCH="arm32-v7a" ;; \
      *) echo "Unsupported architecture: ${BUILD_ARCH}"; exit 1 ;; \
    esac; \
    BASE="https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}"; \
    curl -fsSL -o /tmp/xray.zip "${BASE}/Xray-linux-${XRAY_ARCH}.zip"; \
    curl -fsSL -o /tmp/xray.dgst "${BASE}/Xray-linux-${XRAY_ARCH}.zip.dgst"; \
    EXPECTED="$(grep -i '^SHA2-256=' /tmp/xray.dgst | head -n1 | awk '{print $2}')"; \
    echo "${EXPECTED}  /tmp/xray.zip" | sha256sum -c -; \
    mkdir -p /tmp/xray /usr/share/xray; \
    unzip -q /tmp/xray.zip -d /tmp/xray; \
    install -m 0755 /tmp/xray/xray /usr/bin/xray; \
    mv /tmp/xray/*.dat /usr/share/xray/; \
    rm -rf /tmp/xray /tmp/xray.zip /tmp/xray.dgst; \
    apk del .build-deps; \
    xray version

ENV XRAY_LOCATION_ASSET=/usr/share/xray

COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
