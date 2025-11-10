#description: Downloads and installs CA Interactive Checklist shortcut to public desktop
#tags: Nerdio, Shortcut, Deployment

<#
.SYNOPSIS
    Downloads and installs the CA Interactive Checklist shortcut to the public desktop.

.DESCRIPTION
    This script downloads the CA Interactive Checklist shortcut from GitHub and places it
    on the public desktop so all users can access it. The shortcut points to:
    \\CAAZURAPP01\Interactive Checklist\InteractiveChecklist.exe

.EXAMPLE
    .\install-interactive-checklist-shortcut.ps1
    
.NOTES
    Requires:
    - Administrator privileges
    - Internet connection to download shortcut
    - Network access to \\CAAZURAPP01\Interactive Checklist
#>

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "Installing CA Interactive Checklist Shortcut..." -ForegroundColor Cyan
Write-Host ""

# GitHub raw URL for the shortcut file
$shortcutUrl = "https://raw.githubusercontent.com/ProDriveIT/NMW/main/scripted-actions/CA-InteractiveChecklist%20-%20Shortcut.lnk"
$shortcutName = "CA-InteractiveChecklist - Shortcut.lnk"

# Public desktop path
$publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
$targetPath = Join-Path $publicDesktop $shortcutName

Write-Host "Target location: $targetPath" -ForegroundColor Gray
Write-Host ""

# Check if shortcut already exists
if (Test-Path $targetPath) {
    Write-Host "Shortcut already exists. Removing old version..." -ForegroundColor Yellow
    Remove-Item -Path $targetPath -Force -ErrorAction Stop
}

# Download shortcut from GitHub
Write-Host "Downloading shortcut from GitHub..." -ForegroundColor Yellow
$tempPath = Join-Path $env:TEMP $shortcutName

try {
    Invoke-WebRequest -Uri $shortcutUrl -OutFile $tempPath -UseBasicParsing -ErrorAction Stop
    Write-Host "  Shortcut downloaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download shortcut: $_"
    Write-Host ""
    Write-Host "Alternative: You can manually download from:" -ForegroundColor Yellow
    Write-Host "  $shortcutUrl" -ForegroundColor Gray
    exit 1
}

# Copy to public desktop
Write-Host "Copying shortcut to public desktop..." -ForegroundColor Yellow
try {
    Copy-Item -Path $tempPath -Destination $targetPath -Force -ErrorAction Stop
    Write-Host "  Shortcut installed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to copy shortcut to public desktop: $_"
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    exit 1
}

# Clean up temp file
Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue

# Verify the shortcut
Write-Host ""
Write-Host "Verifying shortcut..." -ForegroundColor Cyan
if (Test-Path $targetPath) {
    try {
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($targetPath)
        Write-Host "  Target: $($shortcut.TargetPath)" -ForegroundColor Gray
        if ($shortcut.WorkingDirectory) {
            Write-Host "  Working Directory: $($shortcut.WorkingDirectory)" -ForegroundColor Gray
        }
        Write-Host "  Shortcut verified" -ForegroundColor Green
    }
    catch {
        Write-Warning "  Could not read shortcut properties, but file exists at: $targetPath"
        Write-Host "  File size: $((Get-Item $targetPath).Length) bytes" -ForegroundColor Gray
    }
}
else {
    Write-Warning "  Shortcut file not found at target location"
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Installation Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "CA Interactive Checklist shortcut installed:" -ForegroundColor Green
Write-Host "  Location: $targetPath" -ForegroundColor Gray
Write-Host "  Target: \\CAAZURAPP01\Interactive Checklist\InteractiveChecklist.exe" -ForegroundColor Gray
Write-Host ""
Write-Host "All users will see this shortcut on their desktop." -ForegroundColor Gray
Write-Host ""

