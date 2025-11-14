#description: Temporarily disables OneDrive GPO settings to troubleshoot FSLogix login hang
#tags: Troubleshooting, OneDrive, FSLogix, GPO

<#
.SYNOPSIS
    Temporarily disables OneDrive GPO settings that may be causing FSLogix profile load hangs.

.DESCRIPTION
    This script removes or disables the OneDrive registry settings that could cause login hangs:
    - AutoMountTeamSites (most likely culprit - tries to mount all SharePoint sites during login)
    - SilentAccountConfig (tries to auto-sign in during profile load)
    
    This allows you to test if the OneDrive GPO is causing the FSLogix hang.

.NOTES
    Run this script on the affected AVD machine to test if OneDrive settings are the issue.
    If login works after this, you know the GPO is the problem.
#>

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "Disabling OneDrive GPO settings to troubleshoot FSLogix login hang..." -ForegroundColor Yellow
Write-Host ""

$oneDrivePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"

# Check if path exists
if (Test-Path $oneDrivePolicyPath) {
    Write-Host "Found OneDrive policy registry path" -ForegroundColor Green
    
    # Disable AutoMountTeamSites (most likely culprit)
    $autoMount = Get-ItemProperty -Path $oneDrivePolicyPath -Name "AutoMountTeamSites" -ErrorAction SilentlyContinue
    if ($autoMount) {
        Write-Host "  Removing AutoMountTeamSites (was: $($autoMount.AutoMountTeamSites))" -ForegroundColor Yellow
        Remove-ItemProperty -Path $oneDrivePolicyPath -Name "AutoMountTeamSites" -Force -ErrorAction SilentlyContinue
    }
    
    # Disable SilentAccountConfig
    $silentConfig = Get-ItemProperty -Path $oneDrivePolicyPath -Name "SilentAccountConfig" -ErrorAction SilentlyContinue
    if ($silentConfig) {
        Write-Host "  Removing SilentAccountConfig (was: $($silentConfig.SilentAccountConfig))" -ForegroundColor Yellow
        Remove-ItemProperty -Path $oneDrivePolicyPath -Name "SilentAccountConfig" -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
    Write-Host "OneDrive GPO settings disabled." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Have the affected user log out and log back in" -ForegroundColor Gray
    Write-Host "  2. If login works, the OneDrive GPO was the issue" -ForegroundColor Gray
    Write-Host "  3. Consider disabling AutoMountTeamSites in the GPO or adding a delay" -ForegroundColor Gray
} else {
    Write-Host "OneDrive policy registry path not found - GPO may not be applied" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "To re-enable settings, run the GPO script again or run gpupdate /force" -ForegroundColor Gray

### End Script ###

