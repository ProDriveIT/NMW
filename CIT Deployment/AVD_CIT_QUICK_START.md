# AVD Custom Image Template - Quick Start Guide

This guide will help you set up infrastructure for Azure Virtual Desktop Custom Image Templates and create your first custom image using the Azure Portal.

## Prerequisites

Before you begin, ensure you have:

- **Azure CLI** installed ([Download here](https://aka.ms/installazurecliwindows))
- **Global Administrator** role in Azure AD
- **Owner** role on the target subscription
- **Azure CLI logged in** (`az login`)

## Step 1: Run Infrastructure Setup

Run the setup script to create all required infrastructure:

```powershell
.\setup-avd-cit-infrastructure.ps1
```

**What the script does:**
- Prompts for subscription ID (or uses current)
- Registers required resource providers
- Creates resource group: `rg-avd-cit-infrastructure`
- Creates managed identity: `umi-avd-cit`
- Creates image gallery: `gal-avd-images`
- Creates storage account (optional, for scripts)
- Configures all required permissions

**What to save from the output:**
- **Managed Identity Resource ID** - You'll need this in the portal wizard
- Gallery name: `gal-avd-images`

## Step 2: Create Custom Image Template in Azure Portal

### 2.1 Navigate to Custom Image Templates

1. Sign in to [Azure Portal](https://portal.azure.com)
2. In the search bar, type **Azure Virtual Desktop** and select it
3. In the left menu, select **Custom image templates**
4. Click **+ Add custom image template** or **Create**

### 2.2 Basics Tab

Complete the following:

| Field | Value |
|-------|-------|
| Template name | Enter a descriptive name (e.g., "AVD-GoldenImage-v1") |
| Import from existing template | No |
| Subscription | Select your subscription |
| Resource group | Select `rg-avd-cit-infrastructure` |
| Location | Select the same region where infrastructure was created |
| Managed identity | **Select "User-assigned managed identity"** |
| | **Paste the Resource ID from Step 1 output** |

Click **Next**.

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

**For Azure Compute Gallery (Recommended):**

1. Check **Azure Compute Gallery**
2. Complete the following:
   - **Gallery name**: `gal-avd-images` (from Step 1)
   - **Gallery image definition**: 
     - If no definition exists, click **Create new**
     - Enter a name (e.g., "avd-session-host")
     - Select **Publisher**: Your organization name
     - Select **Offer**: e.g., "avd-images"
     - Select **SKU**: e.g., "windows11-avd"
     - **Generation**: Must match your source image generation (Gen1 or Gen2)
   - **Gallery image version**: Leave blank (auto-generated) or enter a version
   - **Replicated regions**: Select regions where you want the image stored
   - **Excluded from latest**: No (unless you want to exclude this version)
   - **Storage account type**: Standard_LRS or Premium_LRS

**Optionally for Managed Image:**

1. Check **Managed image**
2. Complete:
   - **Resource group**: `rg-avd-cit-infrastructure`
   - **Image name**: Create new or select existing
   - **Location**: Same as resource group
   - **Run output name**: Any name for tracking

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
- Install and enable FSLogix
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
   https://raw.githubusercontent.com/[your-org]/NMW/main/scripted-actions/custom-image-template-scripts/[script-name].ps1
   ```
   
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
   - Select **Shared Images** (for gallery) or **My Images** (for managed image)
   - Select your custom image
   - **Important**: Choose a VM size that matches the generation of your source image

## Troubleshooting

### Build Fails

1. **Check build logs:**
   - Select your template
   - Review **Build run state** for error details
   - Check the temporary resource group: `IT_<ResourceGroupName>_<TemplateName>_<GUID>`
   - Look for `packerlogs` container in storage account

2. **Common issues:**
   - **Timeout**: Increase build timeout in Build Properties
   - **Script download failed**: Verify script URLs are publicly accessible
   - **Permission errors**: Verify managed identity has correct roles
   - **Generation mismatch**: Ensure VM size matches source image generation

### Permission Errors

If you see permission errors:
- Verify managed identity has "AVD Custom Image Builder Role" assigned
- Check role assignments in Access control (IAM) on resource group
- Ensure you have Owner role on subscription

### Resource Provider Not Registered

If you see resource provider errors:
- Re-run the setup script (it will register missing providers)
- Or manually register: `az provider register --namespace Microsoft.VirtualMachineImages`

## Reference Scripts

Scripts are available in this repository:
- Location: `scripted-actions/custom-image-template-scripts/`
- GitHub URLs: `https://raw.githubusercontent.com/[your-org]/NMW/main/scripted-actions/custom-image-template-scripts/[script-name].ps1`

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

