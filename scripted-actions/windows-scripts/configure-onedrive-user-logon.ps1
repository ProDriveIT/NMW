#description: User logon script to configure OneDrive after FSLogix profile load
#tags: OneDrive, FSLogix, User Logon, GPO

<#
.SYNOPSIS
    User logon script to ensure OneDrive initializes correctly after FSLogix profile load.

.DESCRIPTION
    This script runs at user logon (after FSLogix profile is loaded) and:
    1. Sets Timerautomount registry value to enable SharePoint sync (fixes sync issues)
    2. Ensures OneDrive can initialize properly without blocking profile load
    3. Triggers OneDrive to start if not already running
    
    This should be deployed as a GPO User Logon Script (not Startup Script).

.NOTES
    - Runs in user context (not admin)
    - Deploy via GPO: User Configuration > Policies > Windows Settings > Scripts > Logon
    - This runs AFTER FSLogix profile is loaded, so it won't cause login hangs
#>

$ErrorActionPreference = 'SilentlyContinue'

# Wait a few seconds to ensure FSLogix profile is fully loaded
Start-Sleep -Seconds 5

Write-Host "Configuring OneDrive user settings..." -ForegroundColor Cyan

# Set Timerautomount registry value (fixes SharePoint sync issues)
# This is set per-user in the OneDrive Business account registry
$oneDriveBusinessPath = "HKCU:\SOFTWARE\Microsoft\OneDrive\Accounts\Business1"

if (Test-Path $oneDriveBusinessPath) {
    try {
        # Set Timerautomount to 1 (QWORD) - enables auto-mounting after initial delay
        $existingValue = Get-ItemProperty -Path $oneDriveBusinessPath -Name "Timerautomount" -ErrorAction SilentlyContinue
        
        if (-not $existingValue -or $existingValue.Timerautomount -ne 1) {
            Set-ItemProperty -Path $oneDriveBusinessPath -Name "Timerautomount" -Value 1 -Type QWORD -Force
            Write-Host "  Set Timerautomount = 1 (enables SharePoint sync)" -ForegroundColor Green
        } else {
            Write-Host "  Timerautomount already set" -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "Failed to set Timerautomount: $_"
    }
} else {
    Write-Host "  OneDrive Business account not found yet (will be created on first sign-in)" -ForegroundColor Yellow
}

# Ensure OneDrive process is running (it should auto-start, but verify)
$onedriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue

if (-not $onedriveProcess) {
    Write-Host "  OneDrive not running, starting OneDrive..." -ForegroundColor Yellow
    try {
        # Start OneDrive silently
        $onedrivePath = "${env:ProgramFiles}\Microsoft OneDrive\OneDrive.exe"
        if (Test-Path $onedrivePath) {
            Start-Process -FilePath $onedrivePath -WindowStyle Hidden
            Write-Host "  OneDrive started" -ForegroundColor Green
        } else {
            Write-Warning "OneDrive executable not found at: $onedrivePath"
        }
    }
    catch {
        Write-Warning "Failed to start OneDrive: $_"
    }
} else {
    Write-Host "  OneDrive is running" -ForegroundColor Green
}

Write-Host "OneDrive user configuration complete." -ForegroundColor Green

### End Script ###

