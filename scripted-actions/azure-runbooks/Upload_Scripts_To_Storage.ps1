# Upload Custom Image Template Scripts to Azure Storage
# Run this after creating the storage container

<#
.SYNOPSIS
    Uploads all Custom Image Template Scripts to the storage account container

.DESCRIPTION
    This script uploads all PowerShell scripts from the custom-image-template-scripts
    directory to the Azure Storage blob container for use with Azure Image Builder.

.PARAMETER ResourceGroupName
    Resource group name where the storage account exists

.PARAMETER StorageAccountName
    Name of the storage account

.PARAMETER ScriptsPath
    Path to the custom-image-template-scripts directory
    Default: .\custom-image-template-scripts (relative to this script's location)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory = $false)]
    [string]$ScriptsPath = ""
)

$ErrorActionPreference = 'Stop'

Write-Output "========================================="
Write-Output "Upload Custom Image Template Scripts"
Write-Output "========================================="
Write-Output ""

# Determine scripts path
if ([string]::IsNullOrEmpty($ScriptsPath)) {
    # Default: look for custom-image-template-scripts relative to this script
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ScriptsPath = Join-Path (Split-Path -Parent $scriptDir) "custom-image-template-scripts"
}

if (-not (Test-Path $ScriptsPath)) {
    Write-Error "Scripts directory not found: $ScriptsPath"
    Write-Output "Please provide the correct path with -ScriptsPath parameter"
    exit 1
}

Write-Output "Scripts Source: $ScriptsPath"
Write-Output ""

# Get storage account and context
Write-Output "Connecting to storage account: $StorageAccountName"
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName `
    -ErrorAction Stop

$ctx = $storageAccount.Context

# Verify container exists
$container = Get-AzStorageContainer `
    -Name "scripts" `
    -Context $ctx `
    -ErrorAction SilentlyContinue

if (-not $container) {
    Write-Error "Container 'scripts' not found. Please create it first using Fix_Storage_Container.ps1"
    exit 1
}

Write-Output "✓ Connected to storage account"
Write-Output "✓ Container 'scripts' found"
Write-Output ""

# Get all PowerShell scripts
$scripts = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -File

if ($scripts.Count -eq 0) {
    Write-Error "No PowerShell scripts found in: $ScriptsPath"
    exit 1
}

Write-Output "Found $($scripts.Count) script(s) to upload:"
Write-Output ""

$uploaded = 0
$skipped = 0
$failed = 0

foreach ($script in $scripts) {
    try {
        # Check if blob already exists
        $existingBlob = Get-AzStorageBlob `
            -Container "scripts" `
            -Blob $script.Name `
            -Context $ctx `
            -ErrorAction SilentlyContinue
        
        if ($existingBlob) {
            Write-Output "  ⚠ Skipping (already exists): $($script.Name)"
            $skipped++
        }
        else {
            # Upload the script
            Set-AzStorageBlobContent `
                -File $script.FullName `
                -Container "scripts" `
                -Blob $script.Name `
                -Context $ctx `
                -Force | Out-Null
            
            Write-Output "  ✓ Uploaded: $($script.Name)"
            $uploaded++
        }
    }
    catch {
        Write-Output "  ✗ Failed: $($script.Name) - $_"
        $failed++
    }
}

Write-Output ""
Write-Output "========================================="
Write-Output "Upload Summary"
Write-Output "========================================="
Write-Output "  Uploaded: $uploaded"
Write-Output "  Skipped:  $skipped"
Write-Output "  Failed:   $failed"
Write-Output ""
Write-Output "========================================="
Write-Output "Next Steps"
Write-Output "========================================="
Write-Output ""
Write-Output "Scripts are now available at:"
Write-Output "  https://$StorageAccountName.blob.core.windows.net/scripts/<script-name>.ps1"
Write-Output ""
Write-Output "IMPORTANT: Since the container is private, you'll need to:"
Write-Output ""
Write-Output "1. Generate SAS tokens for each script URL when creating your image template"
Write-Output "   OR"
Write-Output "2. Configure storage account firewall to allow access from Azure services"
Write-Output ""
Write-Output "To generate SAS tokens, use:"
Write-Output "  New-AzStorageBlobSASToken -Container scripts -Blob 'script.ps1' -Permission r -Context `$ctx -ExpiryTime (Get-Date).AddMonths(6)"
Write-Output ""
Write-Output "For detailed instructions, see: POST_SETUP_GUIDE.md"
Write-Output ""
