#description: Installs Adobe Acrobat Reader DC for all users using winget (system-level installation)
#tags: Nerdio, Apps install

<#
Notes:
This script uses Windows Package Manager (winget) to install Adobe Acrobat Reader DC as a system-level installation for all users.
This ensures Reader is available to all users and is compatible with sysprep for AVD image templates.

Key features:
- Uses winget (built into Windows 11) for reliable installation
- Installs Reader to Program Files (system-wide, not per-user)
- Makes Reader available to all users
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

# Function to find winget if not in PATH
function Find-WingetPath {
    $wingetPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
    )
    
    foreach ($path in $wingetPaths) {
        $resolvedPaths = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($resolvedPath in $resolvedPaths) {
            if (Test-Path $resolvedPath.FullName) {
                return $resolvedPath.FullName
            }
        }
    }
    
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

# Check if winget is available
Write-Host "Checking for Windows Package Manager (winget)..."
$wingetCommand = "winget"

try {
    $wingetVersion = winget --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "winget not found in PATH"
    }
    Write-Host "winget is available: $wingetVersion"
}
catch {
    Write-Host "winget not found in PATH. Searching for winget installation..."
    $wingetPath = Find-WingetPath
    
    if ($wingetPath) {
        Write-Host "Found winget at: $wingetPath"
        Write-Host "Adding to PATH for current session..."
        $wingetDir = Split-Path -Parent $wingetPath
        $env:Path = "$wingetDir;$env:Path"
        
        # Try again
        try {
            $wingetVersion = winget --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "winget is now available: $wingetVersion"
            }
            else {
                throw "winget still not working"
            }
        }
        catch {
            # Use direct path as fallback
            Write-Host "Using winget via direct path: $wingetPath"
            $wingetCommand = $wingetPath
        }
    }
    else {
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
        Write-Error "Note: On Windows 11, winget should already be installed - it may just need to be located."
        exit 1
    }
}

# Detect system architecture
$Is64Bit = [Environment]::Is64BitOperatingSystem
if ($Is64Bit) {
    Write-Host "Detected 64-bit system. Will install Adobe Acrobat Reader DC x64."
} else {
    Write-Host "Detected 32-bit system. Will install Adobe Acrobat Reader DC x86."
}

# Check if Adobe Reader is already installed (system-level)
Write-Host "Checking if Adobe Acrobat Reader DC is already installed..."
$ReaderInstalled = $false
if ($Is64Bit) {
    $ReaderInstalled = (Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe") -or (Test-Path "C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe")
} else {
    $ReaderInstalled = (Test-Path "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe")
}

if ($ReaderInstalled) {
    Write-Host "Adobe Reader is already installed. Checking version..."
    $readerPaths = @(
        "C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
        "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
    )
    foreach ($readerPath in $readerPaths) {
        if (Test-Path $readerPath) {
            $ExistingVersion = (Get-Item $readerPath).VersionInfo.FileVersion
            Write-Host "Existing Adobe Reader version: $ExistingVersion"
            break
        }
    }
    
    # Uninstall existing Reader using winget to ensure clean installation
    Write-Host "Uninstalling existing version to ensure clean installation..."
    try {
        # Try multiple possible package IDs for Adobe Reader
        $adobePackageIds = @("Adobe.Acrobat.Reader.64-bit", "Adobe.Acrobat.Reader.32-bit", "Adobe.AcrobatReaderDC")
        
        $uninstalled = $false
        foreach ($packageId in $adobePackageIds) {
            try {
                & $wingetCommand uninstall --id $packageId --scope machine --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Uninstalled using package ID: $packageId"
                    $uninstalled = $true
                    break
                }
            }
            catch {
                # Continue to next package ID
            }
        }
        
        if ($uninstalled) {
            Start-Sleep -Seconds 5
            
            # Wait for uninstall to complete
            $maxWait = 30
            $waitCount = 0
            while ($waitCount -lt $maxWait -and $ReaderInstalled) {
                $ReaderInstalled = (Test-Path "C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe") -or (Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe")
                if (-not $ReaderInstalled) {
                    break
                }
                Start-Sleep -Seconds 2
                $waitCount += 2
            }
            Write-Host "Uninstall completed."
        }
        else {
            Write-Warning "Failed to uninstall existing Reader via winget. Attempting to continue with installation..."
        }
    }
    catch {
        Write-Warning "Failed to uninstall existing Reader via winget: $_"
        Write-Warning "Attempting to continue with installation..."
    }
}

# Install Adobe Reader using winget with machine-wide scope
Write-Host "Installing Adobe Acrobat Reader DC for all users (system-level) using winget..."
Write-Host "This may take a few minutes as winget downloads and installs Adobe Reader..."

try {
    # Use winget to install Adobe Reader with machine-wide scope
    # --scope machine ensures installation for all users (system-wide)
    # --silent performs silent installation
    # --accept-package-agreements and --accept-source-agreements auto-accept licenses
    # Try 64-bit package ID first, fallback to generic if needed
    $packageId = if ($Is64Bit) { "Adobe.Acrobat.Reader.64-bit" } else { "Adobe.Acrobat.Reader.32-bit" }
    
    $wingetOutput = & $wingetCommand install --id $packageId --scope machine --silent --accept-package-agreements --accept-source-agreements 2>&1
    
    # Check exit code
    if ($LASTEXITCODE -eq 0) {
        Write-Host "winget installation command completed successfully."
    }
    else {
        # Check if Reader was already installed (exit code 0x8A150011 or similar)
        $outputString = $wingetOutput -join "`n"
        if ($outputString -match "already installed" -or $outputString -match "0x8A150011") {
            Write-Host "Adobe Reader is already installed (detected by winget)."
        }
        else {
            # Try alternative package ID
            Write-Host "Trying alternative package ID..."
            $wingetOutput = & $wingetCommand install --id "Adobe.AcrobatReaderDC" --scope machine --silent --accept-package-agreements --accept-source-agreements 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "winget installation command completed successfully with alternative package ID."
            }
            else {
                Write-Error "winget installation failed with exit code: $LASTEXITCODE"
                Write-Error "Output: $outputString"
                exit 1
            }
        }
    }
}
catch {
    Write-Error "Failed to install Adobe Reader using winget: $_"
    exit 1
}

# Wait for installation to complete and verify
Write-Host "Verifying installation..."
Start-Sleep -Seconds 5

# Retry verification if needed
$maxRetries = 6
$retryCount = 0
$installationVerified = $false

# Define expected installation paths based on architecture
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

while ($retryCount -lt $maxRetries -and -not $installationVerified) {
    foreach ($readerPath in $readerPaths) {
        if (Test-Path $readerPath) {
            $readerVersion = (Get-Item $readerPath).VersionInfo.FileVersion
            Write-Host "Adobe Acrobat Reader DC version $readerVersion installed successfully at: $readerPath"
            $installationVerified = $true
            break
        }
    }
    
    if (-not $installationVerified) {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "Adobe Reader executable not found yet. Waiting 10 seconds and retrying... (Attempt $retryCount/$maxRetries)"
            Start-Sleep -Seconds 10
        }
    }
}

# Final verification
if (-not $installationVerified) {
    Write-Error "Adobe Reader installation verification failed. Executable not found at expected locations."
    Write-Error "Expected paths:"
    foreach ($readerPath in $readerPaths) {
        Write-Error "  - $readerPath"
    }
    exit 1
}

# Verify installation is system-wide (not per-user)
$programFilesReader = $false
foreach ($readerPath in $readerPaths) {
    if (Test-Path $readerPath) {
        $programFilesReader = $true
        break
    }
}

if ($programFilesReader) {
    Write-Host "Verification: Adobe Reader is installed system-wide (Program Files) - compatible with sysprep."
}
else {
    Write-Warning "Warning: Adobe Reader may not be installed system-wide."
    Write-Warning "This may cause issues with sysprep. Installation may need to be reviewed."
}

Write-Host "Adobe Acrobat Reader DC installation completed successfully using winget."
Write-Host "Adobe Reader is installed system-wide and ready for sysprep."

### End Script ###

