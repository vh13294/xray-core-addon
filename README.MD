```
# Xray-core Home Assistant Add-on
This is a custom Home Assistant add-on for Xray-core, designed to be flexible and easy to configure.

## 🚀 Installation Guide
### Step 1: Create the Add-on Directory
First, you need a dedicated folder for the add-on on your Home Assistant machine. You can do this using the SSH or Samba add-ons.
```

mkdir -p /addons/xray-core

```
### Step 2: Add the Required Files

Place the following files into the new `/addons/xray-core` directory:
- `config.json`
- `run.sh`
- `Dockerfile`

### Step 3: Add the Local Repository
Navigate to the Home Assistant UI to add this local directory as a repository.
1. Go to **Settings** > **Add-ons**.
2. Click the **Add-on Store** button (bottom right corner).
3. Open the three-dot menu (top right) and select **Repositories**.
4. Enter `file:///addons` in the URL field and click **Add**.

### Step 4: Install the Add-on
After adding the repository, your new add-on should be visible.
1. Refresh the Add-on Store page.
2. Find the "Xray-core" add-on under the "Local add-ons" section.
3. Click on the add-on and then click **Install**.

### Step 5: Configure Xray-core
The core of the add-on is configured with a JSON file.
1. After installation, go to the **Configuration** tab for the add-on.
2. Paste your complete Xray-core JSON configuration into the `core_config` option.
3. **Save** the configuration.

### Step 6: Start and Verify
1. Return to the **Info** tab and click **Start**.
2. Check the **Logs** tab to monitor the status and confirm that Xray-core is running without errors.
## 🛠️ Configuration Details
The `core_config` option is a text field that expects a valid JSON object. This JSON will be used directly by the Xray-core binary.