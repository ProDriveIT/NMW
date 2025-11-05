#description: Installs Windows Package Manager (winget) if not already available
#tags: Nerdio, Prerequisites, winget

<#
Notes:
This script ensures Windows Package Manager (winget) is installed and available.
Winget is built into Windows 11 and Windows 10 1809+, but may require the App Installer
to be installed or updated from the Microsoft Store.

This script:
- Checks if winget is already available
- If not, installs it via Microsoft Store or direct download
- Verifies installation before proceeding
- Is sysprep-compatible (no per-user data)
#>

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# Function to check if winget is available
function Test-WingetAvailable {
    try {
        $null = winget --version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Function to find winget executable location
function Find-WingetPath {
    # Common locations where winget might be installed
    $wingetPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\AppInstallerCLI.exe"
    )
    
    foreach ($path in $wingetPaths) {
        # Handle wildcards
        $resolvedPaths = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($resolvedPath in $resolvedPaths) {
            if (Test-Path $resolvedPath.FullName) {
                return $resolvedPath.FullName
            }
        }
    }
    
    # Also check App Installer package location
    $appInstaller = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue
    if ($appInstaller) {
        $installLocation = $appInstaller.InstallLocation
        $wingetPath = Join-Path $installLocation "winget.exe"
        if (Test-Path $wingetPath) {
            return $wingetPath
        }
    }
    
    return $null
}

# Check if winget is already available in PATH
Write-Host "Checking if Windows Package Manager (winget) is available..."
if (Test-WingetAvailable) {
    $wingetVersion = winget --version
    Write-Host "winget is already installed and available. Version: $wingetVersion"
    Write-Host "No installation needed."
    exit 0
}

# winget not in PATH - try to find it and add to PATH
Write-Host "winget not found in PATH. Searching for winget installation..."
$wingetPath = Find-WingetPath

if ($wingetPath) {
    Write-Host "Found winget at: $wingetPath"
    Write-Host "Adding to PATH for current session..."
    
    # Add to PATH for current session
    $wingetDir = Split-Path -Parent $wingetPath
    $env:Path = "$wingetDir;$env:Path"
    
    # Verify it works now
    if (Test-WingetAvailable) {
        $wingetVersion = winget --version
        Write-Host "winget is now available. Version: $wingetVersion"
        Write-Host "Note: PATH change is only for this session. For permanent fix, ensure winget is in system PATH."
        exit 0
    }
    else {
        Write-Warning "Found winget but it's not working. Attempting to use direct path..."
        # Try using full path
        try {
            $version = & $wingetPath --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "winget is available via direct path. Version: $version"
                Write-Host "For this session, using: $wingetPath"
                # Create an alias or function for winget
                Set-Alias -Name winget -Value $wingetPath -Scope Global -ErrorAction SilentlyContinue
                exit 0
            }
        }
        catch {
            Write-Warning "Direct path execution also failed: $_"
        }
    }
}

Write-Host "winget is not available and could not be located. Attempting installation..."

# Method 1: Try to install via Microsoft Store (App Installer)
Write-Host "Attempting to install via Microsoft Store (App Installer)..."

try {
    # Check if Microsoft Store is available
    $storeApp = Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue
    
    if ($storeApp) {
        Write-Host "Microsoft Store is available. Attempting to install App Installer..."
        
        # Try to install App Installer via Microsoft Store
        # Using Start-Process to launch the store app with the App Installer package
        $storeUri = "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" # App Installer Product ID
        Start-Process $storeUri -ErrorAction SilentlyContinue
        
        Write-Host "Launched Microsoft Store to install App Installer."
        Write-Host "Waiting 30 seconds for installation to complete..."
        Start-Sleep -Seconds 30
        
        # Check if winget is now available
        if (Test-WingetAvailable) {
            $wingetVersion = winget --version
            Write-Host "winget installed successfully via Microsoft Store. Version: $wingetVersion"
            exit 0
        }
        else {
            Write-Warning "Microsoft Store installation may still be in progress or failed."
        }
    }
    else {
        Write-Warning "Microsoft Store is not available."
    }
}
catch {
    Write-Warning "Failed to install via Microsoft Store: $_"
}

# Method 2: Download and install App Installer MSIX bundle directly
Write-Host "Attempting direct download and installation of App Installer..."

try {
    # Create temp directory
    $TempPath = "C:\Temp"
    if (!(Test-Path -Path $TempPath)) {
        New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
    }
    
    # Latest App Installer download URL
    # Primary: Microsoft's official short URL
    $AppInstallerUrl = "https://aka.ms/getwinget"
    
    # Alternative: GitHub releases (direct link to latest)
    $AppInstallerUrlAlt = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    
    $AppInstallerPath = Join-Path $TempPath "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    
    Write-Host "Downloading App Installer..."
    
    # Try primary URL first
    $downloadSuccess = $false
    try {
        Write-Host "Attempting download from: $AppInstallerUrl"
        $ProgressPreference = 'SilentlyContinue' # Suppress progress bar
        Invoke-WebRequest -Uri $AppInstallerUrl -OutFile $AppInstallerPath -UseBasicParsing -ErrorAction Stop
        Write-Host "Download completed successfully from primary URL."
        $downloadSuccess = $true
    }
    catch {
        Write-Warning "Failed to download from primary URL: $_"
        Write-Warning "Trying alternative URL..."
        
        # Try alternative URL
        try {
            Write-Host "Attempting download from: $AppInstallerUrlAlt"
            Invoke-WebRequest -Uri $AppInstallerUrlAlt -OutFile $AppInstallerPath -UseBasicParsing -ErrorAction Stop
            Write-Host "Download completed successfully from alternative URL."
            $downloadSuccess = $true
        }
        catch {
            Write-Error "Failed to download App Installer from both URLs: $_"
            Write-Error "You may need to manually install App Installer from the Microsoft Store."
            exit 1
        }
    }
    
    if (-not $downloadSuccess) {
        Write-Error "Download failed. Cannot proceed with installation."
        exit 1
    }
    
    # Verify file was downloaded
    if (!(Test-Path $AppInstallerPath)) {
        Write-Error "Downloaded file not found at: $AppInstallerPath"
        exit 1
    }
    
    Write-Host "Installing App Installer package..."
    
    # Install MSIX bundle using Add-AppxPackage
    # Note: This requires the package to be signed and trusted
    # IMPORTANT: Add-AppxPackage may not work when running as SYSTEM account
    Write-Host "Attempting to install App Installer package..."
    Write-Host "Note: If running as SYSTEM account, this may fail. On Windows 11, winget should already be installed."
    
    try {
        # Try Add-AppxPackage - this may fail under SYSTEM account
        Add-AppxPackage -Path $AppInstallerPath -ErrorAction Stop
        Write-Host "App Installer package installed successfully."
        
        # Wait a moment for installation to complete
        Start-Sleep -Seconds 10
        
        # Refresh environment to pick up new PATH entries
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Try to find winget again after installation attempt
        $wingetPath = Find-WingetPath
        if ($wingetPath) {
            $wingetDir = Split-Path -Parent $wingetPath
            $env:Path = "$wingetDir;$env:Path"
        }
        
        # Check if winget is now available
        $maxRetries = 5
        $retryCount = 0
        $wingetInstalled = $false
        
        while ($retryCount -lt $maxRetries -and -not $wingetInstalled) {
            if (Test-WingetAvailable) {
                $wingetVersion = winget --version
                Write-Host "winget installed successfully. Version: $wingetVersion"
                $wingetInstalled = $true
            }
            else {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Waiting for winget to become available... (Attempt $retryCount/$maxRetries)"
                    Start-Sleep -Seconds 5
                }
            }
        }
        
        if ($wingetInstalled) {
            # Clean up installer
            if (Test-Path $AppInstallerPath) {
                Remove-Item -Path $AppInstallerPath -Force
                Write-Host "Installer file cleaned up."
            }
            exit 0
        }
        else {
            Write-Warning "winget installation completed but not yet available. It may require a restart or PATH refresh."
            Write-Warning "You may need to restart the PowerShell session or the system."
        }
    }
    catch {
        Write-Warning "Add-AppxPackage failed (this is expected when running as SYSTEM account): $_"
        Write-Host "On Windows 11, winget should already be installed. Attempting to locate it..."
        
        # Clean up installer
        if (Test-Path $AppInstallerPath) {
            Remove-Item -Path $AppInstallerPath -Force -ErrorAction SilentlyContinue
        }
        
        # Try one more time to find winget (it might have been installed but just not in PATH)
        $wingetPath = Find-WingetPath
        if ($wingetPath) {
            Write-Host "Found winget after installation attempt at: $wingetPath"
            $wingetDir = Split-Path -Parent $wingetPath
            $env:Path = "$wingetDir;$env:Path"
            
            if (Test-WingetAvailable) {
                $wingetVersion = winget --version
                Write-Host "winget is available. Version: $wingetVersion"
                exit 0
            }
        }
        
        Write-Error "Failed to install or locate winget. On Windows 11, winget should be pre-installed."
        Write-Error "If this is a custom Windows image, you may need to ensure winget is included in the base image."
        Write-Error "Microsoft Store link: https://www.microsoft.com/store/productId/9NBLGGH4NNS1"
        exit 1
    }
}
catch {
    Write-Error "Failed to install winget via direct download: $_"
    exit 1
}

# Final verification
Write-Host "Performing final verification..."
if (Test-WingetAvailable) {
    $wingetVersion = winget --version
    Write-Host "winget is now available. Version: $wingetVersion"
    Write-Host "Installation completed successfully."
    exit 0
}
else {
    Write-Error "winget installation failed or is not yet available."
    Write-Error "Please install App Installer from the Microsoft Store manually, or restart the system."
    Write-Error "Microsoft Store link: https://www.microsoft.com/store/productId/9NBLGGH4NNS1"
    exit 1
}

### End Script ###

