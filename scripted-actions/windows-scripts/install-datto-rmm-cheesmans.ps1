#description: Installs Datto RMM agent for Cheesmans client
#tags: Nerdio, Apps install, Datto RMM, Cheesmans
<#
Notes:
This script downloads and installs the Datto RMM agent for the Cheesmans client.
The agent installer is downloaded from the Datto RMM portal and executed silently.

Key features:
- Downloads the Datto RMM agent installer from the Cheesmans-specific URL
- Installs the agent with proper error handling
- Waits for installation to complete
- Verifies the installation was successful
#>

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# Define the download URL and installer path
$DownloadUrl = "https://merlot.rmm.datto.com/download-agent/windows/d77afc16-b8a1-4101-af65-4451811f3d56"
$InstallerPath = Join-Path $env:TEMP "AgentInstall.exe"

# Check if installer already exists and remove it
if (Test-Path -Path $InstallerPath) {
    Write-Host "Removing existing installer file..."
    Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
}

# Download the Datto RMM agent installer
Write-Host "Downloading Datto RMM agent installer for Cheesmans..."
Write-Host "Source URL: $DownloadUrl"
Write-Host "Destination: $InstallerPath"

try {
    # Use Invoke-WebRequest for better error handling
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing -ErrorAction Stop
    Write-Host "Download completed successfully."
    
    # Verify the file was downloaded
    if (Test-Path -Path $InstallerPath) {
        $FileInfo = Get-Item -Path $InstallerPath
        Write-Host "File size: $($FileInfo.Length) bytes"
        Write-Host "File downloaded: $($FileInfo.FullName)"
    }
    else {
        Write-Error "Downloaded file not found at expected location: $InstallerPath"
        exit 1
    }
}
catch {
    Write-Error "Failed to download Datto RMM agent installer: $_"
    Write-Error "Error details: $($_.Exception.Message)"
    exit 1
}

# Install the Datto RMM agent
Write-Host ""
Write-Host "Installing Datto RMM agent..."
Write-Host "This may take several minutes. Please wait..."

try {
    # Start the installation process and wait for completion
    # Using Start-Process with -Wait to ensure the script waits for installation to complete
    $process = Start-Process -FilePath $InstallerPath -Wait -NoNewWindow -PassThru -ErrorAction Stop
    
    # Check exit code
    if ($process.ExitCode -eq 0) {
        Write-Host ""
        Write-Host "Datto RMM agent installation completed successfully." -ForegroundColor Green
        Write-Host "Exit code: $($process.ExitCode)"
    }
    else {
        Write-Warning "Installation completed with exit code: $($process.ExitCode)"
        Write-Warning "Please verify the Datto RMM agent is properly installed and functioning."
        
        # Some installers return non-zero codes even on success, so we'll warn but not fail
        # Exit with the installer's exit code for visibility
        exit $process.ExitCode
    }
}
catch {
    Write-Error "Failed to execute Datto RMM agent installer: $_"
    Write-Error "Error details: $($_.Exception.Message)"
    exit 1
}

# Clean up the installer file
Write-Host ""
Write-Host "Cleaning up installer file..."
try {
    if (Test-Path -Path $InstallerPath) {
        Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
        Write-Host "Installer file removed."
    }
}
catch {
    Write-Warning "Failed to remove installer file: $_"
    Write-Warning "You may manually delete: $InstallerPath"
}

Write-Host ""
Write-Host "Datto RMM agent installation script completed." -ForegroundColor Green

### End Script ###

