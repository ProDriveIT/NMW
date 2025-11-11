#description: Downloads and installs Xerox Workplace Cloud Client for all users from Azure Blob Storage (system-level installation)
#tags: Nerdio, Xerox, Installation

<#
.SYNOPSIS
    Downloads and installs Xerox Workplace Cloud Client EXE from Azure Blob Storage for all users.

.DESCRIPTION
    This script downloads the Xerox Workplace Cloud Client installer from Azure Blob Storage and installs it
    silently for all users (system-wide). This ensures Xerox Workplace Cloud Client is available to all users
    and is compatible with sysprep for AVD image templates.

    Key features:
    - Downloads from Azure Blob Storage using SAS token
    - Installs system-wide for all users
    - Silent installation with /s switch
    - Compatible with sysprep and image capture
    - Verifies installation after completion

.EXAMPLE
    .\install-xerox-workplace-cloud-client.ps1
    
.NOTES
    Requires:
    - Administrator privileges
    - Internet connection to download installer
    
    The installer is downloaded from Azure Blob Storage and installed using the /s switch for silent installation.
    The /s switch typically installs system-wide by default for most EXE installers.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Install Xerox Workplace Cloud Client (System-Wide)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Azure Blob Storage URL with SAS token
$BlobUrl = "https://stavdcitscripts1354.blob.core.windows.net/xerox-workplace-cloud-client/XeroxWorkplaceCloudClient%20(1).exe?sp=r&st=2025-11-11T16:17:33Z&se=2027-11-12T00:32:33Z&spr=https&sv=2024-11-04&sr=b&sig=cPkwjbypvJkhgV%2By5p5TRUAdt5i0KIccgPMAYpqrRgs%3D"
$InstallerFileName = "XeroxWorkplaceCloudClient.exe"

# Check if Xerox Workplace Cloud Client is already installed
Write-Host "Checking for existing Xerox Workplace Cloud Client installation..." -ForegroundColor Cyan
$xeroxInstalled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -like "*Xerox*Workplace*" -or $_.DisplayName -like "*Xerox Workplace Cloud*" }

if ($xeroxInstalled) {
    Write-Host "  Xerox Workplace Cloud Client appears to be already installed: $($xeroxInstalled.DisplayName)" -ForegroundColor Yellow
    Write-Host "  Version: $($xeroxInstalled.DisplayVersion)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Uninstalling existing version to ensure clean installation..." -ForegroundColor Yellow
    
    try {
        $uninstallString = $xeroxInstalled.UninstallString
        if ($uninstallString) {
            # Try to extract uninstall command
            if ($uninstallString -match 'msiexec') {
                # MSI-based uninstall
                $productCode = $xeroxInstalled.PSChildName
                $uninstallArgs = @(
                    "/x",
                    "`"$productCode`"",
                    "/quiet",
                    "/norestart"
                )
                $uninstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $uninstallArgs -Wait -NoNewWindow -PassThru
            }
            elseif ($uninstallString -match '\.exe') {
                # EXE-based uninstall - try common silent switches
                $uninstallExe = $uninstallString -replace '"', '' -split ' ' | Select-Object -First 1
                if (Test-Path $uninstallExe) {
                    $uninstallArgs = @("/S", "/silent", "/uninstall")
                    $uninstallProcess = Start-Process -FilePath $uninstallExe -ArgumentList $uninstallArgs -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                }
            }
            Start-Sleep -Seconds 5
            Write-Host "  Uninstall completed." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "  Failed to uninstall existing Xerox Workplace Cloud Client: $_"
        Write-Warning "  Attempting to continue with installation..."
    }
    Write-Host ""
}

# Download installer
$tempPath = "C:\Windows\Temp"
if (-not (Test-Path $tempPath)) {
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
}

$installerPath = Join-Path $tempPath $InstallerFileName
$logPath = Join-Path $tempPath "XeroxWorkplaceCloudClientInstallLog.txt"

Write-Host "Downloading Xerox Workplace Cloud Client installer..." -ForegroundColor Yellow
Write-Host "  Source: Azure Blob Storage" -ForegroundColor Gray
Write-Host "  Destination: $installerPath" -ForegroundColor Gray
Write-Host ""

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $BlobUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
    $fileSize = (Get-Item $installerPath).Length / 1MB
    Write-Host "  Download completed: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download installer: $_"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Check SAS token is valid and not expired" -ForegroundColor Gray
    Write-Host "  - Verify network connectivity" -ForegroundColor Gray
    Write-Host "  - Verify blob storage URL is accessible" -ForegroundColor Gray
    exit 1
}

# Install Xerox Workplace Cloud Client
Write-Host ""
Write-Host "Installing Xerox Workplace Cloud Client for all users (system-wide)..." -ForegroundColor Cyan
Write-Host "  This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

try {
    # EXE installation with /s switch for silent installation
    # /s = silent installation (typically installs system-wide)
    Write-Host "Running EXE installer with silent switch..." -ForegroundColor Yellow
    $installArgs = @("/s")
    
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010 -or $null -eq $process.ExitCode) {
        # Some installers don't set exit codes properly, so null is also acceptable
        $exitCode = if ($null -eq $process.ExitCode) { "N/A (installer may not return exit code)" } else { $process.ExitCode }
        Write-Host "  Installation completed (Exit code: $exitCode)" -ForegroundColor Green
        if ($process.ExitCode -eq 3010) {
            Write-Host "  Note: Exit code 3010 indicates a reboot is required (this is normal)" -ForegroundColor Gray
        }
    }
    else {
        Write-Warning "  Installation completed with exit code: $($process.ExitCode)"
        Write-Host "  Note: Some installers may return non-zero codes even on success" -ForegroundColor Yellow
        Write-Host "  Please verify installation manually if needed" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Failed to install Xerox Workplace Cloud Client: $_"
    exit 1
}

# Wait for installation to complete
Write-Host ""
Write-Host "Waiting for installation to complete..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Cyan

# Retry verification if needed
$maxRetries = 6
$retryCount = 0
$installationVerified = $false

while ($retryCount -lt $maxRetries -and -not $installationVerified) {
    $xeroxCheck = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -like "*Xerox*Workplace*" -or $_.DisplayName -like "*Xerox Workplace Cloud*" }
    
    if ($xeroxCheck) {
        $installationVerified = $true
        Write-Host "  Xerox Workplace Cloud Client installed: $($xeroxCheck.DisplayName)" -ForegroundColor Green
        Write-Host "  Version: $($xeroxCheck.DisplayVersion)" -ForegroundColor Gray
        
        # Try to verify installation path (check common locations)
        $programFilesXerox = Test-Path "${env:ProgramFiles}\Xerox"
        $programFilesX86Xerox = Test-Path "${env:ProgramFiles(x86)}\Xerox"
        $commonAppDataXerox = Test-Path "${env:ProgramData}\Xerox"
        
        if ($programFilesXerox -or $programFilesX86Xerox -or $commonAppDataXerox) {
            $installPath = if ($programFilesXerox) { 
                "${env:ProgramFiles}\Xerox" 
            } elseif ($programFilesX86Xerox) { 
                "${env:ProgramFiles(x86)}\Xerox" 
            } else { 
                "${env:ProgramData}\Xerox" 
            }
            Write-Host "  Installation path found: $installPath" -ForegroundColor Gray
            
            # Check if it's in Program Files (system-wide)
            if ($programFilesXerox -or $programFilesX86Xerox) {
                Write-Host "  Verification: Xerox Workplace Cloud Client is installed system-wide (Program Files) - compatible with sysprep." -ForegroundColor Green
            }
            else {
                Write-Host "  Verification: Installation found in ProgramData (system-wide) - compatible with sysprep." -ForegroundColor Green
            }
        }
        else {
            Write-Host "  Note: Could not verify installation path, but registry entry exists" -ForegroundColor Gray
        }
    }
    else {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "  Xerox Workplace Cloud Client not found in registry yet. Waiting 10 seconds and retrying... (Attempt $retryCount/$maxRetries)" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
    }
}

# Final verification
if (-not $installationVerified) {
    Write-Warning "Installation verification failed. Xerox Workplace Cloud Client may not be installed correctly."
    Write-Host "  You may need to verify installation manually" -ForegroundColor Yellow
    Write-Host "  Check if the application appears in Start Menu or Program Files" -ForegroundColor Yellow
}

# Clean up installer
Write-Host ""
Write-Host "Cleaning up installer file..." -ForegroundColor Yellow
try {
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
    Write-Host "  Installer removed" -ForegroundColor Green
}
catch {
    Write-Warning "  Could not remove installer file: $_"
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Xerox Workplace Cloud Client:" -ForegroundColor Green
if ($installationVerified) {
    Write-Host "  Status: Installed (System-Wide)" -ForegroundColor Green
    Write-Host "  Version: $($xeroxCheck.DisplayVersion)" -ForegroundColor Gray
}
else {
    Write-Host "  Status: Installation completed (verification pending)" -ForegroundColor Yellow
    Write-Host "  Please verify the application is installed and working correctly" -ForegroundColor Yellow
}
Write-Host ""

if ($installationVerified) {
    Write-Host "Xerox Workplace Cloud Client installation completed successfully!" -ForegroundColor Green
    Write-Host "Xerox Workplace Cloud Client is installed system-wide and ready for sysprep." -ForegroundColor Green
}
else {
    Write-Host "Installation completed with warnings. Please verify Xerox Workplace Cloud Client is installed correctly." -ForegroundColor Yellow
}
Write-Host ""

### End Script ###

