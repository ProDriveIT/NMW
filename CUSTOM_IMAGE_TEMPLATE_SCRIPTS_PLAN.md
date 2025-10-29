# Custom Image Template Scripts - Detailed Explanation & Deployment Plan

## Executive Summary

**YES** - These 16 Custom Image Template Scripts can absolutely be used to create, customize, prep, and capture a "golden image" for AVD host pool deployment **without logging into the VM manually**. They are designed specifically for Azure Image Builder (AIB), which Azure AVD Custom Image Templates (CIT) uses under the hood.

---

## What Are Custom Image Template Scripts?

These scripts are PowerShell automation scripts designed to run during the **customization phase** of Azure Image Builder builds. They automate the entire image preparation process:

### Script Categories & Capabilities

#### 1. **Core Image Setup (Sysprep & Localization)**
- **`Admin Sysprep.ps1`** - Modifies the default sysprep script to use VM mode (`/mode:vm`) instead of quiet mode, ensuring proper generalization for VDI environments
- **`Set default OS language.ps1`** - Configures the default Windows language
- **`Install language packs.ps1`** - Adds language support packages

#### 2. **FSLogix Profile Container Configuration**
- **`Install and enable FSLogix.ps1`** - Downloads, installs, and configures FSLogix with:
  - Profile path configuration (SMB path)
  - VHD size settings
  - Dynamic VHDX creation
  - Microsoft Defender exclusions for FSLogix processes and files
  - Registry settings for profile management
- **`Enable FSLogix with Kerberos.ps1`** - Configures Kerberos authentication for FSLogix profiles

#### 3. **AVD/WVD Optimizations**
- **`Enable Windows optimizations for AVD.ps1`** - Comprehensive VDI optimization script that:
  - Disables Windows Media Player and removes payload
  - Disables unnecessary scheduled tasks
  - Configures default user settings via registry
  - Disables AutoLoggers (Windows traces)
  - Disables unnecessary services
  - Configures network optimizations (LanManWorkstation settings, adapter buffer sizes)
  - Applies Local Group Policy settings optimized for VDI
  - Configures Edge browser policies
  - Removes legacy Internet Explorer
  - Removes OneDrive Commercial
  - Performs disk cleanup (temp files, WER reports, recycle bins)
  
- **`Enable Screen capture protection.ps1`** - Enables AVD screen capture protection (blocks client, server, or both)
- **`Configure RDP Shortpath for managed networks.ps1`** - Configures RDP Shortpath for optimized network performance
- **`Enable time zone redirection.ps1`** - Configures time zone redirection for AVD sessions
- **`Configure Multi Media Redirection.ps1`** - Sets up multimedia redirection for AVD
- **`Configure session timeouts.ps1`** - Configures session timeout settings

#### 4. **Application Configuration**
- **`Configure Microsoft Office packages.ps1`** - Installs or uninstalls Office applications (Word, Excel, PowerPoint, etc.) with 32/64-bit support, including Visio and Project
- **`Configure Microsoft Teams optimizations.ps1`** - Installs and optimizes Microsoft Teams for AVD:
  - Installs Visual C++ Redistributable
  - Installs WebRTC Redirector Service (critical for Teams audio/video in VDI)
  - Installs Teams (1.0 MSI or 2.0 bootstrapper)
  - Configures registry settings for WVD environment detection
  
- **`Disable MSIX app attach auto updates.ps1`** - Prevents automatic MSIX app updates during image build
- **`Remove AppX packages.ps1`** - Removes bloatware/unnecessary Windows Store apps (Xbox, games, entertainment apps, etc.)
- **`Disable Storage sense.ps1`** - Disables Windows Storage Sense feature

### Key Characteristics of These Scripts

1. **Azure Image Builder Compatible** - All scripts follow AIB conventions:
   - Output logs prefixed with "AVD AIB Customization"
   - Proper error handling and exit codes
   - Cleanup of temporary files (removes `C:\AVDImage` and `C:\temp\wvd` folders)
   - Idempotent operations (can run multiple times safely)

2. **Execution Modes** - Marked with `#execution mode: Individual` meaning they run independently in sequence

3. **Parameter Support** - Many scripts support variables/parameters for customization:
   - FSLogix profile paths and VHD sizes
   - Teams version selection (1.0 vs 2.0)
   - Office application selection and architecture
   - Optimization category selection (All, Services, ScheduledTasks, etc.)

4. **Source Attribution** - All scripts are sourced from Microsoft's official RDS Templates repository, ensuring best practices and compatibility

---

## Two Deployment Options

### Option 1: Azure AVD Custom Image Templates (CIT) - Recommended

**Easiest approach** - Uses Azure portal/API with managed infrastructure.

#### Advantages:
- ✅ Fully managed by Azure (no need to create resource groups or managed identities manually)
- ✅ Integrated with AVD workspace
- ✅ Built-in monitoring and job tracking
- ✅ Automatic cleanup of build VMs
- ✅ Simple UI in Azure Portal

#### How It Works:
1. Azure AVD Custom Image Templates automatically creates:
   - Resource group: `IT_<region>_<random>` (e.g., `IT_eastus_xxxxx`)
   - Managed identity: System-assigned for the image template resource
   - Storage account for build artifacts
2. You select scripts from a catalog (or provide custom script URLs)
3. Scripts run in sequence during the customization phase
4. Final image is automatically generalized and captured
5. Image is stored as a managed image or in Azure Compute Gallery

#### Prerequisites:
- Contributor or Owner role on subscription/resource group
- `Microsoft.VirtualMachineImages` resource provider registered
- Network access from build VM to download sources (Internet, Azure Blob Storage, etc.)

---

### Option 2: Azure Image Builder (Direct) - Full Control

**Advanced approach** - Direct control over all resources and configuration.

#### Plan: Setup Infrastructure for Automated Image Building

### Step 1: Create Resource Group for Image Building

```powershell
# Define variables
$subscriptionId = "your-subscription-id"
$resourceGroupName = "rg-avd-image-builder"
$location = "eastus" # Or your preferred region

# Set subscription context
Set-AzContext -SubscriptionId $subscriptionId

# Create resource group
New-AzResourceGroup -Name $resourceGroupName -Location $location
```

### Step 2: Register Required Resource Providers

```powershell
# Register Azure Image Builder resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault
Register-AzResourceProvider -ProviderNamespace Microsoft.Network

# Verify registration (may take a few minutes)
Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages | 
    Select-Object RegistrationState
```

### Step 3: Create User-Assigned Managed Identity

```powershell
# Create managed identity
$identityName = "umi-avd-image-builder"
$identity = New-AzUserAssignedIdentity `
    -ResourceGroupName $resourceGroupName `
    -Name $identityName `
    -Location $location

# Get identity principal ID (you'll need this later)
$identityPrincipalId = $identity.PrincipalId
$identityId = $identity.Id

Write-Output "Identity Principal ID: $identityPrincipalId"
Write-Output "Identity Resource ID: $identityId"
```

### Step 4: Grant Managed Identity Permissions

```powershell
# Grant Contributor role to the managed identity on the resource group
New-AzRoleAssignment `
    -ObjectId $identityPrincipalId `
    -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" `
    -RoleDefinitionName "Contributor"

# If using Azure Compute Gallery, grant permissions there too
# $galleryResourceGroup = "rg-avd-gallery"
# $galleryName = "avdImageGallery"
# New-AzRoleAssignment `
#     -ObjectId $identityPrincipalId `
#     -Scope "/subscriptions/$subscriptionId/resourceGroups/$galleryResourceGroup/providers/Microsoft.Compute/galleries/$galleryName" `
#     -RoleDefinitionName "Contributor"
```

### Step 5: Create Storage Account for Build Scripts (Optional but Recommended)

If you want to store scripts in Azure Blob Storage instead of using inline scripts:

```powershell
# Create storage account
$storageAccountName = "stavdimgbuilder$(Get-Random -Minimum 1000 -Maximum 9999)"
New-AzStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -Location $location `
    -SkuName Standard_LRS `
    -Kind StorageV2

# Create container for scripts
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$ctx = $storageAccount.Context
New-AzStorageContainer -Name "scripts" -Context $ctx -Permission Blob
```

### Step 6: Upload Customization Scripts to Storage (Optional)

```powershell
# Upload scripts to blob storage
$scriptsPath = "C:\Dev\NMW\scripted-actions\custom-image-template-scripts"
$containerName = "scripts"

Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | ForEach-Object {
    $blobName = $_.Name
    Set-AzStorageBlobContent `
        -File $_.FullName `
        -Container $containerName `
        -Blob $blobName `
        -Context $ctx `
        -Force
}

# Get storage account key for SAS token generation
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]
```

### Step 7: Create Azure Image Builder Template

```powershell
# Define image template name
$imageTemplateName = "avd-golden-image-template"

# Base image reference (Windows 10/11 Enterprise with Microsoft 365 Apps)
# You can use Azure Marketplace image or custom image
$sourceImage = @{
    publisher = "microsoftwindowsdesktop"
    offer     = "office-365"
    sku       = "win11-21h2-avd-m365"
    version   = "latest"
}

# Or use existing managed image:
# $sourceImage = @{
#     id = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/images/your-base-image"
# }

# Distribution targets (Managed Image and/or Azure Compute Gallery)
$distTarget = @{
    type = "ManagedImage"
    managedImage = @{
        location = $location
        imageId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/images/avd-golden-image"
    }
}

# Customization scripts from your repository
$customizations = @(
    # Windows Optimizations (comprehensive)
    @{
        type = "PowerShell"
        name = "Enable Windows Optimizations"
        scriptUri = "https://your-storage-account.blob.core.windows.net/scripts/Enable%20Windows%20optimizations%20for%20AVD.ps1"
        runElevated = $true
        inline = @(
            ".\Enable Windows optimizations for AVD.ps1 -Optimizations All"
        )
    },
    
    # Install and Configure FSLogix
    @{
        type = "PowerShell"
        name = "Install FSLogix"
        scriptUri = "https://your-storage-account.blob.core.windows.net/scripts/Install%20and%20enable%20FSLogix.ps1"
        runElevated = $true
        inline = @(
            ".\Install and enable FSLogix.ps1 -ProfilePath '\\your-storage.file.core.windows.net\profiles' -VHDSize 30000"
        )
    },
    
    # Configure Teams Optimizations
    @{
        type = "PowerShell"
        name = "Configure Teams"
        scriptUri = "https://your-storage-account.blob.core.windows.net/scripts/Configure%20Microsoft%20Teams%20optimizations.ps1"
        runElevated = $true
        inline = @(
            ".\Configure Microsoft Teams optimizations.ps1 -TeamsDownloadLink 'https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409' -VCRedistributableLink 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -WebRTCInstaller 'https://aka.ms/msrdcwebrtcsvc/msi'"
        )
    },
    
    # Remove AppX Packages
    @{
        type = "PowerShell"
        name = "Remove Bloatware"
        scriptUri = "https://your-storage-account.blob.core.windows.net/scripts/Remove%20AppX%20packages.ps1"
        runElevated = $true
        inline = @(
            ".\Remove AppX packages.ps1 -AppxPackages @('Microsoft.XboxApp','Microsoft.GamingApp','Microsoft.BingNews','Microsoft.BingWeather')"
        )
    },
    
    # Enable Screen Capture Protection
    @{
        type = "PowerShell"
        name = "Screen Capture Protection"
        scriptUri = "https://your-storage-account.blob.core.windows.net/scripts/Enable%20Screen%20capture%20protection.ps1"
        runElevated = $true
        inline = @(
            ".\Enable Screen capture protection.ps1 -BlockOption 'BlockClientAndServer'"
        )
    },
    
    # Configure RDP Shortpath
    @{
        type = "PowerShell"
        name = "RDP Shortpath"
        scriptUri = "https://your-storage-account.blob.core.windows.net/scripts/Configure%20RDP%20Shortpath%20for%20managed%20networks.ps1"
        runElevated = $true
    },
    
    # Admin Sysprep (modifies default sysprep behavior)
    @{
        type = "PowerShell"
        name = "Admin Sysprep"
        scriptUri = "https://your-storage-account.blob.core.windows.net/scripts/Admin%20Sysprep.ps1"
        runElevated = $true
    }
)

# Create the image template
$imageTemplateConfig = @{
    Location = $location
    TemplateName = $imageTemplateName
    Source = $sourceImage
    Distribute = @($distTarget)
    Customize = $customizations
    Identity = @{
        type = "UserAssigned"
        userAssignedIdentities = @{
            $identityId = @{}
        }
    }
}

# Create image template using REST API or Az.ImageBuilder PowerShell module
# Note: Az.ImageBuilder may require preview module installation
Install-Module -Name Az.ImageBuilder -AllowPrerelease -Force -Scope CurrentUser
Import-Module Az.ImageBuilder

New-AzImageBuilderTemplate `
    -ResourceGroupName $resourceGroupName `
    -Name $imageTemplateName `
    -Location $location `
    -IdentityType UserAssigned `
    -IdentityId $identityId `
    -SourceType MarketplaceImage `
    -SourcePublisher $sourceImage.publisher `
    -SourceOffer $sourceImage.offer `
    -SourceSku $sourceImage.sku `
    -SourceVersion $sourceImage.version `
    -Customize $customizations `
    -Distribute $distTarget
```

### Step 8: Run the Image Build

```powershell
# Start the image build
$jobId = Invoke-AzImageBuilderTemplate `
    -ResourceGroupName $resourceGroupName `
    -ImageTemplateName $imageTemplateName

Write-Output "Image build started. Job ID: $jobId"
Write-Output "Monitor progress in Azure Portal or using:"
Write-Output "Get-AzImageBuilderTemplateRunOutput -ResourceGroupName $resourceGroupName -ImageTemplateName $imageTemplateName"
```

### Step 9: Monitor Build Progress

```powershell
# Check build status
$buildStatus = Get-AzImageBuilderTemplate `
    -ResourceGroupName $resourceGroupName `
    -Name $imageTemplateName

Write-Output "Build Status: $($buildStatus.LastRunStatusRunState)"
Write-Output "Start Time: $($buildStatus.LastRunStatusRunStartTime)"
Write-Output "End Time: $($buildStatus.LastRunStatusRunEndTime)"

# View build logs (if available)
Get-AzImageBuilderTemplateRunOutput `
    -ResourceGroupName $resourceGroupName `
    -ImageTemplateName $imageTemplateName
```

---

## Complete Example: Azure Image Builder Template JSON

Here's a complete ARM template example you can use with Azure CLI or PowerShell:

```json
{
  "$schema": "http://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "imageTemplateName": {
      "type": "string",
      "defaultValue": "avd-golden-image-template"
    },
    "managedIdentityResourceId": {
      "type": "string"
    },
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]"
    }
  },
  "resources": [
    {
      "type": "Microsoft.VirtualMachineImages/imageTemplates",
      "apiVersion": "2022-02-14",
      "name": "[parameters('imageTemplateName')]",
      "location": "[parameters('location')]",
      "identity": {
        "type": "UserAssigned",
        "userAssignedIdentities": {
          "[parameters('managedIdentityResourceId')]": {}
        }
      },
      "properties": {
        "source": {
          "type": "PlatformImage",
          "publisher": "microsoftwindowsdesktop",
          "offer": "office-365",
          "sku": "win11-21h2-avd-m365",
          "version": "latest"
        },
        "customize": [
          {
            "type": "PowerShell",
            "name": "WindowsOptimizations",
            "scriptUri": "https://yourstorageaccount.blob.core.windows.net/scripts/Enable%20Windows%20optimizations%20for%20AVD.ps1",
            "runElevated": true,
            "inline": [
              ".\\Enable Windows optimizations for AVD.ps1 -Optimizations All"
            ]
          },
          {
            "type": "PowerShell",
            "name": "InstallFSLogix",
            "scriptUri": "https://yourstorageaccount.blob.core.windows.net/scripts/Install%20and%20enable%20FSLogix.ps1",
            "runElevated": true,
            "inline": [
              ".\\Install and enable FSLogix.ps1 -ProfilePath '\\\\yourstorageaccount.file.core.windows.net\\profiles' -VHDSize 30000"
            ]
          },
          {
            "type": "PowerShell",
            "name": "ConfigureTeams",
            "scriptUri": "https://yourstorageaccount.blob.core.windows.net/scripts/Configure%20Microsoft%20Teams%20optimizations.ps1",
            "runElevated": true,
            "inline": [
              ".\\Configure Microsoft Teams optimizations.ps1 -TeamsDownloadLink 'https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409' -VCRedistributableLink 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -WebRTCInstaller 'https://aka.ms/msrdcwebrtcsvc/msi'"
            ]
          },
          {
            "type": "PowerShell",
            "name": "AdminSysprep",
            "scriptUri": "https://yourstorageaccount.blob.core.windows.net/scripts/Admin%20Sysprep.ps1",
            "runElevated": true
          }
        ],
        "distribute": [
          {
            "type": "ManagedImage",
            "location": "[parameters('location')]",
            "imageId": "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/[resourceGroup().name]/providers/Microsoft.Compute/images/avd-golden-image",
            "runOutputName": "avd-golden-image-output"
          }
        ]
      }
    }
  ]
}
```

---

## Using Scripts Directly from GitHub (Inline)

You can also reference scripts directly from GitHub or any public URL:

```powershell
$customizations = @(
    @{
        type = "PowerShell"
        name = "WindowsOptimizations"
        scriptUri = "https://raw.githubusercontent.com/your-org/NMW/main/scripted-actions/custom-image-template-scripts/Enable%20Windows%20optimizations%20for%20AVD.ps1"
        runElevated = $true
        inline = @(
            ".\\Enable Windows optimizations for AVD.ps1 -Optimizations All"
        )
    }
)
```

---

## Important Considerations

### 1. **Script Execution Order**
Scripts run in the order defined in the `customize` array. Recommended order:
1. Windows Optimizations (removes bloatware, disables services)
2. FSLogix Installation
3. Application Installations (Teams, Office)
4. Configuration (RDP Shortpath, Screen Capture, Time Zone)
5. Admin Sysprep (last, before generalization)

### 2. **Network Requirements**
- Build VM needs outbound Internet access to download:
  - Scripts (if using public URLs)
  - FSLogix installer
  - Teams installer
  - Windows updates (optional but recommended)
- If using private endpoints, ensure build VM can access:
  - Storage accounts (for script storage)
  - Key Vault (if storing secrets)
  - Your FSLogix profile storage account

### 3. **Build VM Configuration**
- Azure Image Builder creates a temporary build VM (typically `IT_*` naming)
- VM is automatically deleted after image capture
- Default size is Standard_D1_v2, but can be customized if needed

### 4. **Image Size Management**
- Scripts include cleanup steps to remove temp files
- Consider running `Optimize-Volume` or disk cleanup after all customizations
- Monitor final image size vs. base image size

### 5. **Error Handling**
- All scripts include error handling and logging
- Check build logs for any script failures
- Scripts use `$LASTEXITCODE` for status reporting
- Failed builds will show detailed error messages

### 6. **Parameter Validation**
- Many scripts validate input parameters
- Ensure required parameters are provided when using inline scripts
- Some scripts have optional parameters with defaults

---

## Alternative: Using Azure AVD Custom Image Templates Portal

If you prefer a UI-driven approach:

1. Navigate to Azure Portal → Azure Virtual Desktop → Custom Image Templates
2. Click "Create"
3. Configure:
   - **Source Image**: Select base image
   - **Scripts**: Add scripts from catalog or provide URLs
   - **Distribution**: Managed Image or Compute Gallery
4. Azure automatically creates:
   - Resource group
   - Managed identity
   - Storage account
5. Review and start build
6. Monitor in "Jobs" tab

---

## Troubleshooting

### Common Issues:

1. **Script Download Failures**
   - Verify script URLs are accessible
   - Check network security group rules
   - Ensure storage account firewall allows build VM subnet

2. **Permission Errors**
   - Verify managed identity has Contributor role
   - Check role assignments: `Get-AzRoleAssignment -ObjectId $identityPrincipalId`

3. **Build Timeout**
   - Complex scripts may take 1-2 hours
   - Increase timeout if needed
   - Monitor build VM status in portal

4. **Image Capture Failures**
   - Ensure Admin Sysprep script ran successfully
   - Check build VM logs in Azure Portal
   - Verify final image distribution target permissions

---

## Summary

✅ **Yes, you can fully automate golden image creation without manual VM access**

The Custom Image Template Scripts are designed specifically for this use case. Choose:

- **Option 1 (CIT)**: Easier, fully managed, good for most scenarios
- **Option 2 (Direct AIB)**: More control, advanced customization, CI/CD integration

Both approaches eliminate the need to:
- ❌ Create VMs manually
- ❌ RDP into build VMs
- ❌ Run scripts manually
- ❌ Run sysprep manually
- ❌ Capture images manually

Everything is automated end-to-end! 🚀
