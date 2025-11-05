# Upload Folder to C:\ Drive During Image Build

This guide explains how to upload a folder to the C:\ drive during the Azure Virtual Desktop Custom Image Template build process.

## Overview

The build process uses a PowerShell script that downloads a ZIP file containing your folder and extracts it to C:\ drive. There are two methods available:

1. **GitHub Method** (Recommended for public files or small-medium folders)
2. **Azure Blob Storage Method** (Recommended for private files or large folders)

## Prerequisites

- Your folder ready to be uploaded
- Access to either:
  - GitHub repository (for Method 1), OR
  - Azure Storage Account (for Method 2)

---

## Method 1: Using GitHub (Recommended for Most Cases)

This method is best if:
- Your files are not sensitive/confidential
- Folder size is under ~100MB (GitHub has file size limits)
- You want a simple, version-controlled solution

### Step 1: Prepare Your Folder

1. **Create a ZIP file** of the folder you want to upload:
   - Right-click the folder → **Send to** → **Compressed (zipped) folder**
   - Or use PowerShell: `Compress-Archive -Path "C:\YourFolder" -DestinationPath "C:\YourFolder.zip"`

2. **Name your ZIP file** (e.g., `custom-folder.zip`, `company-assets.zip`)

### Step 2: Upload to GitHub

You have two options:

#### Option A: GitHub Releases (Recommended)
1. Go to your GitHub repository: `https://github.com/ProDriveIT/NMW`
2. Click **Releases** → **Create a new release**
3. Upload your ZIP file as a release asset
4. Copy the **direct download URL** (e.g., `https://github.com/ProDriveIT/NMW/releases/download/v1.0/custom-folder.zip`)

#### Option B: GitHub Repository (Alternative)
1. Create a folder in your repository (e.g., `assets/` or `build-files/`)
2. Upload the ZIP file to that folder
3. Use the raw GitHub URL: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/assets/custom-folder.zip`

### Step 3: Add Script to Custom Image Template

1. In Azure Portal, navigate to your **Custom Image Template**
2. Go to **Customizations** tab
3. Click **+ Add your own script**
4. Configure:
   - **Name**: `Upload Custom Folder to C Drive`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1`
   - **Optional parameters** (click **Advanced** if available):
     - `GitHubRawUrl`: `https://github.com/ProDriveIT/NMW/releases/download/v1.0/custom-folder.zip`
     - `DestinationPath`: `C:\` (default) or `C:\CustomFolder` (if you want a subfolder)
     - `ZipFileName`: `custom-folder.zip` (default)
5. Click **Save**

> **Note**: If the Custom Image Template wizard doesn't support script parameters, you'll need to modify the script URL or create a custom script wrapper. See "Alternative: Create Custom Script Wrapper" below.

---

## Method 2: Using Azure Blob Storage (Recommended for Private/Large Files)

This method is best if:
- Your files are sensitive/confidential
- Folder size is large (>100MB)
- You need better control over access

### Step 1: Upload ZIP to Azure Blob Storage

1. **Create a ZIP file** of your folder (same as Method 1, Step 1)

2. **Upload to Azure Blob Storage**:
   - In Azure Portal, navigate to your Storage Account
   - Go to **Containers** (or create a new container, e.g., `build-files`)
   - Click **Upload** → Select your ZIP file → Upload
   - Copy the **Blob URL** (e.g., `https://[storageaccount].blob.core.windows.net/build-files/custom-folder.zip`)

3. **Generate SAS Token**:
   - Click on your uploaded blob (ZIP file)
   - Click **Generate SAS token and URL**
   - Configure:
     - **Permissions**: Read only
     - **Expiry**: Set a date far in the future (e.g., 1 year from now)
   - Click **Generate SAS token and URL**
   - Copy the **SAS token** (the part after the `?` in the URL, e.g., `sv=2022-11-02&ss=b&srt=co&sp=r&se=2025-12-31T23:59:59Z&st=2024-01-01T00:00:00Z&sig=...`)

### Step 2: Add Script to Custom Image Template

1. In Azure Portal, navigate to your **Custom Image Template**
2. Go to **Customizations** tab
3. Click **+ Add your own script**
4. Configure:
   - **Name**: `Upload Custom Folder to C Drive`
   - **URI**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1`
   - **Optional parameters** (if supported):
     - `BlobStorageUrl`: `https://[storageaccount].blob.core.windows.net/build-files/custom-folder.zip`
     - `SASToken`: `sv=2022-11-02&ss=b&srt=co&sp=r&se=2025-12-31T23:59:59Z&st=2024-01-01T00:00:00Z&sig=...`
     - `DestinationPath`: `C:\` (default) or `C:\CustomFolder`
     - `ZipFileName`: `custom-folder.zip` (default)
5. Click **Save**

> **Note**: Custom Image Templates may not support script parameters directly. See "Alternative: Create Custom Script Wrapper" below.

---

## Alternative: Create Custom Script Wrapper

If the Custom Image Template wizard doesn't support script parameters, create a wrapper script with hardcoded values:

### Example: GitHub Wrapper Script

Create a new file: `scripted-actions/windows-scripts/upload-custom-folder.ps1`

```powershell
# Wrapper script for uploading custom folder
# This script calls the main upload script with your specific parameters

$GitHubRawUrl = "https://github.com/ProDriveIT/NMW/releases/download/v1.0/custom-folder.zip"
$DestinationPath = "C:\"
$ZipFileName = "custom-folder.zip"

# Download and execute the main script
$ScriptUrl = "https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1"
$ScriptPath = "$env:TEMP\upload-folder-script.ps1"

Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptPath -UseBasicParsing
& $ScriptPath -GitHubRawUrl $GitHubRawUrl -DestinationPath $DestinationPath -ZipFileName $ZipFileName
```

Then use this wrapper script URL in your Custom Image Template instead.

### Example: Azure Blob Storage Wrapper Script

Create a new file: `scripted-actions/windows-scripts/upload-custom-folder-private.ps1`

```powershell
# Wrapper script for uploading custom folder from Azure Blob Storage

$BlobStorageUrl = "https://[storageaccount].blob.core.windows.net/build-files/custom-folder.zip"
$SASToken = "sv=2022-11-02&ss=b&srt=co&sp=r&se=2025-12-31T23:59:59Z&st=2024-01-01T00:00:00Z&sig=..."
$DestinationPath = "C:\"
$ZipFileName = "custom-folder.zip"

# Download and execute the main script
$ScriptUrl = "https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1"
$ScriptPath = "$env:TEMP\upload-folder-script.ps1"

Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptPath -UseBasicParsing
& $ScriptPath -BlobStorageUrl $BlobStorageUrl -SASToken $SASToken -DestinationPath $DestinationPath -ZipFileName $ZipFileName
```

---

## Important Notes

### Script Execution Order

- Add the folder upload script **after** any scripts that might need the files
- If other scripts depend on the folder, ensure proper ordering in the Custom Image Template

### Destination Path

- Default: `C:\` - Files will be extracted directly to C:\
- Custom: `C:\CustomFolder` - Files will be extracted to a subfolder
- The script will create the destination directory if it doesn't exist

### File Permissions

- Files extracted to C:\ will be owned by SYSTEM
- If you need specific permissions, add a separate script after the upload script to set permissions

### Large Folders

- For very large folders (>500MB), consider:
  - Using Azure Blob Storage (Method 2)
  - Increasing build timeout in Build Properties
  - Splitting into multiple smaller ZIPs if possible

### Security

- **GitHub Method**: Files are publicly accessible (if using GitHub Releases)
- **Azure Blob Storage Method**: Files are private (requires SAS token)
- Store SAS tokens securely - never commit them to version control

---

## Troubleshooting

### Script Fails to Download ZIP

**Symptoms**: Error "Failed to download ZIP file"

**Solutions**:
- Verify the URL is accessible (try opening in browser)
- Check if GitHub rate limiting is blocking the download
- For Azure Blob Storage, verify SAS token is valid and not expired
- Ensure network connectivity during build

### Extraction Fails

**Symptoms**: Error "Failed to extract ZIP file"

**Solutions**:
- Verify ZIP file is not corrupted (try extracting manually)
- Check if destination path is writable (C:\ should always be writable)
- Ensure sufficient disk space on C:\ drive
- Check build logs for detailed error messages

### Files Not in Expected Location

**Symptoms**: Files extracted but not where expected

**Solutions**:
- Check the `DestinationPath` parameter value
- Verify ZIP file structure (extract manually to see folder structure)
- Review build logs to see where files were extracted

### Build Timeout

**Symptoms**: Build times out before script completes

**Solutions**:
- Increase build timeout in Build Properties (e.g., 300 minutes)
- Optimize ZIP file size (compress better, remove unnecessary files)
- Consider splitting into multiple smaller uploads

---

## Example Use Cases

### Company Assets Folder
- Upload company logos, templates, wallpapers to `C:\CompanyAssets`
- Use in image build so all users have access

### Custom Application Files
- Upload application configuration files, certificates, or data files
- Extract to `C:\ProgramData\[AppName]` for system-wide access

### Scripts and Tools
- Upload custom PowerShell scripts or utilities
- Extract to `C:\Scripts` or `C:\Tools`

### Configuration Files
- Upload registry files, configuration templates, or policy files
- Extract to appropriate system locations

---

## Script Reference

The main script is located at:
- **Path**: `scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1`
- **GitHub URL**: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1`

**Parameters**:
- `GitHubRawUrl` (string): GitHub URL to ZIP file (for Method 1)
- `BlobStorageUrl` (string): Azure Blob Storage URL to ZIP file (for Method 2)
- `SASToken` (string): SAS token for Azure Blob Storage access (required for Method 2)
- `DestinationPath` (string): Destination path on C:\ drive (default: `C:\`)
- `ZipFileName` (string): Name of ZIP file (default: `custom-folder.zip`)

---

For questions or issues, refer to the main [AVD Custom Image Template Quick Start Guide](./AVD_CIT_QUICK_START.md).

