#description: Downloads and installs Onvio Link for all users from Azure Blob Storage (system-level installation)
#tags: Nerdio, Onvio Link, Installation

<#
.SYNOPSIS
    Downloads and installs Onvio Link MSI from Azure Blob Storage for all users.

.DESCRIPTION
    This script downloads the Onvio Link installer from Azure Blob Storage and installs it
    silently for all users (system-wide). This ensures Onvio Link is available to all users
    and is compatible with sysprep for AVD image templates.

    Key features:
    - Downloads from Azure Blob Storage using SAS token
    - Installs system-wide (ALLUSERS=1) for all users
    - Silent installation with /qn (no UI, suppresses certificate prompts)
    - Compatible with sysprep and image capture
    - Verifies installation after completion

.EXAMPLE
    .\install-onvio-link-per-machine.ps1
    
.NOTES
    Requires:
    - Administrator privileges
    - Internet connection to download installer
    
    The installer is downloaded from Azure Blob Storage and installed using msiexec.
    /qn switch ensures completely silent installation (no UI, suppresses certificate prompts).
    ALLUSERS=1 property ensures system-wide installation compatible with sysprep.
    REBOOT=ReallySuppress prevents automatic reboot.
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
Write-Host "Install Onvio Link (System-Wide)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Azure Blob Storage URL with SAS token
$BlobUrl = "https://stavdcitscripts1354.blob.core.windows.net/onvio-link/onvio_link_installer.en_gb.msi?sp=r&st=2025-11-11T16:36:25Z&se=2027-11-12T00:51:25Z&spr=https&sv=2024-11-04&sr=b&sig=2nOoJ8X9bX98pDwG1s4rOulhfYA4QlnQkNVlV03EKP4%3D"
$InstallerFileName = "onvio_link_installer.en_gb.msi"

# Check if Onvio Link is already installed
Write-Host "Checking for existing Onvio Link installation..." -ForegroundColor Cyan
$onvioInstalled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -like "*Onvio*Link*" -or $_.DisplayName -like "*Onvio Link*" }

if ($onvioInstalled) {
    Write-Host "  Onvio Link appears to be already installed: $($onvioInstalled.DisplayName)" -ForegroundColor Yellow
    Write-Host "  Version: $($onvioInstalled.DisplayVersion)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Uninstalling existing version to ensure clean installation..." -ForegroundColor Yellow
    
    try {
        $uninstallString = $onvioInstalled.UninstallString
        if ($uninstallString -match 'msiexec') {
            # Extract product code from uninstall string or use GUID
            $productCode = $onvioInstalled.PSChildName
            $uninstallArgs = @(
                "/x",
                "`"$productCode`"",
                "/qn",
                "/norestart",
                "REBOOT=ReallySuppress"
            )
            $uninstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $uninstallArgs -Wait -NoNewWindow -PassThru
            Start-Sleep -Seconds 5
            Write-Host "  Uninstall completed." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "  Failed to uninstall existing Onvio Link: $_"
        Write-Warning "  Attempting to continue with installation..."
    }
    Write-Host ""
}

# Ensure log directory exists
$logDir = "C:\ProgramData\Logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Download installer
$tempPath = "C:\Temp"
if (-not (Test-Path $tempPath)) {
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
}

$installerPath = Join-Path $tempPath $InstallerFileName
$logPath = Join-Path $logDir "OnvioLink_Install.log"

Write-Host "Downloading Onvio Link installer..." -ForegroundColor Yellow
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

# Install Onvio Link
Write-Host ""
Write-Host "Installing Onvio Link for all users (system-wide)..." -ForegroundColor Cyan
Write-Host "  This may take a few minutes..." -ForegroundColor Gray
Write-Host "  Using /qn for completely silent installation (suppresses certificate prompts)..." -ForegroundColor Gray
Write-Host ""

try {
    # MSI installation with /qn for completely silent installation
    # /qn = completely silent, no UI (suppresses certificate/driver installation prompts)
    # /l*v = verbose logging
    # ALLUSERS=1 = install for all users (system-wide, compatible with sysprep)
    # REBOOT=ReallySuppress = prevent automatic reboot
    $installArgs = @(
        "/i",
        "`"$installerPath`"",
        "/qn",
        "/norestart",
        "/l*v",
        "`"$logPath`"",
        "REBOOT=ReallySuppress",
        "ALLUSERS=1"
    )
    
    Write-Host "Running MSI installer with silent mode (/qn)..." -ForegroundColor Yellow
    Write-Host "  This will suppress all UI prompts including certificate installation dialogs" -ForegroundColor Gray
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Write-Host "  Installation completed successfully (Exit code: $($process.ExitCode))" -ForegroundColor Green
        if ($process.ExitCode -eq 3010) {
            Write-Host "  Note: Exit code 3010 indicates a reboot is required (suppressed by REBOOT=ReallySuppress)" -ForegroundColor Gray
        }
    }
    else {
        Write-Warning "  Installation completed with exit code: $($process.ExitCode)"
        Write-Host "  Check log file: $logPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Common exit codes:" -ForegroundColor Yellow
        Write-Host "  0 = Success" -ForegroundColor Gray
        Write-Host "  3010 = Success (reboot required)" -ForegroundColor Gray
        Write-Host "  Other codes may indicate an error - check the log file" -ForegroundColor Gray
    }
}
catch {
    Write-Error "Failed to install Onvio Link: $_"
    if (Test-Path $logPath) {
        Write-Host "  Check log file: $logPath" -ForegroundColor Yellow
    }
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
    $onvioCheck = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -like "*Onvio*Link*" -or $_.DisplayName -like "*Onvio Link*" }
    
    if ($onvioCheck) {
        $installationVerified = $true
        Write-Host "  Onvio Link installed: $($onvioCheck.DisplayName)" -ForegroundColor Green
        Write-Host "  Version: $($onvioCheck.DisplayVersion)" -ForegroundColor Gray
        
        # Verify it's installed system-wide (check Program Files)
        $programFilesOnvio = Test-Path "${env:ProgramFiles}\Onvio"
        $programFilesX86Onvio = Test-Path "${env:ProgramFiles(x86)}\Onvio"
        $programDataOnvio = Test-Path "${env:ProgramData}\Onvio"
        
        if ($programFilesOnvio -or $programFilesX86Onvio -or $programDataOnvio) {
            $installPath = if ($programFilesOnvio) { 
                "${env:ProgramFiles}\Onvio" 
            } elseif ($programFilesX86Onvio) { 
                "${env:ProgramFiles(x86)}\Onvio" 
            } else { 
                "${env:ProgramData}\Onvio" 
            }
            Write-Host "  Installation path found: $installPath" -ForegroundColor Gray
            
            # Check if it's in Program Files (system-wide)
            if ($programFilesOnvio -or $programFilesX86Onvio) {
                Write-Host "  Verification: Onvio Link is installed system-wide (Program Files) - compatible with sysprep." -ForegroundColor Green
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
            Write-Host "  Onvio Link not found in registry yet. Waiting 10 seconds and retrying... (Attempt $retryCount/$maxRetries)" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
    }
}

# Final verification
if (-not $installationVerified) {
    Write-Warning "Installation verification failed. Onvio Link may not be installed correctly."
    Write-Host "  Check log file: $logPath" -ForegroundColor Yellow
    Write-Host "  You may need to verify installation manually" -ForegroundColor Yellow
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
Write-Host "Onvio Link:" -ForegroundColor Green
if ($installationVerified) {
    Write-Host "  Status: Installed (System-Wide)" -ForegroundColor Green
    Write-Host "  Version: $($onvioCheck.DisplayVersion)" -ForegroundColor Gray
    Write-Host "  Log file: $logPath" -ForegroundColor Gray
}
else {
    Write-Host "  Status: Installation completed (verification pending)" -ForegroundColor Yellow
    Write-Host "  Log file: $logPath" -ForegroundColor Gray
}
Write-Host ""

if ($installationVerified) {
    Write-Host "Onvio Link installation completed successfully!" -ForegroundColor Green
    Write-Host "Onvio Link is installed system-wide and ready for sysprep." -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Certificate installation prompts were suppressed using /qn switch." -ForegroundColor Gray
    Write-Host "      The Thomson Reuters Printers driver certificate should be installed automatically." -ForegroundColor Gray
}
else {
    Write-Host "Installation completed with warnings. Please verify Onvio Link is installed correctly." -ForegroundColor Yellow
}
Write-Host ""

### End Script ###

