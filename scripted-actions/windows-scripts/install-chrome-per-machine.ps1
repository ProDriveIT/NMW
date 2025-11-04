#description: Downloads and installs Google Chrome for all users (system-level installation)
#tags: Nerdio, Apps install

<#
Notes:
This script downloads and installs Google Chrome as a system-level installation for all users.
This ensures Chrome is available to all users and is compatible with sysprep for AVD image templates.

The installation automatically installs system-wide when run with administrative privileges:
- Installs Chrome to Program Files (not per-user)
- Makes Chrome available to all users
- Is compatible with sysprep and image capture
- Prevents per-user Chrome installations
#>

# Define the URL for Chrome standalone installer (64-bit)
$ChromeInstallerUrl = "https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe"

# Define the path where the Chrome installer will be downloaded
$DownloadPath = "C:\Temp\ChromeStandaloneSetup64.exe"

# Create the directory if it doesn't exist
if (!(Test-Path -Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
}

# Check if Chrome is already installed (system-level)
$ChromeInstalled = Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"

if ($ChromeInstalled) {
    Write-Host "Google Chrome is already installed. Uninstalling existing version..."
    # Uninstall existing Chrome using its uninstaller
    $ChromeVersionPath = Get-ChildItem "C:\Program Files\Google\Chrome\Application" -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($ChromeVersionPath) {
        $UninstallerPath = Join-Path $ChromeVersionPath.FullName "Installer\setup.exe"
        if (Test-Path $UninstallerPath) {
            Start-Process -FilePath $UninstallerPath -ArgumentList "--uninstall", "--force-uninstall", "--system-level" -Wait -NoNewWindow
            Start-Sleep -Seconds 5
        }
    }
}

# Download the Chrome installer
Write-Host "Downloading Google Chrome installer..."
try {
    Invoke-WebRequest -Uri $ChromeInstallerUrl -OutFile $DownloadPath -UseBasicParsing
    Write-Host "Download completed successfully."
}
catch {
    Write-Error "Failed to download Chrome installer: $_"
    exit 1
}

# Install Chrome (automatically installs system-wide when run as admin)
# When run with administrative privileges, Chrome installer automatically detects elevated context
# and installs to Program Files for all users (system-level installation)
Write-Host "Installing Google Chrome for all users (system-level)..."
# Chrome installer is a self-extracting executable - when executed as admin, it automatically installs system-wide
$process = Start-Process -FilePath $DownloadPath -Wait -PassThru -NoNewWindow

# Wait a moment for installation to complete
Start-Sleep -Seconds 3

# Verify installation
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $ChromeVersion = (Get-Item "C:\Program Files\Google\Chrome\Application\chrome.exe").VersionInfo.FileVersion
    Write-Host "Google Chrome version $ChromeVersion installed successfully for all users."
}
elseif ($process.ExitCode -eq 0) {
    Write-Warning "Installation reported success but Chrome executable not found. Waiting and retrying..."
    Start-Sleep -Seconds 10
    if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
        $ChromeVersion = (Get-Item "C:\Program Files\Google\Chrome\Application\chrome.exe").VersionInfo.FileVersion
        Write-Host "Google Chrome version $ChromeVersion installed successfully for all users."
    }
    else {
        Write-Error "Chrome installation verification failed. Chrome executable not found."
        exit 1
    }
}
else {
    Write-Error "Chrome installation failed with exit code: $($process.ExitCode)"
    exit 1
}

# Clean up installer
if (Test-Path $DownloadPath) {
    Remove-Item -Path $DownloadPath -Force
    Write-Host "Installer file cleaned up."
}

### End Script ###

