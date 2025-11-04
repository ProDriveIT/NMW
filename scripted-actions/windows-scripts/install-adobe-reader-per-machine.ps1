#description: Downloads and installs Adobe Acrobat Reader DC for all users (system-level installation)
#tags: Nerdio, Apps install

<#
Notes:
This script downloads and installs Adobe Acrobat Reader DC as a system-level installation for all users.
This ensures Reader is available to all users and is compatible with sysprep for AVD image templates.

The installation uses system-wide flags which:
- Installs Reader to Program Files (not per-user)
- Makes Reader available to all users
- Is compatible with sysprep and image capture
- Prevents per-user Reader installations

This script is designed for clean image builds in Custom Image Templates.
#>

# Configure error handling
$ErrorActionPreference = 'Stop'

# Detect system architecture
$Is64Bit = [Environment]::Is64BitOperatingSystem

# Define installer URLs based on architecture
if ($Is64Bit) {
    $ReaderInstallerUrl = "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2100720091/AcroRdrDCx642100720091_MUI.exe"
    $ReaderInstallerFilename = "AcroRdrDCx64_MUI.exe"
    Write-Host "Detected 64-bit system. Will install Adobe Reader DC x64."
} else {
    $ReaderInstallerUrl = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/1500720033/AcroRdrDC1500720033_MUI.exe"
    $ReaderInstallerFilename = "AcroRdrDC_MUI.exe"
    Write-Host "Detected 32-bit system. Will install Adobe Reader DC x86."
}

# Define the path where the installer will be downloaded
$DownloadPath = "C:\Temp\$ReaderInstallerFilename"

# Create the directory if it doesn't exist
if (!(Test-Path -Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
}

# Check if Adobe Reader is already installed (system-level)
$ReaderInstalled = $false
if ($Is64Bit) {
    $ReaderInstalled = (Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe") -or (Test-Path "C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe")
} else {
    $ReaderInstalled = (Test-Path "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe")
}

if ($ReaderInstalled) {
    Write-Host "Adobe Reader is already installed. Uninstalling existing version..."
    # Try to uninstall using Adobe's uninstaller
    $UninstallPaths = @(
        "C:\Program Files\Adobe\Acrobat DC\Acrobat\SetupFiles\{AC76BA86-7AD7-*}\setup.exe",
        "C:\Program Files\Adobe\Acrobat Reader DC\SetupFiles\{AC76BA86-7AD7-*}\setup.exe",
        "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\SetupFiles\{AC76BA86-7AD7-*}\setup.exe"
    )
    
    $uninstalled = $false
    foreach ($pathPattern in $UninstallPaths) {
        $uninstaller = Get-ChildItem -Path (Split-Path $pathPattern -Parent) -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($uninstaller) {
            Write-Host "Found uninstaller at: $($uninstaller.FullName)"
            Start-Process -FilePath $uninstaller.FullName -ArgumentList "/sAll", "/rs", "/runwg", "/rps" -Wait -NoNewWindow
            Start-Sleep -Seconds 10
            $uninstalled = $true
            break
        }
    }
    
    if (-not $uninstalled) {
        Write-Warning "Could not find Adobe uninstaller. Installation may proceed but may encounter conflicts."
    }
}

# Download the Adobe Reader installer
Write-Host "Downloading Adobe Acrobat Reader DC installer..."
try {
    # Enable TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    Invoke-WebRequest -Uri $ReaderInstallerUrl -OutFile $DownloadPath -UseBasicParsing
    Write-Host "Download completed successfully."
    
    # Verify file was downloaded
    if (!(Test-Path $DownloadPath)) {
        Write-Error "Downloaded file not found at: $DownloadPath"
        exit 1
    }
    
    # Verify file size (should be substantial)
    $fileInfo = Get-Item $DownloadPath
    if ($fileInfo.Length -lt 1000000) {  # Less than 1MB is suspicious
        Write-Error "Downloaded file appears to be too small. Download may have failed."
        exit 1
    }
    
    Write-Host "Downloaded file size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"
}
catch {
    Write-Error "Failed to download Adobe Reader installer: $_"
    exit 1
}

# Verify digital signature (optional but recommended)
Write-Host "Verifying digital signature..."
try {
    $signature = Get-AuthenticodeSignature -FilePath $DownloadPath
    if ($signature.Status -eq 'Valid') {
        Write-Host "Digital signature verified successfully."
    } else {
        Write-Warning "Digital signature status: $($signature.Status). Proceeding with caution..."
    }
}
catch {
    Write-Warning "Could not verify digital signature: $_. Proceeding with installation..."
}

# Install Adobe Reader with system-wide flags
# /sAll - Silent install for all users (system-wide installation)
# /rs - Suppress reboot
# /re - Suppress restart prompt
# When run as admin, these flags ensure system-wide installation to Program Files
Write-Host "Installing Adobe Acrobat Reader DC for all users (system-level)..."
$process = Start-Process -FilePath $DownloadPath -ArgumentList "/sAll", "/rs", "/re" -Wait -PassThru -NoNewWindow

# Wait a moment for installation to complete
Start-Sleep -Seconds 5

# Verify installation
Write-Host "Verifying installation..."
$installationSuccess = $false

if ($Is64Bit) {
    $readerPaths = @(
        "C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
        "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
    )
} else {
    $readerPaths = @(
        "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    )
}

foreach ($readerPath in $readerPaths) {
    if (Test-Path $readerPath) {
        $readerVersion = (Get-Item $readerPath).VersionInfo.FileVersion
        Write-Host "Adobe Acrobat Reader DC version $readerVersion installed successfully at: $readerPath"
        $installationSuccess = $true
        break
    }
}

if (-not $installationSuccess) {
    # Check exit code
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        Write-Error "Adobe Reader installation failed with exit code: $($process.ExitCode)"
        Write-Error "Exit code 3010 indicates a successful installation requiring reboot (which is normal for image builds)"
        exit 1
    }
    
    # Wait longer and retry verification
    Write-Warning "Installation reported success but executable not found. Waiting and retrying..."
    Start-Sleep -Seconds 15
    
    foreach ($readerPath in $readerPaths) {
        if (Test-Path $readerPath) {
            $readerVersion = (Get-Item $readerPath).VersionInfo.FileVersion
            Write-Host "Adobe Acrobat Reader DC version $readerVersion installed successfully at: $readerPath"
            $installationSuccess = $true
            break
        }
    }
    
    if (-not $installationSuccess) {
        Write-Error "Adobe Reader installation verification failed. Executable not found in expected locations."
        exit 1
    }
}

# Clean up installer
if (Test-Path $DownloadPath) {
    Remove-Item -Path $DownloadPath -Force
    Write-Host "Installer file cleaned up."
}

Write-Host "Adobe Acrobat Reader DC installation completed successfully for all users."

# Exit with success code
exit 0

