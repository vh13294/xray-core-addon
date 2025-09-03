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

# Download the latest Xray-core binary, handling different naming conventions
bashio::log.info "Downloading the latest Xray-core binary for $ARCH..."

# Try the standard naming convention first
XRAY_URL="$BASE_URL/Xray-linux-$ARCH.zip"
curl -sSL "$XRAY_URL" -o /tmp/xray.zip

# If the first download fails and the architecture is amd64, try the alternative naming
if [ $? -ne 0 ] && [ "$ARCH" == "amd64" ]; then
    bashio::log.info "Standard naming failed. Trying alternative naming convention for amd64..."
    XRAY_URL="$BASE_URL/Xray-linux-64.zip"
    curl -sSL "$XRAY_URL" -o /tmp/xray.zip
fi

if [ $? -ne 0 ]; then
    bashio::log.error "Failed to download Xray-core binary. Please check the URL and your network connection."
    exit 1
fi

# Unzip and make executable
bashio::log.info "Installing Xray-core..."
unzip -o /tmp/xray.zip -d /usr/bin/
chmod +x /usr/bin/xray
rm /tmp/xray.zip

# Run Xray-core
bashio::log.info "Starting Xray-core with provided configuration..."
/usr/bin/xray -c /xray-config.json

# Keep the script running to prevent the container from stopping
wait
