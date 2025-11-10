#description: Installs PowerShell 7.2+ (pwsh) for running modern PowerShell scripts
#tags: Nerdio, PowerShell, Installation

<#
.SYNOPSIS
    Installs the latest PowerShell 7 on Windows systems.

.DESCRIPTION
    This script installs the latest PowerShell 7 (pwsh) which is required for modern 
    PowerShell scripts. It checks if PowerShell 7.2+ is already installed, downloads 
    the latest MSI from GitHub, and installs it silently.

.EXAMPLE
    .\install-powershell7.ps1
    
.NOTES
    Requires: Administrator privileges and internet connection
#>

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "Installing PowerShell 7..." -ForegroundColor Cyan

# Check if PowerShell 7.2+ is already installed
try {
    $pwshVersion = & pwsh -Command '$PSVersionTable.PSVersion.ToString()' -ErrorAction SilentlyContinue 2>$null
    if ($pwshVersion) {
        $versionParts = $pwshVersion -split '\.'
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]
        
        if ($major -gt 7 -or ($major -eq 7 -and $minor -ge 2)) {
            Write-Host "PowerShell 7.$minor is already installed. Skipping installation." -ForegroundColor Green
            exit 0
        }
    }
}
catch {
    # PowerShell 7 not installed, continue
}

# Determine architecture
$arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }

# Get latest version from GitHub
Write-Host "Checking for latest PowerShell 7 version..." -ForegroundColor Yellow
try {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" -UseBasicParsing
    $msiAsset = $latestRelease.assets | Where-Object { 
        $_.name -like "PowerShell-*-win-$arch.msi" -and $_.name -notlike "*preview*" 
    } | Select-Object -First 1
    
    if (-not $msiAsset) {
        throw "MSI installer not found for architecture $arch"
    }
    
    $downloadUrl = $msiAsset.browser_download_url
    $installerName = $msiAsset.name
    Write-Host "Found version: $($latestRelease.tag_name)" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to get latest version. Using fallback version 7.4.0"
    $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-$arch.msi"
    $installerName = "PowerShell-7.4.0-win-$arch.msi"
}

# Download installer
$installerPath = Join-Path $env:TEMP $installerName
Write-Host "Downloading installer..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Error "Failed to download installer: $_"
    exit 1
}

# Install silently
Write-Host "Installing PowerShell 7 (this may take a minute)..." -ForegroundColor Yellow
$installArgs = @(
    "/i",
    "`"$installerPath`"",
    "/quiet",
    "/norestart"
)

$process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow -PassThru

if ($process.ExitCode -ne 0) {
    Write-Error "Installation failed with exit code: $($process.ExitCode)"
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
    exit 1
}

# Clean up
Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

# Verify installation
Start-Sleep -Seconds 3
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

try {
    $pwshVersion = & pwsh -Command '$PSVersionTable.PSVersion.ToString()' -ErrorAction Stop 2>$null
    Write-Host "PowerShell 7 installed successfully. Version: $pwshVersion" -ForegroundColor Green
    Write-Host "Run 'pwsh' to launch PowerShell 7." -ForegroundColor Gray
}
catch {
    Write-Warning "Installation completed but verification failed. You may need to restart the system."
    Write-Warning "After restart, run 'pwsh' to verify installation."
}
