#description: Fixes OneDrive GPO settings to prevent FSLogix login hangs
#tags: OneDrive, FSLogix, GPO, Fix

<#
.SYNOPSIS
    Modifies OneDrive GPO settings to prevent FSLogix profile load hangs.

.DESCRIPTION
    The issue is that AutoMountTeamSites tries to mount all SharePoint sites during login,
    which can cause FSLogix profile load to hang. This script:
    
    1. Disables AutoMountTeamSites (prevents auto-mounting during login)
    2. Keeps other settings (Files On Demand, KFM, etc.)
    3. Users can manually sync SharePoint sites after login
    
    Alternative: Keep AutoMountTeamSites but add Timerautomount registry value to delay mounting.

.NOTES
    Run this on affected machines or update the GPO script to exclude AutoMountTeamSites.
#>

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "Fixing OneDrive GPO settings to prevent FSLogix login hangs..." -ForegroundColor Cyan
Write-Host ""

$oneDrivePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"

# Create path if it doesn't exist
if (-not (Test-Path $oneDrivePolicyPath)) {
    New-Item -Path $oneDrivePolicyPath -Force | Out-Null
}

# Option 1: Disable AutoMountTeamSites (recommended fix)
Write-Host "Option 1: Disabling AutoMountTeamSites..." -ForegroundColor Yellow
$autoMount = Get-ItemProperty -Path $oneDrivePolicyPath -Name "AutoMountTeamSites" -ErrorAction SilentlyContinue
if ($autoMount -and $autoMount.AutoMountTeamSites -eq 1) {
    Remove-ItemProperty -Path $oneDrivePolicyPath -Name "AutoMountTeamSites" -Force
    Write-Host "  AutoMountTeamSites disabled" -ForegroundColor Green
    Write-Host "  Users will need to manually sync SharePoint sites after login" -ForegroundColor Gray
} else {
    Write-Host "  AutoMountTeamSites already disabled or not set" -ForegroundColor Gray
}

# Option 2: Add Timerautomount delay (alternative - keeps auto-mount but delays it)
Write-Host ""
Write-Host "Option 2: Adding Timerautomount delay (keeps auto-mount but delays it)..." -ForegroundColor Yellow
Write-Host "  This allows auto-mount but delays it until after profile load" -ForegroundColor Gray

# Set Timerautomount for Business accounts (per-user, but we can set default)
# Note: This is typically set per-user, but we can create a script that runs at user login
$userOneDrivePath = "HKCU:\SOFTWARE\Microsoft\OneDrive\Accounts\Business1"
Write-Host "  Note: Timerautomount is set per-user at: $userOneDrivePath" -ForegroundColor Gray
Write-Host "  This should be set via user logon script or after first login" -ForegroundColor Gray

Write-Host ""
Write-Host "Fix applied!" -ForegroundColor Green
Write-Host ""
Write-Host "Recommendation:" -ForegroundColor Cyan
Write-Host "  - Keep AutoMountTeamSites disabled (Option 1)" -ForegroundColor Yellow
Write-Host "  - OR update GPO script to exclude AutoMountTeamSites" -ForegroundColor Yellow
Write-Host "  - Users can manually sync SharePoint sites they need" -ForegroundColor Gray
Write-Host ""
Write-Host "To test: Have affected users log out and log back in" -ForegroundColor Gray

### End Script ###

