# AVD Custom Image Template - Quick Start Guide

This guide will help you set up infrastructure for Azure Virtual Desktop Custom Image Templates and create your first custom image using the Azure Portal.

## Contents

- [Prerequisites](#prerequisites)
- [Step 1: Run Infrastructure Setup (Required First Step)](#step-1-run-infrastructure-setup-required-first-step)
  - [1.1 Open Azure Cloud Shell](#11-open-azure-cloud-shell)
  - [1.2 Clone the Repository and Run the Script](#12-clone-the-repository-and-run-the-script)
  - [1.3 What the Script Does](#13-what-the-script-does)
  - [1.4 Save This Information (Required for Portal)](#14-save-this-information-required-for-portal)
- [Step 2: Create Custom Image Template in Azure Portal](#step-2-create-custom-image-template-in-azure-portal)
  - [2.1 Navigate to Custom Image Templates](#21-navigate-to-custom-image-templates)
  - [2.2 Basics Tab](#22-basics-tab)
  - [2.3 Source Image Tab](#23-source-image-tab)
  - [2.4 Distribution Targets Tab](#24-distribution-targets-tab)
  - [2.5 Build Properties Tab](#25-build-properties-tab)
  - [2.6 Customizations Tab](#26-customizations-tab)
  - [2.7 Tags Tab (Optional)](#27-tags-tab-optional)
  - [2.8 Review and Create](#28-review-and-create)
- [Step 3: Build the Custom Image](#step-3-build-the-custom-image)
- [Step 4: Manual Image Creation and Template Updates (Optional)](#step-4-manual-image-creation-and-template-updates-optional)
  - [4.1 Create a Standalone VM for Manual Customization (If Required)](#41-create-a-standalone-vm-for-manual-customization-if-required)
  - [4.2 Create a New Template with Updated Scripts or Actions](#42-create-a-new-template-with-updated-scripts-or-actions)
- [Step 5: Use Your Custom Image](#step-5-use-your-custom-image)
  - [5.1 Verify Image Build Completion](#51-verify-image-build-completion)
  - [5.2 Navigate to Host Pools](#52-navigate-to-host-pools)
  - [5.3 Create a New Host Pool (Scenario A)](#53-create-a-new-host-pool-scenario-a)
  - [5.4 Configure Virtual Machines with Your Custom Image](#54-configure-virtual-machines-with-your-custom-image)
  - [5.5 Select Your Custom Image from Gallery](#55-select-your-custom-image-from-gallery)
  - [5.6 Select VM Size](#56-select-vm-size)
  - [5.7 Complete Host Pool Configuration](#57-complete-host-pool-configuration)
  - [5.8 Verify Host Pool Deployment](#58-verify-host-pool-deployment)
  - [5.9 Update Existing Host Pool (Scenario B)](#59-update-existing-host-pool-scenario-b)
- [Troubleshooting](#troubleshooting)
  - [Build Fails](#build-fails)
  - [Permission Errors](#permission-errors)
  - [Resource Provider Not Registered](#resource-provider-not-registered)
  - [Failed to Start Image Template Build - "OperationNotAllowed" Error](#failed-to-start-image-template-build-operationnotallowed-error)
  - [Gallery Shows But Returns 404 Error in Portal](#gallery-shows-but-returns-404-error-in-portal)
- [Reference Scripts](#reference-scripts)
- [Next Steps](#next-steps)
- [Support](#support)

---

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

4. **Install Windows Package Manager (winget)**
   - **Name**: `Install Windows Package Manager (winget)`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-winget.ps1`
   - Click **Save**
   - **Note**: This should be added before Chrome and Adobe Reader scripts, as they use winget for installation.

5. **Install Google Chrome Per Machine**
   - **Name**: `Install Google Chrome Per Machine`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-chrome-per-machine.ps1`
   - Click **Save**
   - **Note**: Requires winget to be installed first (add script #4 above).

6. **Install Adobe Reader Per Machine**
   - **Name**: `Install Adobe Reader Per Machine`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-adobe-reader-per-machine.ps1`
   - Click **Save**
   - **Note**: Requires winget to be installed first (add script #4 above).

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

> **Note**: Only proceed to this step after successfully completing Step 3 and verifying your image build completed successfully.

### 5.1 Verify Image Build Completion

Before using your custom image, verify the build completed successfully:

1. **Navigate to Custom Image Templates**:
   - In Azure Portal, go to **Azure Virtual Desktop** > **Custom image templates**
   - Find your template (e.g., `AVD-GoldenImage-v1`)

2. **Check Build Status**:
   - The **Status** column should show **Succeeded**
   - If it shows **Running**, wait for it to complete (click **Refresh** to update)
   - If it shows **Failed**, see the [Troubleshooting](#troubleshooting) section

3. **Verify Image in Gallery** (Optional):
   - In Azure Portal, search for **Azure Compute Gallery**
   - Open `gal_avd_images` (created in Step 1)
   - Go to **Image definitions** → `avd_session_host`
   - Verify your image version appears (e.g., `0.0.1`)
   - Status should be **Replication status: Completed**

### 5.2 Navigate to Host Pools

1. In Azure Portal, navigate to: **Azure Virtual Desktop** > **Host pools**

2. You will see one of two scenarios:
   - **Scenario A**: You need to create a new host pool
   - **Scenario B**: You want to update an existing host pool with your custom image

### 5.3 Create a New Host Pool (Scenario A)

If you don't have a host pool yet, create one:

1. **Click + Create** (or **+ Add host pool**)

2. **Basics Tab**:
   - Complete the required fields:
     - **Subscription**: Select your subscription
     - **Resource group**: Select or create a resource group for your host pool
     - **Host pool name**: Enter a name (e.g., `hp-avd-production`)
     - **Location**: Select the region where you want the host pool
     - **Validation environment**: Select **No** (unless creating a validation host pool)
     - **Host pool type**: Select **Pooled** (recommended) or **Personal** based on your needs
     - **Load balancing algorithm**: Select **Breadth-first** (recommended) or **Depth-first**

3. **Click Next** to proceed to the **Virtual Machines** tab

4. **Continue with Step 5.4** below to configure the virtual machines with your custom image

### 5.4 Configure Virtual Machines with Your Custom Image

Whether creating a new host pool or updating an existing one, follow these steps to use your custom image:

1. **Navigate to the Virtual Machines Tab**:
   - If creating new: You're already on this tab
   - If updating existing: Select your host pool → Click **Virtual machines** → Click **+ Add**

2. **Configure Virtual Machine Settings**:

   Complete the following fields:

   | Field | What to Enter |
   |-------|---------------|
   | **Resource group** | Select the resource group for your VMs (can be different from host pool resource group) |
   | **Name prefix** | Enter a prefix for VM names (e.g., `avd-vm`) |
   | **Virtual machine location** | Select the region (should match your image replication region) |
   | **Availability options** | Select **Availability zone** or **Availability set** based on your requirements |
   | **Security type** | Select **Trusted launch** (recommended) or **Standard** |
   | **Image** | **See Step 5.5 below** for detailed instructions |
   | **VM size** | Select a VM size (see Step 5.6 for guidance) |
   | **Number of VMs** | Enter the number of session hosts you want to create |
   | **OS disk type** | Select **Premium SSD** (recommended) or **Standard SSD** |
   | **Virtual network** | Select your existing virtual network |
   | **Subnet** | Select the subnet for your session hosts |
   | **Network security group** | Select **None** (recommended) or your existing NSG |
   | **Public IP** | Select **No** (recommended for security) |

3. **Continue with Step 5.5** to select your custom image

### 5.5 Select Your Custom Image from Gallery

1. **Click on the Image field** (or click **See all images** if available)

2. **Select Image Source**:
   - You'll see options like **Marketplace**, **My images**, **Shared images**, etc.
   - Click **Shared images** (your custom image is stored in Azure Compute Gallery)

3. **Select Your Gallery**:
   - In the **Select an image** dialog, you should see your gallery: `gal_avd_images`
   - If you don't see it, verify:
     - The image build completed successfully
     - The image was replicated to the region you're deploying in
     - You have permissions to view the gallery

4. **Select Image Definition**:
   - After selecting the gallery, you'll see image definitions
   - Select **`avd_session_host`** (created in Step 1)

5. **Select Image Version**:
   - You'll see available image versions (e.g., `0.0.1`, `0.0.2`)
   - Select the version you want to use
   - **Tip**: The latest version is usually recommended unless you need a specific version

6. **Confirm Selection**:
   - The image details will show:
     - **Publisher**: ProDriveIT
     - **Offer**: avd_images
     - **SKU**: windows11_avd
     - **Version**: Your selected version (e.g., `0.0.1`)
   - Click **Select** to confirm

> **Note**: If you don't see your image in the list, ensure:
> - The image build completed successfully (check Step 5.1)
> - The image is replicated to the region you're deploying in
> - You're looking in the correct subscription

### 5.6 Select VM Size

**Important**: Choose a VM size that matches the generation of your source image.

Since your source image is **Gen2** (Windows 11), you must select a **Gen2-compatible VM size**.

1. **Click on the VM size field**

2. **Select a VM Size**:
   - Recommended sizes for AVD session hosts:
     - **Standard_D2s_v4** - Good for light to moderate workloads (2 vCPUs, 8 GB RAM)
     - **Standard_D4s_v4** - Better for moderate workloads (4 vCPUs, 16 GB RAM)
     - **Standard_D8s_v4** - For heavier workloads (8 vCPUs, 32 GB RAM)
     - **Standard_B2s** - Budget option for light workloads (2 vCPUs, 4 GB RAM)

3. **Verify Generation Compatibility**:
   - All VM sizes with "s" suffix (e.g., `Standard_D2s_v4`) support Gen2
   - Avoid sizes without "s" suffix unless you're certain they support Gen2
   - If unsure, select a size with "s" suffix

4. **Consider Your Workload**:
   - **Light users** (basic Office apps, web browsing): `Standard_B2s` or `Standard_D2s_v4`
   - **Moderate users** (Office apps, multiple tabs, light design work): `Standard_D4s_v4`
   - **Power users** (design software, development, heavy multitasking): `Standard_D8s_v4` or larger

> **Important**: VM size selection affects cost and performance. Start with a smaller size and scale up if needed. You can change VM sizes later by redeploying session hosts.

### 5.7 Complete Host Pool Configuration

After configuring virtual machines, complete the remaining host pool settings:

1. **Workspace Tab** (if creating new host pool):
   - **Register desktop app group**: Select **Yes** (recommended)
   - **Workspace**: Select existing workspace or create new

2. **Tags Tab** (Optional):
   - Add any tags to organize your resources

3. **Review + Create**:
   - Review all settings
   - Verify:
     - Custom image is selected from `gal_avd_images`
     - VM size is Gen2-compatible
     - Network configuration is correct
   - Click **Create**

4. **Wait for Deployment**:
   - Deployment typically takes 15-30 minutes
   - Monitor progress in the **Notifications** area (bell icon)
   - VMs will be created, domain-joined (if configured), and registered to the host pool

### 5.8 Verify Host Pool Deployment

After deployment completes:

1. **Navigate to Host Pools**:
   - Go to **Azure Virtual Desktop** > **Host pools**
   - Select your host pool

2. **Check Virtual Machines**:
   - Click **Virtual machines** tab
   - Verify all VMs show **Status: Available**
   - Verify **Agent version** is shown (indicates AVD agent is installed)

3. **Test Connection** (Optional):
   - Assign users to the host pool
   - Have a test user connect using Remote Desktop app
   - Verify the desktop loads and applications are available

> **Note**: If VMs show as **Unavailable** or have errors, check:
> - Network connectivity
> - Domain join status (if using domain join)
> - AVD agent installation status
> - See [Troubleshooting](#troubleshooting) section for more help

### 5.9 Update Existing Host Pool (Scenario B)

If you want to update an existing host pool with your new custom image:

1. **Navigate to Your Host Pool**:
   - Go to **Azure Virtual Desktop** > **Host pools**
   - Select your existing host pool

2. **Generate Registration Key** (Required):
   - In the host pool overview, click **Registration key** in the left menu
   - Click **Generate new key**
   - Set an **Expiration date and time** (recommend at least 24 hours from now to allow time for deployment)
   - Click **OK**
   - **Copy the registration key** - You'll need this during VM deployment
   - **Important**: Keep this key secure and note the expiration time. If the key expires before VMs are deployed, you'll need to generate a new one.

3. **Add New Session Hosts**:
   - Click **Virtual machines** tab (or **Session hosts** tab)
   - Click **+ Add**
   - Follow **Step 5.4** through **Step 5.7** to configure new VMs with your custom image
   - **Note**: During the deployment process, the registration key will be used automatically to register the new VMs to the host pool

4. **Replace Existing Session Hosts** (Optional):
   - If you want to replace existing hosts:
     - **Generate a registration key** (if you haven't already - see step 2 above)
     - Drain existing hosts (set to drain mode to prevent new sessions)
     - Wait for users to disconnect
     - Delete old VMs
     - Add new VMs using your custom image (follow steps 2-3 above, including registration key generation)

> **Note**: When updating an existing host pool, consider:
> - Adding new VMs first, then removing old ones (zero-downtime approach)
> - Testing the new image with a subset of users before full rollout
> - Using validation host pools for testing before production deployment

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
- `install-winget.ps1` - Installs Windows Package Manager (winget) if not already available
- `install-chrome-per-machine.ps1` - Installs Google Chrome for all users using winget (system-wide, sysprep-compatible)
- `install-adobe-reader-per-machine.ps1` - Installs Adobe Acrobat Reader DC for all users using winget (system-wide, sysprep-compatible)
- `install-datto-rmm-stewart-co.ps1` - Installs Datto RMM agent for Stewart & Co client
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

