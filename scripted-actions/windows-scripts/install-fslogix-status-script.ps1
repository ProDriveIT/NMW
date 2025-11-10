#description: Downloads and installs FSLogix Profile Status script for all users
#tags: Nerdio, FSLogix, Monitoring

<#
.SYNOPSIS
    Downloads and installs the FSLogix Profile Status script for all users.

.DESCRIPTION
    This script downloads the FSLogix Profile Status script from GitHub and installs it
    in a location accessible to all users. It also creates a desktop shortcut and adds
    it to the Start Menu for easy access.

.EXAMPLE
    .\install-fslogix-status-script.ps1
    
.NOTES
    Requires:
    - Administrator privileges
    - Internet connection to download script
    - PowerShell 7.2+ (will check and prompt if needed)
#>

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "Installing FSLogix Profile Status Script..." -ForegroundColor Cyan
Write-Host ""

# Check if PowerShell 7.2+ is installed
Write-Host "Checking for PowerShell 7.2+..." -ForegroundColor Yellow
try {
    $pwshVersion = & pwsh -Command '$PSVersionTable.PSVersion.ToString()' -ErrorAction Stop 2>$null
    if ($pwshVersion) {
        $versionParts = $pwshVersion -split '\.'
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]
        
        if ($major -gt 7 -or ($major -eq 7 -and $minor -ge 2)) {
            Write-Host "  PowerShell 7.$minor found" -ForegroundColor Green
        }
        else {
            Write-Warning "  PowerShell 7.2+ is required. Please run install-powershell7.ps1 first."
            exit 1
        }
    }
}
catch {
    Write-Warning "  PowerShell 7 not found. Please run install-powershell7.ps1 first."
    exit 1
}

# Create script directory (accessible to all users)
$scriptDir = "C:\Program Files\FSLogixStatus"
Write-Host "Creating script directory: $scriptDir" -ForegroundColor Yellow
if (-not (Test-Path $scriptDir)) {
    New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
}

# Download script from GitHub
$scriptUrl = "https://raw.githubusercontent.com/DrazenNikolic/FSLogix-Profile-Status/main/FSLogix-Status_v1.3.ps1"
$scriptPath = Join-Path $scriptDir "FSLogix-Status.ps1"

Write-Host "Downloading FSLogix Profile Status script..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    Write-Host "  Script downloaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download script: $_"
    exit 1
}

# Create desktop shortcut for all users
Write-Host "Creating desktop shortcut..." -ForegroundColor Yellow
$desktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
$shortcutPath = Join-Path $desktopPath "FSLogix Status.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "pwsh.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$shortcut.WorkingDirectory = $scriptDir
$shortcut.Description = "FSLogix Profile Status Dashboard"
$shortcut.IconLocation = "pwsh.exe,0"
$shortcut.Save()

Write-Host "  Desktop shortcut created" -ForegroundColor Green

# Create Start Menu shortcut
Write-Host "Creating Start Menu shortcut..." -ForegroundColor Yellow
$startMenuPath = [Environment]::GetFolderPath("CommonPrograms")
$startMenuFolder = Join-Path $startMenuPath "FSLogix"
if (-not (Test-Path $startMenuFolder)) {
    New-Item -Path $startMenuFolder -ItemType Directory -Force | Out-Null
}

$startMenuShortcut = Join-Path $startMenuFolder "FSLogix Status.lnk"
$shortcut2 = $shell.CreateShortcut($startMenuShortcut)
$shortcut2.TargetPath = "pwsh.exe"
$shortcut2.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$shortcut2.WorkingDirectory = $scriptDir
$shortcut2.Description = "FSLogix Profile Status Dashboard"
$shortcut2.IconLocation = "pwsh.exe,0"
$shortcut2.Save()

Write-Host "  Start Menu shortcut created" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Installation Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "FSLogix Profile Status script installed:" -ForegroundColor Green
Write-Host "  Location: $scriptPath" -ForegroundColor Gray
Write-Host "  Desktop shortcut: FSLogix Status.lnk" -ForegroundColor Gray
Write-Host "  Start Menu: FSLogix > FSLogix Status" -ForegroundColor Gray
Write-Host ""
Write-Host "Users can now:" -ForegroundColor Cyan
Write-Host "  - Double-click the desktop shortcut" -ForegroundColor Gray
Write-Host "  - Find it in Start Menu under FSLogix" -ForegroundColor Gray
Write-Host "  - Run: pwsh -File `"$scriptPath`"" -ForegroundColor Gray
Write-Host ""

