#description: Installs Google Chrome for all users using winget (system-level installation)
#tags: Nerdio, Apps install

<#
Notes:
This script uses Windows Package Manager (winget) to install Google Chrome as a system-level installation for all users.
This ensures Chrome is available to all users and is compatible with sysprep for AVD image templates.

Key features:
- Uses winget (built into Windows 11) for reliable installation
- Installs Chrome to Program Files (system-wide, not per-user)
- Makes Chrome available to all users
- Is compatible with sysprep and image capture
- No manual downloads required - winget handles everything
- Automatically gets the latest stable version
#>

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# Check if winget is available
Write-Host "Checking for Windows Package Manager (winget)..."
try {
    $wingetVersion = winget --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "winget not found"
    }
    Write-Host "winget is available: $wingetVersion"
}
catch {
    Write-Error "winget is not available. This script requires Windows Package Manager (winget)."
    Write-Error ""
    Write-Error "To install winget, you can:"
    Write-Error "1. Run the install-winget.ps1 script first (recommended):"
    Write-Error "   https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-winget.ps1"
    Write-Error ""
    Write-Error "2. Or manually install App Installer from the Microsoft Store:"
    Write-Error "   https://www.microsoft.com/store/productId/9NBLGGH4NNS1"
    Write-Error ""
    Write-Error "Note: Add install-winget.ps1 as a script BEFORE this script in your Custom Image Template."
    exit 1
}

# Check if Chrome is already installed (system-level)
Write-Host "Checking if Google Chrome is already installed..."
$ChromeInstalled = Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"

if ($ChromeInstalled) {
    Write-Host "Google Chrome is already installed. Checking version..."
    $ExistingVersion = (Get-Item "C:\Program Files\Google\Chrome\Application\chrome.exe").VersionInfo.FileVersion
    Write-Host "Existing Chrome version: $ExistingVersion"
    
    # Uninstall existing Chrome using winget to ensure clean installation
    Write-Host "Uninstalling existing version to ensure clean installation..."
    try {
        winget uninstall --id Google.Chrome --scope machine --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        
        # Wait for uninstall to complete
        $maxWait = 30
        $waitCount = 0
        while ($waitCount -lt $maxWait -and (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe")) {
            Start-Sleep -Seconds 2
            $waitCount += 2
        }
        Write-Host "Uninstall completed."
    }
    catch {
        Write-Warning "Failed to uninstall existing Chrome via winget: $_"
        Write-Warning "Attempting to continue with installation..."
    }
}

# Install Chrome using winget with machine-wide scope
Write-Host "Installing Google Chrome for all users (system-level) using winget..."
Write-Host "This may take a few minutes as winget downloads and installs Chrome..."

try {
    # Use winget to install Chrome with machine-wide scope
    # --scope machine ensures installation for all users (system-wide)
    # --silent performs silent installation
    # --accept-package-agreements and --accept-source-agreements auto-accept licenses
    $wingetOutput = winget install --id Google.Chrome --scope machine --silent --accept-package-agreements --accept-source-agreements 2>&1
    
    # Check exit code
    if ($LASTEXITCODE -eq 0) {
        Write-Host "winget installation command completed successfully."
    }
    else {
        # Check if Chrome was already installed (exit code 0x8A150011 or similar)
        $outputString = $wingetOutput -join "`n"
        if ($outputString -match "already installed" -or $outputString -match "0x8A150011") {
            Write-Host "Chrome is already installed (detected by winget)."
        }
        else {
            Write-Error "winget installation failed with exit code: $LASTEXITCODE"
            Write-Error "Output: $outputString"
            exit 1
        }
    }
}
catch {
    Write-Error "Failed to install Chrome using winget: $_"
    exit 1
}

# Wait for installation to complete and verify
Write-Host "Verifying installation..."
Start-Sleep -Seconds 5

# Retry verification if needed
$maxRetries = 6
$retryCount = 0
$installationVerified = $false

while ($retryCount -lt $maxRetries -and -not $installationVerified) {
    if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
        $ChromeVersion = (Get-Item "C:\Program Files\Google\Chrome\Application\chrome.exe").VersionInfo.FileVersion
        Write-Host "Google Chrome version $ChromeVersion installed successfully for all users."
        $installationVerified = $true
    }
    else {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "Chrome executable not found yet. Waiting 10 seconds and retrying... (Attempt $retryCount/$maxRetries)"
            Start-Sleep -Seconds 10
        }
    }
}

# Final verification
if (-not $installationVerified) {
    Write-Error "Chrome installation verification failed. Chrome executable not found at expected location."
    Write-Error "Expected path: C:\Program Files\Google\Chrome\Application\chrome.exe"
    exit 1
}

# Verify installation is system-wide (not per-user)
$programFilesChrome = Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"
$localAppDataChrome = Test-Path "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"

if ($programFilesChrome) {
    Write-Host "Verification: Chrome is installed system-wide (Program Files) - compatible with sysprep."
}
elseif ($localAppDataChrome) {
    Write-Warning "Warning: Chrome appears to be installed per-user (LocalAppData) instead of system-wide."
    Write-Warning "This may cause issues with sysprep. Installation may need to be reviewed."
}

Write-Host "Google Chrome installation completed successfully using winget."
Write-Host "Chrome is installed system-wide and ready for sysprep."

### End Script ###

