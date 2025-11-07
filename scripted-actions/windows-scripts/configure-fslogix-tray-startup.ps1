#description: Configures FSLogix tray application to run at user logon
#tags: Nerdio, AVD, FSLogix, Startup

<#
.SYNOPSIS
    Configures FSLogix tray application (frxtray.exe) to run automatically at user logon.

.DESCRIPTION
    This script adds the FSLogix tray application to the Windows startup registry, ensuring it runs
    automatically when users log in to AVD session hosts. The FSLogix tray provides a system tray icon
    that allows users to see FSLogix profile status and access FSLogix settings.
    
    Features:
    - Adds frxtray.exe to Windows startup registry (runs for all users)
    - Verifies FSLogix is installed before configuring
    - Works for all users on the system
    - Provides visual feedback in system tray for FSLogix profile status
    
    This script should be run AFTER FSLogix is installed (typically via CIT built-in script).

.EXAMPLE
    .\configure-fslogix-tray-startup.ps1
    
.NOTES
    Requires:
    - Administrator privileges
    - FSLogix must be installed (frxtray.exe must exist)
    
    Registry Location:
    - HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run (runs for all users at logon)
    
    The FSLogix tray application provides:
    - System tray icon showing FSLogix profile status
    - Access to FSLogix profile information
    - Visual indication that FSLogix is active
#>

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Configure FSLogix Tray Startup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# FSLogix tray executable path
$fsLogixTrayPath = "C:\Program Files\FSLogix\Apps\frxtray.exe"

# Verify FSLogix is installed
Write-Host "Checking for FSLogix installation..." -ForegroundColor Cyan
if (-not (Test-Path $fsLogixTrayPath)) {
    Write-Warning "FSLogix tray application not found at: $fsLogixTrayPath"
    Write-Warning "Please ensure FSLogix is installed before running this script."
    Write-Host ""
    Write-Host "FSLogix is typically installed via the CIT built-in script:" -ForegroundColor Yellow
    Write-Host "  'Install and enable FSLogix' in the Customizations tab" -ForegroundColor Gray
    exit 1
}

Write-Host "  ✓ FSLogix tray found: $fsLogixTrayPath" -ForegroundColor Green
Write-Host ""

# Registry path for startup items (runs for all users)
$startupRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$startupItemName = "FSLogixTray"

Write-Host "Configuring FSLogix tray to run at user logon..." -ForegroundColor Cyan
Write-Host ""

# Check if already configured
$existingValue = Get-ItemProperty -Path $startupRegistryPath -Name $startupItemName -ErrorAction SilentlyContinue
if ($existingValue -and $existingValue.$startupItemName) {
    Write-Host "FSLogix tray is already configured to run at logon." -ForegroundColor Yellow
    Write-Host "  Current value: $($existingValue.$startupItemName)" -ForegroundColor Gray
    
    # Check if the path matches
    if ($existingValue.$startupItemName -eq $fsLogixTrayPath) {
        Write-Host "  ✓ Configuration is correct, no changes needed." -ForegroundColor Green
        Write-Host ""
        exit 0
    }
    else {
        Write-Host "  Updating to correct path..." -ForegroundColor Yellow
    }
}

# Add FSLogix tray to startup registry
Write-Host "Setting: Add FSLogix tray to startup" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $startupRegistryPath -Name $startupItemName -Value $fsLogixTrayPath -PropertyType String -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ FSLogix tray added to startup registry" -ForegroundColor Green
    Write-Host "    Registry: $startupRegistryPath\$startupItemName" -ForegroundColor Gray
    Write-Host "    Value: $fsLogixTrayPath" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to add FSLogix tray to startup: $_"
    exit 1
}

# Verify the setting was applied
Write-Host ""
Write-Host "Verifying configuration..." -ForegroundColor Cyan
$verifyValue = Get-ItemProperty -Path $startupRegistryPath -Name $startupItemName -ErrorAction SilentlyContinue
if ($verifyValue -and $verifyValue.$startupItemName -eq $fsLogixTrayPath) {
    Write-Host "  ✓ Configuration verified successfully" -ForegroundColor Green
}
else {
    Write-Warning "  Configuration verification failed. Please check manually."
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Configuration Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "FSLogix Tray Startup Configuration:" -ForegroundColor Green
Write-Host "  ✓ FSLogix tray will run at user logon" -ForegroundColor Green
Write-Host "  ✓ Applies to all users on this system" -ForegroundColor Green
Write-Host "  ✓ Registry location: $startupRegistryPath\$startupItemName" -ForegroundColor Green
Write-Host ""

Write-Host "What This Provides:" -ForegroundColor Cyan
Write-Host "  - System tray icon showing FSLogix profile status" -ForegroundColor Gray
Write-Host "  - Visual indication that FSLogix is active" -ForegroundColor Gray
Write-Host "  - Access to FSLogix profile information via tray icon" -ForegroundColor Gray
Write-Host ""

Write-Host "Important Notes:" -ForegroundColor Yellow
Write-Host "  - The tray application will start automatically for all users" -ForegroundColor Gray
Write-Host "  - Changes take effect on next user logon" -ForegroundColor Gray
Write-Host "  - Existing sessions will not see the tray until they log out and back in" -ForegroundColor Gray
Write-Host ""

Write-Host "Configuration completed successfully!" -ForegroundColor Green
Write-Host "FSLogix tray will run at user logon." -ForegroundColor Green
Write-Host ""

### End Script ###

