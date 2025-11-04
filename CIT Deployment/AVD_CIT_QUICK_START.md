# AVD Custom Image Template - Quick Start Guide

This guide will help you set up infrastructure for Azure Virtual Desktop Custom Image Templates and create your first custom image using the Azure Portal.

## Prerequisites

Before you begin, ensure you have:

- **Access to Azure Portal** - You'll use Azure Cloud Shell (no installation required)
- **Global Administrator** role in Azure AD
- **Owner** role on the target subscription
- **Signed in to Azure Portal** - Cloud Shell uses your portal session automatically

---

## Step 1: Run Infrastructure Setup (Required First Step)

### 1.1 Open Azure Cloud Shell

1. **Sign in to Azure Portal**: Go to [https://portal.azure.com](https://portal.azure.com) and sign in
2. **Open Cloud Shell**: 
   - Click the **Cloud Shell icon** (`>_`) at the top of the portal (usually next to the search bar)
   - If prompted to choose **Bash** or **PowerShell**, select **PowerShell**
   - Wait for Cloud Shell to initialize (first time may take a minute)
   - You'll see a terminal window at the bottom of the portal

> **Note**: Cloud Shell is pre-authenticated with your portal session - no need to run `az login`

### 1.2 Clone the Repository and Run the Script

In the Cloud Shell terminal, run these commands:

```powershell
# Clone the repository
git clone https://github.com/ProDriveIT/NMW.git

# Navigate to the CIT Deployment folder
cd NMW/"CIT Deployment"

# Run the setup script
./setup-avd-cit-infrastructure.ps1
```

**When prompted for subscription ID:**
- Press **Enter** to use your current subscription, OR
- Enter your subscription ID and press **Enter**

> **Note**: The script uses Azure CLI commands. **No installation needed** - Azure CLI is already built into Cloud Shell and ready to use.

### 1.3 What the Script Does

The script automatically:
- Registers required resource providers (Microsoft.VirtualMachineImages, etc.)
- Creates resource group: `rg-avd-cit-infrastructure`
- Creates managed identity: `umi-avd-cit`
- Creates image gallery: `gal_avd_images`
- Creates gallery image definition: `avd_session_host` (Publisher: ProDriveIT, Offer: avd_images, SKU: windows11_avd, Gen2)
- Creates storage account (optional, for scripts)
- Creates custom RBAC role with required permissions
- Assigns all necessary role assignments

The script takes approximately 15-20 minutes to complete, as resource provider registration can take several minutes.

### 1.4 Save This Information (Required for Portal)

**Note these values from the script output (you may need them in Step 2):**

1. **Managed Identity Name**: `umi-avd-cit` - You'll select this from a dropdown in the portal wizard

2. **Gallery Name**: `gal_avd_images`
   - **Gallery Image Definition**: `avd_session_host` (already created)

3. **Resource Group Name**: `rg-avd-cit-infrastructure`

4. **Location** (region): The region where resources were created (e.g., `uksouth` or `UK South`)

---

## Step 2: Create Custom Image Template in Azure Portal

> **Note**: Only proceed to this step after successfully completing Step 1.

### 2.1 Navigate to Custom Image Templates

> **Note**: If you have Cloud Shell open, you can keep it open in the background. The portal navigation works independently.

1. **In Azure Portal** (same portal window where Cloud Shell is running):
   - **Search for Azure Virtual Desktop**:
     - Click the **search bar** at the top of the portal (or press `/`)
     - Type: `Azure Virtual Desktop`
     - Click on **Azure Virtual Desktop** in the results
2. **Navigate to Custom Image Templates**:
   - In the left-hand menu, scroll down and click **Custom image templates**
   - You should see the Custom image templates page
3. **Start Creation**:
   - Click the **+ Create** button (or **+ Add custom image template**)

You should now see the "Create a custom image template" wizard with multiple tabs at the top.

### 2.2 Basics Tab

Complete the following fields in order:

| Field | What to Enter |
|-------|---------------|
| **Template name** | Enter a descriptive name (e.g., `AVD-GoldenImage-v1` or `Windows11-AVD-SessionHost`) |
| **Import from existing template** | Leave as **No** |
| **Subscription** | Select your subscription from the dropdown |
| **Resource group** | Select `rg-avd-cit-infrastructure` from the dropdown (created in Step 1) |
| **Location** | Select the same region you used in Step 1 (e.g., `UK South`) |
| **Managed identity** | **CRITICAL**: Select the dropdown and choose **User-assigned managed identity** |
| | Then click in the **Managed identity** field below - it will show a list of available managed identities |
| | Select **`umi-avd-cit`** from the list (you should see: `umi-avd-cit / rg-avd-cit-infrastructure`) |

**Verify** the Managed identity field shows `umi-avd-cit` before proceeding.

Click **Next** at the bottom right.


### 2.3 Source Image Tab

Choose your source image:

**Option A: Platform Image (Marketplace)**
- Select **Platform image (marketplace)**
- Choose an image from the list (e.g., Windows 11 Enterprise with Microsoft 365 Apps)
- Note the **Generation** shown (Gen1 or Gen2) - you'll need this later

**Option B: Managed Image**
- Select **Managed image**
- Choose an existing managed image from your subscription

**Option C: Azure Compute Gallery**
- Select **Azure Compute Gallery**
- Choose a gallery, image definition, and version

Click **Next**.

### 2.4 Distribution Targets Tab

**Use Azure Compute Gallery (Required):**

The infrastructure created in Step 1 includes an Azure Compute Gallery. You must use this gallery for distribution.

1. Check **Azure Compute Gallery** (leave "Managed image" unchecked)
2. Complete the following:
   - **Gallery name**: Select `gal_avd_images` from the dropdown (created in Step 1)
   - **Gallery image definition**: 
     - Select `avd_session_host` from the dropdown (already created in Step 1)
     - OR click **Create new** if you want different settings:
       - Enter a name (e.g., `avd-session-host`)
       - Select **Publisher**: Your organization name
       - Select **Offer**: e.g., `avd-images`
       - Select **SKU**: e.g., `windows11-avd`
       - **Generation**: **CRITICAL** - Must match your source image generation (Gen1 or Gen2). The default definition created is Gen2 - if your source is Gen1, create a new definition with Gen1.
   - **Gallery image version**: Leave blank (auto-generated) or enter a version like `1.0.0`
   - **Replicated regions**: Select regions where you want the image stored (e.g., `UK South`). At minimum, select the same region as your infrastructure.
   - **Excluded from latest**: Leave as **No** (unless you want to exclude this version from "latest" references)
   - **Storage account type**: `Standard_LRS` (recommended) or `Premium_LRS` if you need faster performance

> **Note**: Managed images are not recommended for AVD deployments. Azure Compute Gallery provides versioning, replication, and better management capabilities.

Click **Next**.

### 2.5 Build Properties Tab

Configure build settings:

| Field | Recommendation |
|-------|----------------|
| Build timeout (minutes) | 120-180 (for Windows Updates, language packs, etc.) |
| Build VM size | Standard_D2s_v3 (for Gen1) or Standard_D2s_v4 (for Gen2) |
| OS disk size (GB) | 127 (default) or larger if needed |
| Staging group | Leave blank (auto-created) |
| Build VM managed identity | Leave blank (optional) |
| Virtual network | Leave blank (temporary network created) |

**Important**: Select a VM size that matches the **generation** of your source image:
- **Gen1**: Standard_D2s_v3, Standard_D4s_v3, etc.
- **Gen2**: Standard_D2s_v4, Standard_D4s_v4, etc.

Click **Next**.

### 2.6 Customizations Tab

Add scripts to customize your image:

#### Option A: Built-in Scripts (Recommended)

Click **+ Add built-in script** and select from available options:
- Install language packs
- Set default OS language
- Enable Windows optimizations for AVD
- **Install and enable FSLogix** - Requires Profile Path in UNC format:
  - If your Azure Files URL is: `https://[storageaccount].file.core.windows.net/[sharename]`
  - Convert to UNC format: `\\[storageaccount].file.core.windows.net\[sharename]`
  - Example: `https://caavdstorage.file.core.windows.net/avd-profiles` → `\\caavdstorage.file.core.windows.net\avd-profiles`
  - Enter the UNC path (not HTTPS URL) in the "Profile path" field
- Configure Microsoft Teams optimizations
- Configure Microsoft Office packages
- Enable screen capture protection
- Configure RDP Shortpath
- And more...

Complete any required parameters and click **Save**.

#### Option B: Your Own Scripts

Click **+ Add your own script**:

1. Enter a **Name** for the script
2. Enter the **URI**:
   
   **Recommended: GitHub Raw URL**
   ```
   https://raw.githubusercontent.com/ProDriveIT/NMW/main/scripted-actions/custom-image-template-scripts/[script-name].ps1
   ```
   
   **Example URLs from this repository:**
   - Windows Optimizations: `https://raw.githubusercontent.com/ProDriveIT/NMW/main/scripted-actions/custom-image-template-scripts/enable-windows-optimizations.ps1`
   - FSLogix: `https://raw.githubusercontent.com/ProDriveIT/NMW/main/scripted-actions/custom-image-template-scripts/install-enable-fslogix.ps1`
   - Teams: `https://raw.githubusercontent.com/ProDriveIT/NMW/main/scripted-actions/custom-image-template-scripts/configure-teams-optimizations.ps1`
   
   **Alternative: Storage Account with SAS Token**
   ```
   https://[storage-account].blob.core.windows.net/scripts/[script-name].ps1?[SAS-token]
   ```

3. Click **Save**

**Script Execution Order:**
- Scripts run in the order listed
- Use **Move up**, **Move down** to reorder
- Recommended order:
  1. Windows Optimizations
  2. FSLogix Installation
  3. Application Installations (Teams, Office)
  4. Configuration Scripts (RDP, Screen Capture)
  5. Admin Sysprep (last, if needed)

Click **Next**.

### 2.7 Tags Tab (Optional)

Add any tags to organize your resources, then click **Next**.

### 2.8 Review and Create

Review all settings, then click **Create**.

The template will be created in about 20 seconds. Click **Refresh** if needed.

## Step 3: Build the Custom Image

1. From **Custom image templates**, select your template (check the box)
2. Click **Start build**
3. Monitor the build status:
   - Click **Refresh** to update status
   - Click the template name to see detailed **Build run state**
   - Build time varies (typically 30-120 minutes depending on scripts)

**What happens during build:**
- Temporary VM is created
- Scripts are downloaded and executed
- Image is generalized with sysprep
- Image is captured and stored
- Temporary resources are cleaned up

## Step 4: Use Your Custom Image

Once the build completes successfully:

1. Navigate to **Host pools** in Azure Virtual Desktop
2. Create a new host pool or update existing one
3. On the **Virtual Machines** tab:
   - For **Image**, click **See all images**
   - Select **Shared Images** (your image is stored in Azure Compute Gallery)
   - Select your custom image from the gallery (`gal_avd_images`)
   - **Important**: Choose a VM size that matches the generation of your source image (Gen1 or Gen2)

## Troubleshooting

### Build Fails

1. **Check build logs via Azure Portal:**
   - Navigate to the temporary resource group: `IT_rg-avd-cit-infrastructure_[TemplateName]_[GUID]`
   - Find the Storage Account (name will be a random string)
   - Open the Storage Account → **Containers** → `packerlogs` container
   - Navigate through folders to find `customization.log`
   - Download and review the log file for error details

2. **Check build logs via Azure CLI (Cloud Shell):**
   ```powershell
   # Set variables from your error message
   $storageAccountName = "fo2qchfajl1umfu60tml38az"  # From your error
   $resourceGroup = "IT_rg-avd-cit-infrastructure_AVD-GoldenImag_2e359f4d-d19e-43fe-be68-330d742a3c92"
   $logPath = "6cf3634f-6ad9-48eb-8a84-7e60600a5d5c/customization.log"
   
   # Download the log file
   az storage blob download `
       --account-name $storageAccountName `
       --container-name "packerlogs" `
       --name "$logPath" `
       --file "customization.log" `
       --auth-mode login
   
   # View the log
   Get-Content customization.log | Select-Object -Last 100
   ```

3. **Common issues:**
   - **Chocolatey package not found**: 
     - Error: `The package was not found with the source(s) listed`
     - Solution: Verify package name is correct, or make Chocolatey install commands non-fatal by adding `-ErrorAction SilentlyContinue` and checking exit codes
     - Example fix: `choco install package-name -y --ignore-errors` or wrap in try/catch
   - **Script exits with non-zero exit code**: 
     - Error: `Script exited with non-zero exit status: 1. Allowed exit codes are: [0]`
     - Solution: Ensure all scripts handle errors gracefully and exit with code 0 on completion. Use `$LASTEXITCODE = 0` at the end of scripts if needed
   - **Timeout**: Increase build timeout in Build Properties
   - **Script download failed**: Verify script URLs are publicly accessible (GitHub raw URLs)
   - **Script execution errors**: Check customization.log for PowerShell errors
   - **Permission errors**: Verify managed identity has Contributor role on resource group, gallery, and image definition
   - **Generation mismatch**: Ensure VM size matches source image generation (Gen1 vs Gen2)
   - **Network connectivity**: Build VM needs internet access to download scripts

### Permission Errors

If you see permission errors:
- Verify managed identity has "Contributor" role assigned on:
  - Resource group (`rg-avd-cit-infrastructure`)
  - Azure Compute Gallery (`gal_avd_images`)
  - Image definition (`avd_session_host`)
- Check role assignments in Access control (IAM) on these resources
- The managed identity should have Contributor role at minimum - this includes all required Image Builder permissions:
  - `Microsoft.Compute/galleries/read`
  - `Microsoft.Compute/galleries/images/read`
  - `Microsoft.Compute/galleries/images/versions/read`
  - `Microsoft.Compute/galleries/images/versions/write`
  - `Microsoft.Compute/images/write`, `read`, `delete`
- Ensure you have Owner role on subscription (for running the setup script)

### Resource Provider Not Registered

If you see resource provider errors:
- Re-run the setup script in Cloud Shell (it will register missing providers)
- Or manually register in Cloud Shell: `az provider register --namespace Microsoft.VirtualMachineImages`

### Failed to Start Image Template Build - "OperationNotAllowed" Error

If you see: `"Operation Microsoft.VirtualMachineImages/imageTemplates/run is not allowed in provisioning state: failed or run state"`

This means the image template is stuck in a **failed** or **running** state. To fix:

**Option 1: Delete and Recreate the Template (Recommended)**
1. In Azure Portal, navigate to your Custom Image Template resource
2. Delete the template (it won't delete the image, just the template)
3. Create a new template using the wizard

**Option 2: Check Current Build Status**
1. In the template resource, go to the **"Run output"** tab
2. Check if a build is currently running (wait for it to complete/fail)
3. If it failed, review error logs to understand why
4. Delete the template and recreate with fixes

**Option 3: Check via Azure CLI**
```powershell
# Check template status
az image builder template show `
    --resource-group [your-rg] `
    --name [your-template-name] `
    --query "lastRunStatus" -o json

# If stuck, delete and recreate
az image builder template delete `
    --resource-group [your-rg] `
    --name [your-template-name]
```

**Common Causes:**
- Script errors in customization scripts
- Network connectivity issues during build
- Permissions errors (managed identity)
- Source image issues

### Gallery Shows But Returns 404 Error in Portal

If the gallery appears in the dropdown but shows a 404 error when selected:

1. **Verify gallery exists** in Cloud Shell:
   ```powershell
   az sig show --resource-group rg-avd-cit-infrastructure --gallery-name gal_avd_images
   ```
   If this returns details, the gallery exists but portal may be caching.

2. **Try these solutions:**
   - **Wait 2-5 minutes** - Portal sometimes takes time to fully index new resources
   - **Refresh the portal page** (F5 or Ctrl+R)
   - **Clear browser cache** and reload
   - **Navigate directly** to the gallery: In Azure Portal, search for "Shared Image Gallery" → Open `gal_avd_images`
   - **Use Cloud Shell** to verify and list gallery:
     ```powershell
     az sig list --resource-group rg-avd-cit-infrastructure
     ```

3. **If gallery doesn't exist**, re-run the setup script - it will skip existing resources and create what's missing.

4. **Alternative**: In the CIT wizard, you can manually enter the gallery details instead of selecting from dropdown:
   - Gallery name: `gal_avd_images`
   - Resource group: `rg-avd-cit-infrastructure`

## Reference Scripts

Scripts are available in this repository:
- **Repository**: [https://github.com/ProDriveIT/NMW](https://github.com/ProDriveIT/NMW)
- **Location**: `scripted-actions/custom-image-template-scripts/`
- **GitHub URLs**: `https://raw.githubusercontent.com/ProDriveIT/NMW/main/scripted-actions/custom-image-template-scripts/[script-name].ps1`

**Available Scripts:**
- `enable-windows-optimizations.ps1` - Comprehensive AVD optimizations
- `install-enable-fslogix.ps1` - FSLogix installation and configuration
- `configure-teams-optimizations.ps1` - Teams VDI optimizations
- `configure-office.ps1` - Office installation/configuration
- `configure-rdp-shortpath.ps1` - RDP Shortpath setup
- `enable-timezone-redirection.ps1` - Time zone redirection
- And more...

## Next Steps

- [Learn more about Custom Image Templates](https://learn.microsoft.com/en-us/azure/virtual-desktop/custom-image-templates)
- [Create a host pool with your custom image](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace)
- Review the detailed [Custom Image Template Scripts Plan](../CUSTOM_IMAGE_TEMPLATE_SCRIPTS_PLAN.md)

## Support

For issues or questions:
1. Check build logs in the temporary resource group
2. Review [Microsoft documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/custom-image-templates)
3. Verify all prerequisites are met

