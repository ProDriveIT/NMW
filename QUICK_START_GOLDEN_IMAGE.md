# Quick Start: Automated Golden Image Creation

## Overview

This guide walks you through creating a fully automated golden image build pipeline using the Custom Image Template Scripts without ever needing to log into a VM.

## Prerequisites

- Azure subscription with Contributor or Owner role
- Azure PowerShell module installed (`Install-Module Az`)
- Your Custom Image Template Scripts (already in this repo)

## Option 1: Using Azure AVD Custom Image Templates (Easiest)

### Steps:

1. **Navigate to Azure Portal**
   - Go to Azure Virtual Desktop → Custom Image Templates
   - Click "Create"

2. **Configure Image Template**
   - **Source Image**: Select base image (e.g., Windows 11 Enterprise Multi-user)
   - **Scripts**: 
     - Use built-in catalog OR
     - Provide script URLs from your storage account
   - **Distribution**: Choose Managed Image or Compute Gallery
   
3. **Start Build**
   - Review and create
   - Monitor in "Jobs" tab
   - Done! Image is automatically captured

**✅ Azure automatically creates all infrastructure for you**

---

## Option 2: Using Azure Image Builder Directly (Full Control)

### Step 1: Setup Infrastructure

Run the setup script:

```powershell
.\scripted-actions\azure-runbooks\Setup-AzureImageBuilderInfrastructure.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "rg-avd-image-builder" `
    -Location "eastus" `
    -CreateStorageAccount $true
```

This creates:
- Resource group
- Managed identity with proper permissions
- Storage account for scripts (optional)

### Step 2: Upload Scripts to Storage

```powershell
# Get storage context
$storageAccount = Get-AzStorageAccount -ResourceGroupName "rg-avd-image-builder" -Name "<storage-account-name>"
$ctx = $storageAccount.Context

# Upload all scripts
Get-ChildItem -Path ".\scripted-actions\custom-image-template-scripts\*.ps1" | ForEach-Object {
    Set-AzStorageBlobContent `
        -File $_.FullName `
        -Container "scripts" `
        -Blob $_.Name `
        -Context $ctx `
        -Force
    Write-Output "Uploaded: $($_.Name)"
}
```

### Step 3: Create Image Builder Template

See `CUSTOM_IMAGE_TEMPLATE_SCRIPTS_PLAN.md` for detailed template examples.

**Quick Example:**

```powershell
# Install preview module
Install-Module -Name Az.ImageBuilder -AllowPrerelease -Force

# Get identity
$identity = Get-AzUserAssignedIdentity -ResourceGroupName "rg-avd-image-builder" -Name "umi-avd-image-builder"

# Create template
New-AzImageBuilderTemplate `
    -ResourceGroupName "rg-avd-image-builder" `
    -Name "avd-golden-image-template" `
    -Location "eastus" `
    -IdentityType UserAssigned `
    -IdentityId $identity.Id `
    -SourceType MarketplaceImage `
    -SourcePublisher "microsoftwindowsdesktop" `
    -SourceOffer "office-365" `
    -SourceSku "win11-21h2-avd-m365" `
    -SourceVersion "latest" `
    -Customize @(
        @{
            type = "PowerShell"
            name = "WindowsOptimizations"
            scriptUri = "https://<storage-account>.blob.core.windows.net/scripts/Enable%20Windows%20optimizations%20for%20AVD.ps1"
            runElevated = $true
            inline = @(".\\Enable Windows optimizations for AVD.ps1 -Optimizations All")
        },
        @{
            type = "PowerShell"
            name = "InstallFSLogix"
            scriptUri = "https://<storage-account>.blob.core.windows.net/scripts/Install%20and%20enable%20FSLogix.ps1"
            runElevated = $true
            inline = @(".\\Install and enable FSLogix.ps1 -ProfilePath '\\<storage>.file.core.windows.net\profiles' -VHDSize 30000")
        },
        @{
            type = "PowerShell"
            name = "ConfigureTeams"
            scriptUri = "https://<storage-account>.blob.core.windows.net/scripts/Configure%20Microsoft%20Teams%20optimizations.ps1"
            runElevated = $true
            inline = @(".\\Configure Microsoft Teams optimizations.ps1 -TeamsDownloadLink 'https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409' -VCRedistributableLink 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -WebRTCInstaller 'https://aka.ms/msrdcwebrtcsvc/msi'")
        },
        @{
            type = "PowerShell"
            name = "AdminSysprep"
            scriptUri = "https://<storage-account>.blob.core.windows.net/scripts/Admin%20Sysprep.ps1"
            runElevated = $true
        }
    ) `
    -Distribute @(
        @{
            type = "ManagedImage"
            location = "eastus"
            imageId = "/subscriptions/<sub-id>/resourceGroups/rg-avd-image-builder/providers/Microsoft.Compute/images/avd-golden-image"
        }
    )
```

### Step 4: Run the Build

```powershell
# Start build
Invoke-AzImageBuilderTemplate `
    -ResourceGroupName "rg-avd-image-builder" `
    -ImageTemplateName "avd-golden-image-template"

# Monitor progress
Get-AzImageBuilderTemplate `
    -ResourceGroupName "rg-avd-image-builder" `
    -Name "avd-golden-image-template" `
    | Select-Object -ExpandProperty LastRunStatusRunState
```

---

## Recommended Script Execution Order

When building your image template, execute scripts in this order:

1. **Enable Windows optimizations for AVD** - Removes bloatware, disables unnecessary services
2. **Remove AppX packages** - Clean up Windows Store apps (optional but recommended)
3. **Install and enable FSLogix** - Profile container setup
4. **Configure Microsoft Office packages** - If customizing Office apps
5. **Configure Microsoft Teams optimizations** - Teams installation and optimization
6. **Enable Screen capture protection** - Security configuration
7. **Configure RDP Shortpath for managed networks** - Performance optimization
8. **Enable time zone redirection** - User experience
9. **Admin Sysprep** - **MUST BE LAST** - Prepares image for deployment

---

## What Each Script Does

| Script | Purpose | Required Parameters |
|--------|---------|---------------------|
| `Enable Windows optimizations for AVD.ps1` | Comprehensive VDI optimizations | `-Optimizations All` or specific categories |
| `Install and enable FSLogix.ps1` | FSLogix installation and config | `-ProfilePath` (SMB path), `-VHDSize` (optional) |
| `Configure Microsoft Teams optimizations.ps1` | Teams installation for AVD | `-TeamsDownloadLink`, `-VCRedistributableLink`, `-WebRTCInstaller` |
| `Remove AppX packages.ps1` | Remove bloatware | `-AppxPackages` (array of package names) |
| `Enable Screen capture protection.ps1` | Security hardening | `-BlockOption` (BlockClient, BlockClientAndServer) |
| `Configure RDP Shortpath for managed networks.ps1` | Performance optimization | None |
| `Admin Sysprep.ps1` | Image generalization | None (modifies default sysprep) |

---

## Script Parameters Quick Reference

### Windows Optimizations
```powershell
# Full optimization
-Optimizations All

# Specific categories
-Optimizations @('Services','ScheduledTasks','NetworkOptimizations','DiskCleanup')
```

### FSLogix Configuration
```powershell
-ProfilePath "\\storageaccount.file.core.windows.net\profiles"
-VHDSize 30000  # Size in MB (optional, default: 30000)
```

### Teams Configuration
```powershell
-TeamsDownloadLink "https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409"  # Teams 2.0
-VCRedistributableLink "https://aka.ms/vs/17/release/vc_redist.x64.exe"
-WebRTCInstaller "https://aka.ms/msrdcwebrtcsvc/msi"
```

### AppX Package Removal
```powershell
-AppxPackages @('Microsoft.XboxApp','Microsoft.GamingApp','Microsoft.BingNews')
```

---

## Troubleshooting

### Build Fails at Script Stage
- **Check logs**: View build VM logs in Azure Portal
- **Verify URLs**: Ensure script URLs are accessible
- **Network**: Confirm build VM has outbound Internet access
- **Permissions**: Verify managed identity has Contributor role

### Script Execution Errors
- **Syntax**: Check inline PowerShell syntax (especially escaping)
- **Parameters**: Verify all required parameters are provided
- **Paths**: Ensure file paths use forward slashes or escaped backslashes in inline scripts

### Image Not Created
- **Sysprep**: Ensure Admin Sysprep script ran successfully
- **Permissions**: Check managed identity permissions on distribution target
- **Image Name**: Verify image name doesn't already exist (if using Managed Image)

---

## Expected Build Times

- **Base Image**: 10-15 minutes (VM creation)
- **Windows Optimizations**: 15-30 minutes
- **FSLogix Installation**: 5-10 minutes
- **Teams Installation**: 10-15 minutes
- **Other Scripts**: 2-5 minutes each
- **Image Capture**: 10-15 minutes

**Total**: Approximately **60-90 minutes** for a complete build

---

## Next Steps After Image Creation

1. **Test the Image**
   - Create a test VM from the captured image
   - Verify applications and configurations
   - Test user login and profile mounting

2. **Distribute to Compute Gallery** (if using)
   - Create image definition and version in gallery
   - Replicate to multiple regions if needed

3. **Update Host Pool**
   - Update host pool to use new image
   - Configure autoscale if needed
   - Monitor session hosts for issues

4. **Version Management**
   - Use image versioning in Compute Gallery
   - Keep previous versions for rollback capability
   - Document changes in each version

---

## Additional Resources

- **Detailed Plan**: See `CUSTOM_IMAGE_TEMPLATE_SCRIPTS_PLAN.md`
- **Microsoft Docs**: [Azure Image Builder Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/image-builder-overview)
- **AVD Custom Image Templates**: [Azure Portal → AVD → Custom Image Templates](https://portal.azure.com)

---

## Summary

✅ **Fully Automated**: No manual VM access required  
✅ **Repeatable**: Same scripts, same results every time  
✅ **Scalable**: Build once, deploy many times  
✅ **Maintainable**: Update scripts, rebuild image  

Your golden images are now built automatically! 🚀
