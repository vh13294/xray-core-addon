# Xray-core Home Assistant Add-on
This is a custom Home Assistant add-on for Xray-core, designed to be flexible and easy to configure.

## 🚀 Installation Guide

### Step 1: Install the Add-on
After adding the repository, your new add-on should be visible.
1. Refresh the Add-on Store page.
2. Find the "Xray-core" add-on under the "Local add-ons" section.
3. Click on the add-on and then click **Install**.

### Step 2: Configure Xray-core
The core of the add-on is configured with a JSON file.
1. After installation, go to the **Configuration** tab for the add-on.
2. Paste your complete Xray-core JSON configuration into the `core_config` option.
3. **Save** the configuration.

### Step 3: Start and Verify
1. Return to the **Info** tab and click **Start**.
2. Check the **Logs** tab to monitor the status and confirm that Xray-core is running without errors.
## 🛠️ Configuration Details
The `core_config` option is a text field that expects a valid JSON object. This JSON will be used directly by the Xray-core binary.