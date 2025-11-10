#description: Downloads and installs Sage 50 Accounts v28 from Azure Blob Storage
#tags: Nerdio, Sage, Installation

<#
.SYNOPSIS
    Downloads and installs Sage 50 Accounts v28 from Azure Blob Storage.

.DESCRIPTION
    This script downloads the Sage 50 Accounts v28 installer from Azure Blob Storage
    and installs it silently. Configuration of data service connection must be done
    separately after installation.

.PARAMETER InstallerFileName
    Name of the installer file in the blob container (optional - script will auto-detect if not provided)

.EXAMPLE
    .\install-sage50-accounts.ps1
    
.EXAMPLE
    .\install-sage50-accounts.ps1 -InstallerFileName "Sage50Accounts_v28.msi"
    
.NOTES
    Requires:
    - Administrator privileges
    - Internet connection to download installer
    
    Note: Data service configuration must be done separately after installation.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallerFileName = ""
)

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Install Sage 50 Accounts v28" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Azure Blob Storage configuration
$StorageAccountName = "stavdcitscripts6009"
$ContainerName = "sage-50-accounts"
$SasToken = "sp=r&st=2025-11-10T13:04:47Z&se=2027-11-10T21:19:47Z&spr=https&sv=2024-11-04&sr=c&sig=PNQExrskkzzcRFf1yO3Zt6ypZr%2BWiYXOKzarDUTZ5nQ%3D"
$ContainerUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Storage Account: $StorageAccountName" -ForegroundColor Gray
Write-Host "  Container: $ContainerName" -ForegroundColor Gray
Write-Host ""

# Check if Sage 50 is already installed
Write-Host "Checking for existing Sage 50 installation..." -ForegroundColor Cyan
$sageInstalled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -like "*Sage 50*" -or $_.DisplayName -like "*Sage Accounts*" }

if ($sageInstalled) {
    Write-Host "  Sage 50 appears to be already installed: $($sageInstalled.DisplayName)" -ForegroundColor Yellow
    Write-Host "  Version: $($sageInstalled.DisplayVersion)" -ForegroundColor Gray
    Write-Host ""
    $continue = Read-Host "Continue with installation anyway? (Y/N)"
    if ($continue -ne 'Y' -and $continue -ne 'y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
}
Write-Host ""

# Set installer filename (hardcoded for CIT)
if ([string]::IsNullOrWhiteSpace($InstallerFileName)) {
    $InstallerFileName = "Sage50Accounts_v28.1.exe"
    Write-Host "Using installer: $InstallerFileName" -ForegroundColor Green
}
else {
    Write-Host "Using specified installer: $InstallerFileName" -ForegroundColor Green
}

Write-Host ""

# Download installer
$tempPath = "C:\Temp"
if (-not (Test-Path $tempPath)) {
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
}

$installerPath = Join-Path $tempPath $InstallerFileName
$downloadUrl = "${ContainerUrl}/${InstallerFileName}?${SasToken}"

Write-Host "Downloading installer..." -ForegroundColor Yellow
Write-Host "  Source: $ContainerUrl/$InstallerFileName" -ForegroundColor Gray
Write-Host "  Destination: $installerPath" -ForegroundColor Gray
Write-Host ""

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
    $fileSize = (Get-Item $installerPath).Length / 1MB
    Write-Host "  Download completed: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download installer: $_"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Verify the installer filename is correct: $InstallerFileName" -ForegroundColor Gray
    Write-Host "  - Check SAS token is valid and not expired" -ForegroundColor Gray
    Write-Host "  - Verify network connectivity" -ForegroundColor Gray
    exit 1
}

# Install Sage 50
Write-Host ""
Write-Host "Installing Sage 50 Accounts v28..." -ForegroundColor Cyan
Write-Host "  This may take several minutes..." -ForegroundColor Gray
Write-Host ""

$extension = [System.IO.Path]::GetExtension($InstallerFileName).ToLower()
$installSuccess = $false

try {
    if ($extension -eq '.msi') {
        # MSI installation
        Write-Host "Running MSI installer..." -ForegroundColor Yellow
        $installArgs = @(
            "/i",
            "`"$installerPath`"",
            "/quiet",
            "/norestart",
            "/l*v",
            "$tempPath\Sage50Install.log"
        )
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            $installSuccess = $true
            Write-Host "  Installation completed successfully (Exit code: $($process.ExitCode))" -ForegroundColor Green
        }
        else {
            Write-Warning "  Installation completed with exit code: $($process.ExitCode)"
            Write-Host "  Check log file: $tempPath\Sage50Install.log" -ForegroundColor Yellow
        }
    }
    elseif ($extension -eq '.exe') {
        # EXE installation - try common silent switches
        Write-Host "Running EXE installer..." -ForegroundColor Yellow
        $installArgs = @("/S", "/quiet", "/norestart")
        
        $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            $installSuccess = $true
            Write-Host "  Installation completed successfully (Exit code: $($process.ExitCode))" -ForegroundColor Green
        }
        else {
            Write-Warning "  Installation completed with exit code: $($process.ExitCode)"
            Write-Host "  Note: Sage 50 may require different silent install parameters" -ForegroundColor Yellow
            Write-Host "  You may need to customize the install arguments" -ForegroundColor Yellow
        }
    }
    else {
        Write-Error "Unsupported installer format: $extension"
        exit 1
    }
}
catch {
    Write-Error "Failed to install Sage 50: $_"
    if (Test-Path "$tempPath\Sage50Install.log") {
        Write-Host "  Check log file: $tempPath\Sage50Install.log" -ForegroundColor Yellow
    }
    exit 1
}

if (-not $installSuccess) {
    Write-Warning "Installation may have failed. Please verify Sage 50 is installed correctly."
    Write-Host "  Check log file: $tempPath\Sage50Install.log" -ForegroundColor Yellow
}


# Clean up installer
Write-Host "Cleaning up installer file..." -ForegroundColor Yellow
try {
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
    Write-Host "  Installer removed" -ForegroundColor Green
}
catch {
    Write-Warning "  Could not remove installer file: $_"
}

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

$sageCheck = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -like "*Sage 50*" -or $_.DisplayName -like "*Sage Accounts*" }

if ($sageCheck) {
    Write-Host "  Sage 50 installed: $($sageCheck.DisplayName)" -ForegroundColor Green
    Write-Host "  Version: $($sageCheck.DisplayVersion)" -ForegroundColor Gray
}
else {
    Write-Warning "  Could not verify installation in registry"
    Write-Host "  Please verify Sage 50 is installed and working correctly" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sage 50 Accounts v28:" -ForegroundColor Green
if ($sageCheck) {
    Write-Host "  Status: Installed" -ForegroundColor Green
    Write-Host "  Version: $($sageCheck.DisplayVersion)" -ForegroundColor Gray
}
else {
    Write-Host "  Status: Installation completed (verification pending)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Verify Sage 50 launches correctly" -ForegroundColor Gray
Write-Host "  2. Configure data service connection in Sage 50 (to be done separately)" -ForegroundColor Gray
Write-Host ""

if ($installSuccess) {
    Write-Host "Installation completed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Installation completed with warnings. Please verify." -ForegroundColor Yellow
}
Write-Host ""

