# Configure Azure Storage Account Access for Custom Image Templates

This guide explains how to configure your Azure Storage Account so that Custom Image Template (CIT) build VMs can access and download ZIP files from private blob containers.

## Overview

When using Azure Blob Storage to host large ZIP files for your CIT builds, you need to configure:

1. **Network Access**: Allow the build VM to reach the storage account
2. **Authentication**: Generate a SAS token with appropriate permissions
3. **Container Permissions**: Ensure the container allows the access method

---

## Prerequisites

- Azure Storage Account created
- ZIP file uploaded to a blob container
- Access to Azure Portal or Azure PowerShell

---

## Step 1: Configure Storage Account Network Access

The CIT build VM runs in Azure and needs network access to your storage account. You have two options:

### Option A: Allow Azure Services (Recommended)

This is the simplest and most secure method. It allows any Azure service (including CIT build VMs) to access your storage account.

#### Via Azure Portal:

1. Navigate to your **Storage Account** in Azure Portal
2. Go to **Networking** (under Security + networking)
3. Under **Network access**, select:
   - **Public network access**: Choose based on your security requirements
   - **Firewalls and virtual networks**: 
     - Select **Enabled from selected virtual networks and IP addresses**
     - Check **Allow Azure services on the trusted services list to access this storage account** ✓
     - Set **Default action** to **Allow** (or configure specific IP/subnet rules)
4. Click **Save**

#### Via PowerShell:

```powershell
# Connect to Azure
Connect-AzAccount

# Set variables
$ResourceGroupName = "your-resource-group"
$StorageAccountName = "your-storage-account"

# Get storage account
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName

# Update network rules to allow Azure services
$networkRuleSet = $storageAccount.NetworkRuleSet
$networkRuleSet.Bypass = "AzureServices"
$networkRuleSet.DefaultAction = "Allow"

Update-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName `
    -NetworkRuleSet $networkRuleSet
```

#### Using the Provided Script:

We have a ready-made script to configure this:

```powershell
# Run the configuration script
.\scripted-actions\extras\azure-runbooks\Fix_Storage_Access_Simple.ps1 `
    -ResourceGroupName "your-resource-group" `
    -StorageAccountName "your-storage-account"
```

### Option B: Allow Specific IP Addresses or Subnets

If you need more restrictive access:

1. Navigate to **Storage Account** → **Networking**
2. Under **Firewalls and virtual networks**:
   - Enable **Allow Azure services** ✓
   - Add specific IP addresses or virtual network subnets
   - Set **Default action** to **Deny**
3. Click **Save**

> **Note**: Option A (Allow Azure Services) is recommended because CIT build VMs use dynamic IP addresses that change with each build.

---

## Step 2: Generate SAS Token for Blob Access

A SAS (Shared Access Signature) token provides secure, time-limited access to your blob without exposing storage account keys.

### Via Azure Portal:

1. Navigate to your **Storage Account** → **Containers**
2. Click on the container containing your ZIP file
3. Click on the **ZIP file blob**
4. Click **Generate SAS token and URL** (or right-click → **Generate SAS**)
5. Configure the SAS token:
   - **Signing key**: `Key1` (default)
   - **Permissions**: 
     - ✓ **Read** (required - this is the only permission needed)
     - Uncheck all other permissions (Write, Delete, List, Add, Create, etc.)
     - **Why only Read?** The script downloads the blob to the local VM and extracts it there. No blob modifications are performed, so only Read permission is required.
   - **Start time**: Current date/time (or leave blank for immediate access)
   - **Expiry time**: Set far in the future (e.g., 1-2 years from now)
     - **Important**: Set a long expiry since the token will be used in your CIT script
   - **Allowed IP addresses**: Leave blank (or restrict if needed)
6. Click **Generate SAS token and URL**
7. Copy the **SAS token** (the part after the `?` in the Blob SAS URL)
   - Example: `sv=2022-11-02&ss=b&srt=co&sp=r&se=2025-12-31T23:59:59Z&st=2024-01-01T00:00:00Z&sig=...`

### Via PowerShell:

```powershell
# Set variables
$ResourceGroupName = "your-resource-group"
$StorageAccountName = "your-storage-account"
$ContainerName = "build-files"
$BlobName = "custom-folder.zip"

# Get storage account context
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName

$ctx = $storageAccount.Context

# Generate SAS token with read permission only, valid for 1 year
# Note: Only 'r' (read) permission is needed because the script only downloads the blob.
# The extraction happens locally on the VM, so no write/delete permissions are required.
$sasToken = New-AzStorageBlobSASToken `
    -Container $ContainerName `
    -Blob $BlobName `
    -Context $ctx `
    -Permission r `
    -ExpiryTime (Get-Date).AddYears(1) `
    -StartTime (Get-Date)

Write-Host "SAS Token: $sasToken"
Write-Host ""
Write-Host "Full URL: https://$StorageAccountName.blob.core.windows.net/$ContainerName/$BlobName?$sasToken"
```

### Via Azure CLI:

```bash
# Generate SAS token
az storage blob generate-sas \
    --account-name your-storage-account \
    --container-name build-files \
    --name custom-folder.zip \
    --permissions r \
    --expiry 2025-12-31T23:59:59Z \
    --output tsv
```

---

## Step 3: Configure Container Access Level

Ensure your container allows the access method you're using:

1. Navigate to **Storage Account** → **Containers**
2. Click on your container
3. Click **Change access level**
4. Choose:
   - **Private (no anonymous access)**: Use with SAS tokens (recommended)
   - **Blob (anonymous read access for blobs only)**: Public access (not recommended for sensitive files)
   - **Container (anonymous read access for container and blobs)**: Public access (not recommended)

> **Note**: For private files, use **Private** access level with SAS tokens.

---

## Step 4: Verify Access

Before using in your CIT, verify the SAS token works:

### Test via Browser:

1. Construct the full URL: `https://[storageaccount].blob.core.windows.net/[container]/[file.zip]?[SAS-token]`
2. Paste into a browser
3. The ZIP file should download (or prompt to download)

### Test via PowerShell:

```powershell
# Test download
$BlobUrl = "https://yourstorageaccount.blob.core.windows.net/build-files/custom-folder.zip"
$SasToken = "sv=2022-11-02&ss=b&srt=co&sp=r&se=2025-12-31T23:59:59Z&st=2024-01-01T00:00:00Z&sig=..."
$FullUrl = "$BlobUrl?$SasToken"

try {
    $response = Invoke-WebRequest -Uri $FullUrl -Method Head -UseBasicParsing
    Write-Host "✓ Access verified! Status: $($response.StatusCode)"
}
catch {
    Write-Error "✗ Access denied: $_"
}
```

---

## Step 5: Use in Custom Image Template

Once your storage account is configured and you have a SAS token, add the upload script to your CIT:

### Method 1: Using Script Parameters (if supported)

1. In Azure Portal, navigate to your **Custom Image Template**
2. Go to **Customizations** tab
3. Click **+ Add your own script**
4. Configure:
   - **Name**: `Upload Custom Folder from Storage Account`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1`
   - **Parameters** (if supported):
     - `BlobStorageUrl`: `https://[storageaccount].blob.core.windows.net/[container]/custom-folder.zip`
     - `SASToken`: `[your-sas-token]`
     - `DestinationPath`: `C:\` (or `C:\CustomFolder`)
     - `ZipFileName`: `custom-folder.zip`
5. Click **Save**

### Method 2: Create Wrapper Script (Recommended)

Since CIT may not support script parameters, create a wrapper script:

1. Create a new file: `scripted-actions/windows-scripts/upload-cch-folder.ps1`

```powershell
# Wrapper script for uploading CCH folder from Azure Blob Storage
# Replace the values below with your actual storage account details

$BlobStorageUrl = "https://yourstorageaccount.blob.core.windows.net/build-files/cch-folder.zip"
$SASToken = "sv=2022-11-02&ss=b&srt=co&sp=r&se=2025-12-31T23:59:59Z&st=2024-01-01T00:00:00Z&sig=YOUR_SAS_TOKEN_HERE"
$DestinationPath = "C:\"
$ZipFileName = "cch-folder.zip"

# Download and execute the main script
$ScriptUrl = "https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1"
$ScriptPath = "$env:TEMP\upload-folder-script.ps1"

try {
    Write-Host "Downloading upload script..."
    Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptPath -UseBasicParsing -ErrorAction Stop
    
    Write-Host "Executing upload script..."
    & $ScriptPath -BlobStorageUrl $BlobStorageUrl -SASToken $SASToken -DestinationPath $DestinationPath -ZipFileName $ZipFileName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Upload completed successfully."
    }
    else {
        Write-Error "Upload failed with exit code: $LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-Error "Failed to download or execute upload script: $_"
    exit 1
}
finally {
    # Clean up
    if (Test-Path $ScriptPath) {
        Remove-Item -Path $ScriptPath -Force -ErrorAction SilentlyContinue
    }
}
```

2. Upload this wrapper script to your GitHub repository
3. Use the wrapper script URL in your CIT instead of the main script

---

## Security Best Practices

### 1. SAS Token Security

- **Long Expiry**: Set SAS tokens to expire 1-2 years in the future (since they're used in automated builds)
- **Minimal Permissions**: Only grant **Read** permission (not Write, Delete, etc.)
- **Scope**: Generate SAS token at the **blob level** (not container or account level) for least privilege
- **Storage**: Never commit SAS tokens to version control - use wrapper scripts or secure parameter storage

### 2. Network Security

- **Use Private Containers**: Keep containers private and use SAS tokens
- **Allow Azure Services**: Use "Allow Azure services" bypass for CIT builds (simpler than IP whitelisting)
- **Monitor Access**: Review storage account access logs regularly

### 3. Storage Account Security

- **Enable Soft Delete**: Protect against accidental deletion
- **Enable Versioning**: Track changes to blobs
- **Use Managed Identity**: If possible, use managed identity instead of SAS tokens (requires additional configuration)

---

## Troubleshooting

### Error: "403 Forbidden" or "Authorization Permission Mismatch"

**Cause**: Storage account firewall is blocking access.

**Solution**:
1. Verify "Allow Azure services" is enabled in Storage Account → Networking
2. Check that Default Action is set to "Allow" (or specific rules are configured)
3. Run the fix script: `Fix_Storage_Access_Simple.ps1`

### Error: "SAS token is expired" or "Signature did not match"

**Cause**: SAS token is invalid, expired, or incorrectly formatted.

**Solution**:
1. Verify the SAS token hasn't expired (check expiry time)
2. Ensure the token includes the `?` separator: `https://...blob.core.windows.net/container/file.zip?sv=...`
3. Regenerate the SAS token with a longer expiry time
4. Verify you copied the entire token (they can be very long)

### Error: "Container not found" or "Blob not found"

**Cause**: Incorrect URL or blob doesn't exist.

**Solution**:
1. Verify the blob URL is correct: `https://[account].blob.core.windows.net/[container]/[blob]`
2. Check that the container and blob names match exactly (case-sensitive)
3. Verify the blob exists in Azure Portal

### Error: "Network is unreachable" or "Connection timeout"

**Cause**: Network connectivity issues or firewall blocking.

**Solution**:
1. Verify the build VM has internet access
2. Check storage account firewall settings
3. Ensure "Allow Azure services" is enabled
4. Test the URL from a browser or PowerShell to verify it's accessible

### Build Fails During Download

**Cause**: Large file download timing out or network issues.

**Solution**:
1. Increase build timeout in CIT Build Properties
2. Verify network connectivity during build
3. Consider splitting large ZIPs into smaller files
4. Check build logs for specific error messages

---

## Quick Reference Checklist

Before using Azure Blob Storage in your CIT:

- [ ] Storage account created
- [ ] ZIP file uploaded to blob container
- [ ] Container access level set to **Private**
- [ ] Storage account networking configured:
  - [ ] "Allow Azure services" enabled ✓
  - [ ] Default action set appropriately
- [ ] SAS token generated with:
  - [ ] **Read** permission only
  - [ ] Long expiry (1-2 years)
  - [ ] Blob-level scope
- [ ] SAS token tested (download works)
- [ ] Wrapper script created (if needed) with SAS token
- [ ] Script added to CIT customizations
- [ ] Build tested and verified

---

## Additional Resources

- [Azure Storage Account Networking Documentation](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security)
- [SAS Token Best Practices](https://learn.microsoft.com/en-us/azure/storage/common/storage-sas-overview)
- [Custom Image Template Documentation](./AVD_CIT_QUICK_START.md)
- [Upload Folder Script Documentation](./UPLOAD_FOLDER_TO_C_DRIVE.md)

---

For questions or issues, refer to the main [AVD Custom Image Template Quick Start Guide](./AVD_CIT_QUICK_START.md).

