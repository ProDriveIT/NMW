# Post-Setup Guide: What Happens After Infrastructure Setup

## Overview

After running `Setup-AzureImageBuilderInfrastructure.ps1`, you'll have all the infrastructure in place. This guide walks you through the next steps to actually build your golden image.

---

## What the Setup Script Created

After successful execution, you now have:

✅ **Resource Group** - Contains all image building resources  
✅ **User-Assigned Managed Identity** - With Contributor permissions  
✅ **Registered Resource Providers** - Microsoft.VirtualMachineImages, etc.  
✅ **Storage Account** (optional) - For storing build scripts  
✅ **Blob Container** - Named "scripts" in storage account  

---

## Step-by-Step: Building Your Golden Image

### Step 1: Upload Customization Scripts to Storage

The setup script created a storage account and "scripts" container. Now you need to upload your PowerShell scripts:

```powershell
# Set your variables (adjust based on setup script output)
$ResourceGroupName = "rg-avd-image-builder"
$StorageAccountName = "stavdimgxxxxx"  # From setup script output
$ScriptsPath = ".\scripted-actions\custom-image-template-scripts"

# Get storage context
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName

$ctx = $storageAccount.Context

# Upload all scripts
Write-Output "Uploading Custom Image Template Scripts..."
Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" | ForEach-Object {
    $blobName = $_.Name
    
    # Encode special characters in blob name (URL encoding)
    $encodedBlobName = [System.Web.HttpUtility]::UrlEncode($blobName)
    
    Set-AzStorageBlobContent `
        -File $_.FullName `
        -Container "scripts" `
        -Blob $blobName `
        -Context $ctx `
        -Force
    
    Write-Output "  ✓ Uploaded: $blobName"
    Write-Output "    URL: https://$StorageAccountName.blob.core.windows.net/scripts/$encodedBlobName"
}

Write-Output ""
Write-Output "All scripts uploaded successfully!"
```

**Alternative: Upload Individual Scripts**

If you only want specific scripts:

```powershell
# Upload specific scripts
$scriptsToUpload = @(
    "Enable Windows optimizations for AVD.ps1",
    "Install and enable FSLogix.ps1",
    "Configure Microsoft Teams optimizations.ps1",
    "Admin Sysprep.ps1"
)

foreach ($script in $scriptsToUpload) {
    $scriptPath = Join-Path $ScriptsPath $script
    if (Test-Path $scriptPath) {
        Set-AzStorageBlobContent `
            -File $scriptPath `
            -Container "scripts" `
            -Blob $script `
            -Context $ctx `
            -Force
        Write-Output "Uploaded: $script"
    }
}
```

**Alternative: Use Public URLs**

If you prefer to host scripts in GitHub or another public location:

```powershell
# No upload needed - use direct GitHub URLs in template
# Format: https://raw.githubusercontent.com/owner/repo/branch/path/to/script.ps1
```

---

### Step 2: Get Your Infrastructure Details

Collect the information you'll need for the image template:

```powershell
# Set variables from setup script output
$ResourceGroupName = "rg-avd-image-builder"
$SubscriptionId = "your-subscription-id"
$Location = "eastus"
$IdentityName = "umi-avd-image-builder"

# Get managed identity
$identity = Get-AzUserAssignedIdentity `
    -ResourceGroupName $ResourceGroupName `
    -Name $IdentityName

$identityId = $identity.Id
$identityPrincipalId = $identity.PrincipalId

# Get storage account (if created)
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName | 
    Select-Object -First 1

$StorageAccountName = $storageAccount.StorageAccountName

Write-Output "Identity Resource ID: $identityId"
Write-Output "Identity Principal ID: $identityPrincipalId"
Write-Output "Storage Account: $StorageAccountName"
Write-Output "Base URL: https://$StorageAccountName.blob.core.windows.net/scripts/"
```

**Save these values** - you'll need them in the next step!

---

### Step 3: Define Your Image Build Configuration

Before creating the template, decide on:

#### A. Source Image (Base Image)

Choose one of these options:

**Option 1: Azure Marketplace Image (Recommended)**
```powershell
# Windows 11 Enterprise Multi-user with Microsoft 365 Apps
$sourceImage = @{
    Publisher = "microsoftwindowsdesktop"
    Offer     = "office-365"
    Sku       = "win11-21h2-avd-m365"
    Version   = "latest"
}

# Windows 10 Enterprise Multi-user with Microsoft 365 Apps
$sourceImage = @{
    Publisher = "microsoftwindowsdesktop"
    Offer     = "office-365"
    Sku       = "win10-22h2-avd-m365"
    Version   = "latest"
}

# Windows 11 Enterprise Multi-user (without Office)
$sourceImage = @{
    Publisher = "microsoftwindowsdesktop"
    Offer     = "windows-11"
    Sku       = "win11-23h2-avd"
    Version   = "latest"
}
```

**Option 2: Existing Managed Image**
```powershell
$sourceImage = @{
    Id = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/images/your-existing-image"
}
```

**Option 3: Azure Compute Gallery Image**
```powershell
$sourceImage = @{
    Id = "/subscriptions/$SubscriptionId/resourceGroups/rg-gallery/providers/Microsoft.Compute/galleries/myGallery/images/myImageDefinition/versions/1.0.0"
}
```

#### B. Customization Scripts

Define which scripts to run and in what order:

```powershell
# Recommended script execution order
$customizations = @(
    @{
        type = "PowerShell"
        name = "01_WindowsOptimizations"
        scriptUri = "https://$StorageAccountName.blob.core.windows.net/scripts/Enable%20Windows%20optimizations%20for%20AVD.ps1"
        runElevated = $true
        inline = @(
            ".\\Enable Windows optimizations for AVD.ps1 -Optimizations All"
        )
    },
    @{
        type = "PowerShell"
        name = "02_RemoveAppXPackages"
        scriptUri = "https://$StorageAccountName.blob.core.windows.net/scripts/Remove%20AppX%20packages.ps1"
        runElevated = $true
        inline = @(
            ".\\Remove AppX packages.ps1 -AppxPackages @('Microsoft.XboxApp','Microsoft.GamingApp','Microsoft.BingNews','Microsoft.BingWeather','Microsoft.Getstarted','Microsoft.MicrosoftSolitaireCollection')"
        )
    },
    @{
        type = "PowerShell"
        name = "03_InstallFSLogix"
        scriptUri = "https://$StorageAccountName.blob.core.windows.net/scripts/Install%20and%20enable%20FSLogix.ps1"
        runElevated = $true
        inline = @(
            ".\\Install and enable FSLogix.ps1 -ProfilePath '\\yourstorageaccount.file.core.windows.net\profiles' -VHDSize 30000"
        )
    },
    @{
        type = "PowerShell"
        name = "04_ConfigureTeams"
        scriptUri = "https://$StorageAccountName.blob.core.windows.net/scripts/Configure%20Microsoft%20Teams%20optimizations.ps1"
        runElevated = $true
        inline = @(
            ".\\Configure Microsoft Teams optimizations.ps1 -TeamsDownloadLink 'https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409' -VCRedistributableLink 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -WebRTCInstaller 'https://aka.ms/msrdcwebrtcsvc/msi'"
        )
    },
    @{
        type = "PowerShell"
        name = "05_EnableScreenCaptureProtection"
        scriptUri = "https://$StorageAccountName.blob.core.windows.net/scripts/Enable%20Screen%20capture%20protection.ps1"
        runElevated = $true
        inline = @(
            ".\\Enable Screen capture protection.ps1 -BlockOption 'BlockClientAndServer'"
        )
    },
    @{
        type = "PowerShell"
        name = "06_ConfigureRDPShortpath"
        scriptUri = "https://$StorageAccountName.blob.core.windows.net/scripts/Configure%20RDP%20Shortpath%20for%20managed%20networks.ps1"
        runElevated = $true
    },
    @{
        type = "PowerShell"
        name = "07_AdminSysprep"
        scriptUri = "https://$StorageAccountName.blob.core.windows.net/scripts/Admin%20Sysprep.ps1"
        runElevated = $true
    }
)
```

**Important Notes:**
- Scripts run in the order defined in the array
- `Admin Sysprep.ps1` **MUST be last**
- Each script downloads from `scriptUri` first
- Then executes commands in `inline` array
- Use `\\` to escape backslashes in inline PowerShell

#### C. Distribution Target

Choose where to store the final image:

**Option 1: Managed Image (Simplest)**
```powershell
$distTarget = @{
    type = "ManagedImage"
    location = $Location
    imageId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/images/avd-golden-image-v1"
    runOutputName = "avd-golden-image-output"
}
```

**Option 2: Azure Compute Gallery (Recommended for Production)**
```powershell
# First, create gallery and definition if they don't exist
$galleryName = "avdImageGallery"
$imageDefinitionName = "avd-windows11-golden"

# Create gallery (one-time)
New-AzGallery -ResourceGroupName $ResourceGroupName -Name $galleryName -Location $Location

# Create image definition (one-time)
$imageDefinitionConfig = @{
    Location = $Location
    Publisher = "YourCompany"
    Offer = "AVD-Golden-Images"
    Sku = "Windows11-M365"
    OsState = "Generalized"
    OsType = "Windows"
    HyperVGeneration = "V2"
}

New-AzGalleryImageDefinition `
    -ResourceGroupName $ResourceGroupName `
    -GalleryName $galleryName `
    -Name $imageDefinitionName `
    @imageDefinitionConfig

# Distribution target
$distTarget = @{
    type = "SharedImage"
    galleryImageId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/galleries/$galleryName/images/$imageDefinitionName"
    replicationRegions = @($Location, "westus2")  # Multiple regions for geo-redundancy
    runOutputName = "avd-golden-image-output"
}
```

---

### Step 4: Create the Azure Image Builder Template

Now create the template using PowerShell or ARM template:

#### Method 1: PowerShell (Using Az.ImageBuilder Module)

```powershell
# Install preview module (if not already installed)
Install-Module -Name Az.ImageBuilder -AllowPrerelease -Force -Scope CurrentUser
Import-Module Az.ImageBuilder

# Image template name
$imageTemplateName = "avd-golden-image-template-v1"

# Create the template
Write-Output "Creating Azure Image Builder template: $imageTemplateName"

try {
    $template = New-AzImageBuilderTemplate `
        -ResourceGroupName $ResourceGroupName `
        -Name $imageTemplateName `
        -Location $Location `
        -IdentityType UserAssigned `
        -IdentityId $identityId `
        -SourceType MarketplaceImage `
        -SourcePublisher $sourceImage.Publisher `
        -SourceOffer $sourceImage.Offer `
        -SourceSku $sourceImage.Sku `
        -SourceVersion $sourceImage.Version `
        -Customize $customizations `
        -Distribute @($distTarget) `
        -VmSize "Standard_D2s_v3"  # Optional: Build VM size
        
    Write-Output "✓ Template created successfully!"
    Write-Output "  Template ID: $($template.Id)"
}
catch {
    Write-Error "Failed to create template: $_"
    exit 1
}
```

#### Method 2: ARM Template (JSON)

Save this as `image-template.json`:

```json
{
  "$schema": "http://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "imageTemplateName": {
      "type": "string",
      "defaultValue": "avd-golden-image-template-v1"
    },
    "managedIdentityResourceId": {
      "type": "string",
      "metadata": {
        "description": "Resource ID of the user-assigned managed identity"
      }
    },
    "storageAccountName": {
      "type": "string",
      "metadata": {
        "description": "Storage account name for script storage"
      }
    },
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]"
    },
    "fsLogixProfilePath": {
      "type": "string",
      "metadata": {
        "description": "SMB path for FSLogix profiles (e.g., \\\\storage.file.core.windows.net\\profiles)"
      }
    }
  },
  "variables": {
    "scriptBaseUrl": "[concat('https://', parameters('storageAccountName'), '.blob.core.windows.net/scripts/')]"
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
            "name": "01_WindowsOptimizations",
            "scriptUri": "[concat(variables('scriptBaseUrl'), 'Enable%20Windows%20optimizations%20for%20AVD.ps1')]",
            "runElevated": true,
            "inline": [
              ".\\Enable Windows optimizations for AVD.ps1 -Optimizations All"
            ]
          },
          {
            "type": "PowerShell",
            "name": "03_InstallFSLogix",
            "scriptUri": "[concat(variables('scriptBaseUrl'), 'Install%20and%20enable%20FSLogix.ps1')]",
            "runElevated": true,
            "inline": [
              "[concat('.\\Install and enable FSLogix.ps1 -ProfilePath ''', parameters('fsLogixProfilePath'), ''' -VHDSize 30000')]"
            ]
          },
          {
            "type": "PowerShell",
            "name": "04_ConfigureTeams",
            "scriptUri": "[concat(variables('scriptBaseUrl'), 'Configure%20Microsoft%20Teams%20optimizations.ps1')]",
            "runElevated": true,
            "inline": [
              ".\\Configure Microsoft Teams optimizations.ps1 -TeamsDownloadLink 'https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409' -VCRedistributableLink 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -WebRTCInstaller 'https://aka.ms/msrdcwebrtcsvc/msi'"
            ]
          },
          {
            "type": "PowerShell",
            "name": "07_AdminSysprep",
            "scriptUri": "[concat(variables('scriptBaseUrl'), 'Admin%20Sysprep.ps1')]",
            "runElevated": true
          }
        ],
        "distribute": [
          {
            "type": "ManagedImage",
            "location": "[parameters('location')]",
            "imageId": "[concat('/subscriptions/', subscription().subscriptionId, '/resourceGroups/', resourceGroup().name, '/providers/Microsoft.Compute/images/avd-golden-image-v1')]",
            "runOutputName": "avd-golden-image-output"
          }
        ],
        "vmProfile": {
          "vmSize": "Standard_D2s_v3"
        }
      }
    }
  ],
  "outputs": {
    "imageTemplateId": {
      "type": "string",
      "value": "[resourceId('Microsoft.VirtualMachineImages/imageTemplates', parameters('imageTemplateName'))]"
    },
    "managedIdentityId": {
      "type": "string",
      "value": "[parameters('managedIdentityResourceId')]"
    }
  }
}
```

Deploy with:

```powershell
New-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile ".\image-template.json" `
    -TemplateParameterObject @{
        imageTemplateName = "avd-golden-image-template-v1"
        managedIdentityResourceId = $identityId
        storageAccountName = $StorageAccountName
        fsLogixProfilePath = "\\yourstorageaccount.file.core.windows.net\profiles"
    }
```

---

### Step 5: Start the Image Build

Once the template is created, trigger the build:

```powershell
$imageTemplateName = "avd-golden-image-template-v1"

Write-Output "Starting image build..."
Write-Output "This will take approximately 60-90 minutes"

# Start the build
try {
    $buildJob = Invoke-AzImageBuilderTemplate `
        -ResourceGroupName $ResourceGroupName `
        -ImageTemplateName $imageTemplateName
        
    Write-Output "✓ Build started successfully!"
    Write-Output "  Build ID: $($buildJob.Id)"
    Write-Output ""
    Write-Output "The build process will:"
    Write-Output "  1. Create a temporary build VM (Standard_D2s_v3)"
    Write-Output "  2. Apply all customization scripts in sequence"
    Write-Output "  3. Generalize the image (sysprep)"
    Write-Output "  4. Capture the image"
    Write-Output "  5. Delete the build VM"
}
catch {
    Write-Error "Failed to start build: $_"
    exit 1
}
```

---

### Step 6: Monitor Build Progress

Monitor the build status:

```powershell
# Function to check build status
function Get-ImageBuildStatus {
    param(
        [string]$ResourceGroupName,
        [string]$ImageTemplateName
    )
    
    $template = Get-AzImageBuilderTemplate `
        -ResourceGroupName $ResourceGroupName `
        -Name $ImageTemplateName
    
    $status = $template.LastRunStatusRunState
    $startTime = $template.LastRunStatusRunStartTime
    $endTime = $template.LastRunStatusRunEndTime
    $message = $template.LastRunStatusMessage
    
    return @{
        Status = $status
        StartTime = $startTime
        EndTime = $endTime
        Message = $message
        Template = $template
    }
}

# Check status
$status = Get-ImageBuildStatus -ResourceGroupName $ResourceGroupName -ImageTemplateName $imageTemplateName

Write-Output "Build Status: $($status.Status)"
Write-Output "Start Time: $($status.StartTime)"
if ($status.EndTime) {
    Write-Output "End Time: $($status.EndTime)"
}
if ($status.Message) {
    Write-Output "Message: $($status.Message)"
}

# Possible status values:
# - Succeeded: Build completed successfully
# - Running: Build in progress
# - Canceled: Build was canceled
# - Failed: Build failed (check logs)
```

**Monitor Continuously:**

```powershell
$imageTemplateName = "avd-golden-image-template-v1"
$checkInterval = 60  # Check every 60 seconds

Write-Output "Monitoring build progress (checking every $checkInterval seconds)..."
Write-Output "Press Ctrl+C to stop monitoring"
Write-Output ""

while ($true) {
    $status = Get-ImageBuildStatus `
        -ResourceGroupName $ResourceGroupName `
        -ImageTemplateName $imageTemplateName
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] Status: $($status.Status)"
    
    if ($status.Status -eq "Succeeded") {
        Write-Output ""
        Write-Output "✓✓✓ BUILD COMPLETED SUCCESSFULLY! ✓✓✓"
        Write-Output ""
        
        # Get output image details
        $runOutput = Get-AzImageBuilderTemplateRunOutput `
            -ResourceGroupName $ResourceGroupName `
            -ImageTemplateName $imageTemplateName
        
        if ($runOutput) {
            Write-Output "Image Location: $($runOutput.ArtifactId)"
        }
        break
    }
    elseif ($status.Status -eq "Failed") {
        Write-Output ""
        Write-Error "✗✗✗ BUILD FAILED ✗✗✗"
        Write-Output "Error Message: $($status.Message)"
        Write-Output ""
        Write-Output "Troubleshooting steps:"
        Write-Output "1. Check build logs in Azure Portal"
        Write-Output "2. Verify script URLs are accessible"
        Write-Output "3. Check build VM in resource group (may not be deleted on failure)"
        break
    }
    elseif ($status.Status -eq "Canceled") {
        Write-Output ""
        Write-Warning "Build was canceled"
        break
    }
    
    Start-Sleep -Seconds $checkInterval
}
```

**Monitor in Azure Portal:**

1. Navigate to Resource Group → Your Image Template
2. Click "Run output" tab to see build logs
3. Check "Build VM" resource for detailed logs
4. View "Jobs" history for previous builds

---

### Step 7: Access the Built Image

Once the build succeeds, your image is ready:

#### If Using Managed Image:

```powershell
# Get the image
$imageName = "avd-golden-image-v1"
$image = Get-AzImage `
    -ResourceGroupName $ResourceGroupName `
    -ImageName $imageName

Write-Output "Image Ready!"
Write-Output "  Image ID: $($image.Id)"
Write-Output "  Location: $($image.Location)"
Write-Output "  Size: $($image.StorageProfile.OsDisk.DiskSizeGB) GB"
Write-Output "  Created: $($image.ProvisioningState)"

# Image ID format:
# /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/images/{image-name}
```

#### If Using Compute Gallery:

```powershell
# Get image version
$galleryName = "avdImageGallery"
$imageDefinitionName = "avd-windows11-golden"
$imageVersion = "1.0.0"

$galleryImage = Get-AzGalleryImageVersion `
    -ResourceGroupName $ResourceGroupName `
    -GalleryName $galleryName `
    -GalleryImageDefinitionName $imageDefinitionName `
    -Name $imageVersion

Write-Output "Image Version Ready!"
Write-Output "  Image Version ID: $($galleryImage.Id)"
Write-Output "  Replication Status:"
$galleryImage.PublishingProfile.TargetRegions | ForEach-Object {
    Write-Output "    - $($_.Name): $($_.RegionalReplicaCount) replica(s)"
}
```

---

### Step 8: Use the Image in AVD Host Pool

Now use your golden image when creating/updating AVD session hosts:

```powershell
# Example: Update host pool to use new image
$hostPoolName = "your-host-pool"
$hostPoolRG = "your-host-pool-rg"

# Managed Image
$imageId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/images/avd-golden-image-v1"

# Or Gallery Image
# $imageId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/galleries/$galleryName/images/$imageDefinitionName/versions/$imageVersion"

# Update host pool VM template (via Nerdio Manager API or Azure CLI)
# This varies based on your deployment method
```

**Via Azure Portal:**
1. Navigate to Azure Virtual Desktop → Host Pools
2. Select your host pool
3. Go to "Virtual machines" tab
4. Create new session hosts using your golden image
5. Or update existing VMs through scaling/update policies

---

### Step 9: Verify the Image

Before deploying to production, test the image:

```powershell
# Create a test VM from the image
$testVMName = "test-vm-golden-image"
$testVMConfig = New-AzVMConfig `
    -VMName $testVMName `
    -VMSize "Standard_D2s_v3" `
    -IdentityType SystemAssigned

$testVMConfig = Set-AzVMOperatingSystem `
    -VM $testVMConfig `
    -Windows `
    -ComputerName "testvm" `
    -Credential (Get-Credential)

$testVMConfig = Set-AzVMSourceImage `
    -VM $testVMConfig `
    -Id $imageId

$testVMConfig = Add-AzVMNetworkInterface `
    -VM $testVMConfig `
    -Id "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/networkInterfaces/test-nic"

New-AzVM `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -VM $testVMConfig

Write-Output "Test VM created. RDP to verify:"
Write-Output "  - Applications installed correctly"
Write-Output "  - Optimizations applied"
Write-Output "  - FSLogix configured"
Write-Output "  - Teams working"
```

---

## Troubleshooting Common Issues

### Build Fails Immediately

**Possible Causes:**
- Missing permissions on managed identity
- Invalid resource provider registration
- Network access issues

**Solutions:**
```powershell
# Re-check role assignments
Get-AzRoleAssignment -ObjectId $identityPrincipalId

# Re-check resource providers
Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages

# Check build VM network connectivity
# Look for build VM in resource group (IT_* naming)
```

### Script Download Failures

**Symptoms:**
- Build shows "Downloading script..." for long time
- Error: "Failed to download script"

**Solutions:**
```powershell
# Verify script URLs are accessible
$scriptUrl = "https://$StorageAccountName.blob.core.windows.net/scripts/Enable%20Windows%20optimizations%20for%20AVD.ps1"
Invoke-WebRequest -Uri $scriptUrl -Method Head

# Check storage account firewall settings
$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
$storageAccount.NetworkRuleSet

# Ensure build VM subnet has access
```

### Script Execution Errors

**Symptoms:**
- Build progresses but fails at specific script
- Error messages in build logs

**Solutions:**
```powershell
# Check build VM logs
# Build VM is named IT_* in your resource group
# Connect to VM and check:
#   C:\Packages\Plugins\Microsoft.CustomScriptExtension\*\Status
#   C:\WindowsAzure\Logs\Plugins\Microsoft.CustomScriptExtension

# Verify script syntax
# Test scripts locally before uploading

# Check parameter formats
# Ensure inline parameters use correct escaping
```

### Image Capture Failures

**Symptoms:**
- All scripts succeed but image capture fails
- Error: "Generalization failed"

**Solutions:**
```powershell
# Ensure Admin Sysprep script runs last
# Check sysprep logs on build VM
# Verify image name doesn't already exist (if using Managed Image)
Get-AzImage -ResourceGroupName $ResourceGroupName -ImageName "avd-golden-image-v1" -ErrorAction SilentlyContinue
```

---

## Next Steps & Best Practices

### Image Versioning

Create new versions for updates:

```powershell
# Increment version in template name
$imageTemplateName = "avd-golden-image-template-v2"
$imageName = "avd-golden-image-v2"
```

### Scheduled Rebuilds

Set up automation to rebuild images regularly:

```powershell
# Create Azure Automation runbook or Logic App
# Trigger rebuild weekly/monthly or when base image updates
```

### CI/CD Integration

Integrate with Azure DevOps or GitHub Actions:

```yaml
# Example GitHub Actions workflow
name: Build Golden Image
on:
  push:
    branches: [main]
    paths: ['scripted-actions/custom-image-template-scripts/**']

jobs:
  build-image:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Upload scripts
        run: az storage blob upload-batch ...
      - name: Create template
        run: az deployment group create ...
      - name: Start build
        run: az image builder template run ...
```

---

## Summary Checklist

After running the setup script, complete these steps:

- [ ] **Step 1**: Upload scripts to storage account
- [ ] **Step 2**: Collect infrastructure details (identity ID, storage account name)
- [ ] **Step 3**: Define your image configuration (source, scripts, distribution)
- [ ] **Step 4**: Create the Azure Image Builder template
- [ ] **Step 5**: Start the image build
- [ ] **Step 6**: Monitor build progress (60-90 minutes)
- [ ] **Step 7**: Verify image is created and accessible
- [ ] **Step 8**: Test image with a sample VM
- [ ] **Step 9**: Use image in AVD host pool

**Total Time:** ~2-3 hours (mostly waiting for build to complete)

---

## Quick Reference Commands

```powershell
# Upload scripts
Set-AzStorageBlobContent -Container scripts -File "script.ps1" -Context $ctx

# Create template
New-AzImageBuilderTemplate ... # (see Step 4)

# Start build
Invoke-AzImageBuilderTemplate -ResourceGroupName $rg -ImageTemplateName $name

# Monitor
Get-AzImageBuilderTemplate -ResourceGroupName $rg -Name $name

# Get result
Get-AzImage -ResourceGroupName $rg -ImageName "avd-golden-image-v1"
```

---

**You're now ready to build your first automated golden image!** 🚀
