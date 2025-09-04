#!/usr/bin/with-contenv bashio

# Get user configuration from Home Assistant
CONFIG_PATH=/data/options.json
XRAY_CONFIG_JSON=$(jq --raw-output ".core_config" $CONFIG_PATH)

# Check if configuration is provided
if [ -z "$XRAY_CONFIG_JSON" ]; then
    bashio::log.error "Xray-core configuration is empty! Please configure the add-on."
    exit 1
fi

# Write the config to a file that Xray-core can read
echo "$XRAY_CONFIG_JSON" > /xray-config.json

# Define base URL and architecture for dynamic download
BASE_URL="https://github.com/XTLS/Xray-core/releases/latest/download"
ARCH=$(bashio::core.arch)

# Determine the correct URL based on architecture
case "$ARCH" in
  "amd64")
    XRAY_URL_AMD64_1="$BASE_URL/Xray-linux-64.zip"
    XRAY_URL_AMD64_2="$BASE_URL/Xray-linux-amd64.zip"
    bashio::log.info "Downloading the latest Xray-core binary for amd64..."
    # Try the first URL
    if curl -sSL --fail -o /tmp/xray.zip "$XRAY_URL_AMD64_1"; then
      bashio::log.info "Download successful from first URL."
    # If the first fails, try the second
    elif curl -sSL --fail -o /tmp/xray.zip "$XRAY_URL_AMD64_2"; then
      bashio::log.info "Download successful from second URL."
    else
      bashio::log.error "Failed to download Xray-core binary for amd64 from both known URLs."
      exit 1
    fi
    ;;
  *)
    # For other architectures, use the standard naming convention
    XRAY_URL="$BASE_URL/Xray-linux-$ARCH.zip"
    bashio::log.info "Downloading the latest Xray-core binary for $ARCH..."
    if ! curl -sSL --fail -o /tmp/xray.zip "$XRAY_URL"; then
      bashio::log.error "Failed to download Xray-core binary for $ARCH. Please check the URL and your network connection."
      exit 1
    fi
    ;;
esac

# Unzip and make executable
bashio::log.info "Installing Xray-core..."

# Check if the downloaded file is a valid zip before unzipping
if ! unzip -t /tmp/xray.zip > /dev/null; then
    bashio::log.error "Downloaded file is not a valid zip archive. Aborting."
    rm /tmp/xray.zip
    exit 1
fi

unzip -o /tmp/xray.zip -d /usr/bin/
chmod +x /usr/bin/xray
rm /tmp/xray.zip

# Run Xray-core
bashio::log.info "Starting Xray-core with provided configuration..."
/usr/bin/xray -c /xray-config.json

# Keep the script running to prevent the container from stopping
wait