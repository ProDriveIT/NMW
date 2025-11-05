#description: Downloads and extracts a folder to C:\ drive during image build
#tags: Nerdio, File deployment, Custom files

<#
Notes:
This script downloads a ZIP file containing a folder and extracts it to C:\ drive during the image build process.

There are two methods supported:
1. Download from GitHub (public repository) - Use GitHubRawUrl parameter
2. Download from Azure Blob Storage (private) - Use BlobStorageUrl and SAS token parameters

The ZIP file will be extracted to C:\ by default, but you can specify a subfolder with DestinationPath.

Example usage in Custom Image Template:
- Name: Upload Custom Folder
- URI: https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1
- Optional parameters (if using Azure Blob Storage):
  - BlobStorageUrl: https://[storageaccount].blob.core.windows.net/[container]/folder.zip
  - SASToken: [your SAS token]
- Or use GitHubRawUrl (if folder is in GitHub):
  - GitHubRawUrl: https://github.com/ProDriveIT/NMW/releases/download/v1.0/custom-folder.zip
#>

param(
    [string]$GitHubRawUrl = "",
    [string]$BlobStorageUrl = "",
    [string]$SASToken = "",
    [string]$DestinationPath = "C:\",
    [string]$ZipFileName = "custom-folder.zip"
)

# Create temp directory for download
$TempPath = "C:\Temp"
if (!(Test-Path -Path $TempPath)) {
    New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
}

$ZipFilePath = Join-Path $TempPath $ZipFileName

# Determine download URL
$DownloadUrl = $null
if ($GitHubRawUrl) {
    $DownloadUrl = $GitHubRawUrl
    Write-Host "Using GitHub URL: $DownloadUrl"
}
elseif ($BlobStorageUrl) {
    if ($SASToken) {
        $DownloadUrl = "${BlobStorageUrl}?${SASToken}"
        Write-Host "Using Azure Blob Storage URL with SAS token"
    }
    else {
        Write-Error "SAS token is required when using Azure Blob Storage URL"
        exit 1
    }
}
else {
    Write-Error "Either GitHubRawUrl or BlobStorageUrl must be provided"
    exit 1
}

# Download the ZIP file
Write-Host "Downloading folder ZIP file from: $DownloadUrl"
try {
    $ProgressPreference = 'SilentlyContinue' # Suppress progress bar for cleaner output
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipFilePath -UseBasicParsing -ErrorAction Stop
    Write-Host "Download completed successfully."
}
catch {
    Write-Error "Failed to download ZIP file: $_"
    exit 1
}

# Verify ZIP file was downloaded
if (!(Test-Path $ZipFilePath)) {
    Write-Error "Downloaded ZIP file not found at: $ZipFilePath"
    exit 1
}

Write-Host "ZIP file size: $((Get-Item $ZipFilePath).Length) bytes"

# Ensure destination path exists
if (!(Test-Path -Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    Write-Host "Created destination directory: $DestinationPath"
}

# Extract ZIP file
Write-Host "Extracting ZIP file to: $DestinationPath"
try {
    # Use .NET classes for extraction (built into Windows)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFilePath, $DestinationPath, $true) # $true = overwrite existing files
    Write-Host "Extraction completed successfully."
}
catch {
    Write-Error "Failed to extract ZIP file: $_"
    # Clean up
    if (Test-Path $ZipFilePath) {
        Remove-Item -Path $ZipFilePath -Force
    }
    exit 1
}

# Verify extraction
$ExtractedItems = Get-ChildItem -Path $DestinationPath -Recurse -ErrorAction SilentlyContinue
if ($ExtractedItems.Count -gt 0) {
    Write-Host "Successfully extracted $($ExtractedItems.Count) items to $DestinationPath"
}
else {
    Write-Warning "Extraction completed but no items found in destination path. Verify ZIP file contents."
}

# Clean up ZIP file
if (Test-Path $ZipFilePath) {
    Remove-Item -Path $ZipFilePath -Force
    Write-Host "ZIP file cleaned up."
}

Write-Host "Folder upload to C:\ drive completed successfully."

### End Script ###

