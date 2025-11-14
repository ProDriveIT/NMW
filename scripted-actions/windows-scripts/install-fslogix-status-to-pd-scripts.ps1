#description: Downloads FSLogix Status script to C:\PD-Scripts during CIT build
#tags: Nerdio, FSLogix, Monitoring, CIT

<#
.SYNOPSIS
    Downloads the FSLogix Profile Status script to C:\PD-Scripts during CIT build.
    This script replaces the traffic lights functionality.

.DESCRIPTION
    Downloads the FSLogix Profile Status script from GitHub and places it in C:\PD-Scripts.
    This script provides a dashboard showing FSLogix profile status, replacing the 
    traditional traffic lights indicator.

.EXAMPLE
    .\install-fslogix-status-to-pd-scripts.ps1
    
.NOTES
    Requires:
    - Administrator privileges
    - Internet connection to download script
    - PowerShell 7.2+ (will check and prompt if needed)
    
    Script Source: https://github.com/DrazenNikolic/FSLogix-Profile-Status
    Version: v1.3
#>

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "Installing FSLogix Status Script to C:\PD-Scripts..." -ForegroundColor Cyan
Write-Host ""

# Create C:\PD-Scripts directory if it doesn't exist
$scriptDir = "C:\PD-Scripts"
Write-Host "Creating directory: $scriptDir" -ForegroundColor Yellow
if (-not (Test-Path $scriptDir)) {
    New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
    Write-Host "  Directory created" -ForegroundColor Green
} else {
    Write-Host "  Directory already exists" -ForegroundColor Gray
}

# Download script from GitHub
$scriptUrl = "https://raw.githubusercontent.com/DrazenNikolic/FSLogix-Profile-Status/main/FSLogix-Status_v1.3.ps1"
$scriptPath = Join-Path $scriptDir "FSLogix-Status.ps1"

Write-Host "Downloading FSLogix Profile Status script..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    Write-Host "  Script downloaded successfully to: $scriptPath" -ForegroundColor Green
} catch {
    Write-Error "Failed to download script: $_"
    exit 1
}

# Verify script was downloaded
if (Test-Path $scriptPath) {
    $scriptInfo = Get-Item $scriptPath
    Write-Host "  File size: $([math]::Round($scriptInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
    Write-Host "  Last modified: $($scriptInfo.LastWriteTime)" -ForegroundColor Gray
} else {
    Write-Error "Script file not found after download"
    exit 1
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Installation Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "FSLogix Profile Status script installed:" -ForegroundColor Green
Write-Host "  Location: $scriptPath" -ForegroundColor Gray
Write-Host ""
Write-Host "To run the script:" -ForegroundColor Cyan
Write-Host "  pwsh -File `"$scriptPath`"" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: This script replaces the traffic lights functionality." -ForegroundColor Yellow
Write-Host "      It provides a comprehensive dashboard showing FSLogix profile status." -ForegroundColor Gray
Write-Host ""

### End Script ###

