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

1. In Azure Portal, navigate to: **Azure Virtual Desktop** > **Custom image templates**
2. Click **+ Create** (or **+ Add custom image template**)

You should now see the "Create a custom image template" wizard with multiple tabs at the top.

### 2.2 Basics Tab

Complete the following fields:

| Field | What to Enter |
|-------|---------------|
| **Template name** | `AVD-GoldenImage-v1` |
| **Import from existing template** | Leave as **No** |
| **Subscription** | Select your subscription from the dropdown |
| **Resource group** | Select `rg-avd-cit-infrastructure` from the dropdown (created in Step 1) |
| **Location** | Select the same region you used in Step 1 (e.g., `UK South`) |
| **Managed identity** | Select **User-assigned managed identity**, then select **`umi-avd-cit`** |

Click **Next** at the bottom right.


### 2.3 Source Image Tab

1. Select **Platform image (marketplace)**
2. Choose the **latest Windows 11 version (without apps)** from the list
3. **Note**: The source image will always be **Gen2**. There is no option at this stage to enter publisher/offer/SKU, nor can you pick the generation.

Click **Next**.

### 2.4 Distribution Targets Tab

1. Check **Azure Compute Gallery** (leave "Managed image" unchecked)
2. Complete the following:
   - **Gallery name**: Select `gal_avd_images` from the dropdown (created in Step 1)
   - **Gallery image definition**: Select `avd_session_host` from the dropdown (already created in Step 1)
   - **Gallery image version**: `0.0.1`
   - **Run output**: `AVDImageBuild1`
   - **Replicated regions**: Select regions where you want the image stored (e.g., `UK South`). At minimum, select the same region as your infrastructure.
   - **Excluded from latest**: **No**
   - **Storage account type**: `Standard_LRS`

Click **Next**.

### 2.5 Build Properties Tab

Configure build settings:

| Field | Value |
|-------|-------|
| **Build timeout (minutes)** | `200` |
| **Build VM size** | `Standard_D2s_v4` |
| **OS disk size (GB)** | 127 (default) or larger if needed |
| **Staging group** | Leave blank (auto-created) |
| **Build VM managed identity** | Leave blank (optional) |
| **Virtual network** | Leave blank (temporary network created) |

Click **Next**.

### 2.6 Customizations Tab

Add built-in scripts to customize your image. Click **+ Add built-in script** for each of the following:

1. **Install language packs**
   - Select **English (United Kingdom)**

2. **Set default OS language**
   - Select **English (United Kingdom)**

3. **Time zone redirection**
   - Enable: **Yes**

4. **Disable storage sense**
   - Enable: **Yes**

5. **Install and enable FSLogix**
   - Enable: **Yes**
   - **Profile path**: Enter your FSLogix profile path in UNC format
     - If your Azure Files URL is: `https://[storageaccount].file.core.windows.net/[sharename]`
     - Convert to UNC format: `\\[storageaccount].file.core.windows.net\[sharename]`
     - Example: `https://caavdstorage.file.core.windows.net/avd-profiles` → `\\caavdstorage.file.core.windows.net\avd-profiles`

6. **Configure RDP shortpath**
   - Enable: **Yes**

7. **Install Teams with optimizations**
   - Enable: **Yes**

8. **Configure session timeouts**
   - Enable: **Yes**
   - **Time limit for disconnected sessions**: `6 hours`
   - **Time limit for active but idle sessions**: `2 hours`
   - **Time limit for active sessions**: `12 hours`
   - **Time limit to sign out sessions**: `15 minutes`

9. **Install multimedia redirection**
   - Enable: **Yes**
   - **Architecture**: `x64`
   - **Edge**: **Yes**
   - **Chrome**: **Yes**

10. **Configure Windows optimizations**
    - Enable: **Yes**
    - **Select all** optimization options

11. **Disable auto update**
    - Enable: **Yes**

12. **Remove AppX packages**
    - Enable: **Yes**
    - **Important**: Keep commonly used apps like Snipping Tool, Voice Recorder, Calculator, etc. (err on the side of caution if unsure)

13. **Apply Windows updates**
    - Enable: **Yes**

After adding each built-in script, complete any required parameters and click **Save**.

#### Add Your Own Scripts

Click **+ Add your own script** and add the following scripts in order:

1. **Install Microsoft 365 Apps**
   - **Name**: `Install Microsoft 365 Apps`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-m365-apps.ps1`
   - Click **Save**

2. **Install OneDrive Per Machine**
   - **Name**: `Install OneDrive Per Machine`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-onedrive-per-machine.ps1`
   - Click **Save**

3. **Optimize Microsoft Edge**
   - **Name**: `Optimize Microsoft Edge`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/optimize-microsoft-edge.ps1`
   - Click **Save**

4. **Install Google Chrome Per Machine**
   - **Name**: `Install Google Chrome Per Machine`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-chrome-per-machine.ps1`
   - Click **Save**

5. **Install Adobe Reader Per Machine**
   - **Name**: `Install Adobe Reader Per Machine`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-adobe-reader-per-machine.ps1`
   - Click **Save**

**Note**: Scripts will execute in the order listed. Use **Move up** or **Move down** to reorder if needed.

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

## Step 4: Manual Image Creation and Template Updates (Optional)

### 4.1 Create a Standalone VM for Manual Customization (If Required)

If you need to install applications that cannot be deployed via script, you can create a standalone VM from your custom image and manually install applications:

1. **Navigate to Azure Compute Gallery**:
   - In Azure Portal, search for **Azure Compute Gallery**
   - Open `gal_avd_images` (created in Step 1)

2. **Create a VM from the latest image version**:
   - Go to **Image definitions** → `avd_session_host`
   - Select the latest image version (e.g., `0.0.1`)
   - Click **Create VM**
   - Configure the VM:
     - **Name**: e.g., `vm-goldenimage-manual`
     - **Resource group**: `rg-avd-cit-infrastructure` (or your preferred resource group)
     - **VM size**: `Standard_D2s_v4` (matches Gen2 source image)
     - **Authentication**: Configure as needed
   - Click **Review + create**, then **Create**

3. **Connect to the VM and install applications**:
   - Connect via RDP or Azure Bastion
   - Install any required applications manually
   - Configure settings as needed
   - **Important**: Do not run sysprep manually - the capture process will handle this

4. **Capture the image back to the gallery**:
   - In Azure Portal, navigate to your VM
   - Click **Capture** (or use Azure CLI)
   - Configure capture settings:
     - **Destination**: **Azure Compute Gallery**
     - **Gallery**: Select `gal_avd_images`
     - **Image definition**: Select `avd_session_host`
     - **Image version**: Enter a new version (e.g., `0.0.2`)
     - **Replication**: Select regions as needed
     - **Storage account type**: `Standard_LRS`
     - **Exclude from latest**: **No** (unless you want this as a test version)
   - Click **Create**

> **Note**: The captured image will be stored in the same gallery as your automated builds, maintaining consistency across your image versions.

### 4.2 Create a New Template with Updated Scripts or Actions

**Important**: Custom image templates are immutable and cannot be edited once created. To add new scripts or modify existing ones, you must create a new template. However, you can use an existing image from your gallery as the source image to build upon.

1. **Navigate to Custom Image Templates**:
   - Go to **Azure Virtual Desktop** > **Custom image templates**
   - Click **+ Create** (or **+ Add custom image template**)

2. **Basics Tab**:
   - **Template name**: Enter a new name (e.g., `AVD-GoldenImage-v2`)
   - **Import from existing template**: Leave as **No**
   - **Subscription**: Select your subscription
   - **Resource group**: Select `rg-avd-cit-infrastructure`
   - **Location**: Select the same region as before
   - **Managed identity**: Select **User-assigned managed identity**, then select **`umi-avd-cit`**
   - Click **Next**

3. **Source Image Tab**:
   - Select **Azure Compute Gallery** (to use your existing image)
   - **Gallery**: Select `gal_avd_images`
   - **Gallery image definition**: Select `avd_session_host`
   - **Gallery image version**: Select the version you want to build upon (e.g., `0.0.1`)
   - **Note**: This uses your existing custom image as the starting point
   - Click **Next**

4. **Distribution Targets Tab**:
   - Check **Azure Compute Gallery** (leave "Managed image" unchecked)
   - **Gallery name**: Select `gal_avd_images`
   - **Gallery image definition**: Select `avd_session_host`
   - **Gallery image version**: Enter a new version (e.g., `0.0.2`)
   - **Run output**: Enter a new name (e.g., `AVDImageBuild2`)
   - **Replicated regions**: Select regions as needed
   - **Excluded from latest**: **No**
   - **Storage account type**: `Standard_LRS`
   - Click **Next**

5. **Build Properties Tab**:
   - Configure as needed (same as Step 2.5)
   - **Build timeout (minutes)**: `200`
   - **Build VM size**: `Standard_D2s_v4`
   - Click **Next**

6. **Customizations Tab**:
   - Add your updated scripts (built-in or custom)
   - **Add new scripts** or **modify the script list** as needed
   - Use **Move up** or **Move down** to adjust execution order
   - Click **Next**

7. **Tags Tab (Optional)**:
   - Add any tags as needed
   - Click **Next**

8. **Review and Create**:
   - Review all settings
   - Click **Create**

9. **Start the build**:
   - After the template is created, follow Step 3 to start a new build
   - The new build will use your updated scripts and create a new image version in the same gallery

> **Note**: 
> - Templates are immutable - you cannot edit them once created
> - Creating a new template allows you to add/modify scripts while building on your existing image
> - Each build creates a new image version in your gallery, maintaining version history

## Step 5: Use Your Custom Image

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
- **Location**: `scripted-actions/windows-scripts/`
- **GitHub URLs**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/[script-name].ps1`

**Available Scripts:**
- `install-m365-apps.ps1` - Installs/updates Microsoft 365 Apps for Business (system-wide)
- `install-onedrive-per-machine.ps1` - Installs OneDrive for all users (system-wide)
- `optimize-microsoft-edge.ps1` - Configures Edge policies for optimized AVD performance
- `install-chrome-per-machine.ps1` - Installs Google Chrome for all users (system-wide, sysprep-compatible)
- `install-adobe-reader-per-machine.ps1` - Installs Adobe Acrobat Reader DC for all users (system-wide, sysprep-compatible)
- And more scripts in `scripted-actions/custom-image-template-scripts/` directory

## Next Steps

- [Learn more about Custom Image Templates](https://learn.microsoft.com/en-us/azure/virtual-desktop/custom-image-templates)
- [Create a host pool with your custom image](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace)
- Review the detailed [Custom Image Template Scripts Plan](../CUSTOM_IMAGE_TEMPLATE_SCRIPTS_PLAN.md)

## Support

For issues or questions:
1. Check build logs in the temporary resource group
2. Review [Microsoft documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/custom-image-templates)
3. Verify all prerequisites are met

