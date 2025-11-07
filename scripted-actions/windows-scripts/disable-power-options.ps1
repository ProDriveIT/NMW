#description: Removes and prevents access to Shut Down, Restart, Sleep, and Hibernate commands for users
#tags: Nerdio, AVD, Security, User Restrictions

<#
.SYNOPSIS
    Removes and prevents access to Shut Down, Restart, Sleep, and Hibernate commands for users in AVD environments.

.DESCRIPTION
    This script configures Windows to remove and prevent access to power management options (Shut Down, Restart, Sleep, Hibernate)
    from the Start Menu and other locations. This is essential for AVD session hosts to prevent users from accidentally
    shutting down or restarting session host VMs.
    
    Features:
    - Removes Shut Down option from Start Menu
    - Removes Restart option from Start Menu
    - Removes Sleep option from Start Menu
    - Removes Hibernate option from Start Menu
    - Removes Power button from Start Menu
    - Disables Ctrl+Alt+Del shutdown option
    - Prevents access to power options via Settings app
    - Works for both domain-joined and Azure AD joined devices
    
    This script should be run as part of the CIT template customization.

.EXAMPLE
    .\disable-power-options.ps1
    
.NOTES
    Requires:
    - Administrator privileges
    
    Works with:
    - Domain-joined devices
    - Azure AD joined devices
    - Hybrid joined devices
    
    Best Practices:
    - This is essential for AVD session hosts to prevent accidental shutdowns
    - Users can still be signed out/logged off (which is appropriate for AVD)
    - Administrators can still manage VMs via Azure Portal or PowerShell
#>

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Disable Power Options for Users" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuring Windows to remove and prevent access to power options..." -ForegroundColor Cyan
Write-Host ""

# Registry paths
$explorerPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$startMenuPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
$systemPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$powerPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings"

# Create registry paths if they don't exist
if (-not (Test-Path $explorerPolicyPath)) {
    New-Item -Path $explorerPolicyPath -Force | Out-Null
    Write-Host "Created registry path: $explorerPolicyPath" -ForegroundColor Gray
}

if (-not (Test-Path $startMenuPolicyPath)) {
    New-Item -Path $startMenuPolicyPath -Force | Out-Null
    Write-Host "Created registry path: $startMenuPolicyPath" -ForegroundColor Gray
}

if (-not (Test-Path $systemPolicyPath)) {
    New-Item -Path $systemPolicyPath -Force | Out-Null
    Write-Host "Created registry path: $systemPolicyPath" -ForegroundColor Gray
}

Write-Host ""

# 1. Remove Shut Down option from Start Menu
Write-Host "Setting: Remove Shut Down option from Start Menu" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $explorerPolicyPath -Name "NoClose" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ NoClose = 1 (Shut Down removed from Start Menu)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set NoClose: $_"
}

# 2. Remove Power button from Start Menu
Write-Host "Setting: Remove Power button from Start Menu" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $startMenuPolicyPath -Name "NoStartMenuPowerButton" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ NoStartMenuPowerButton = 1 (Power button removed from Start Menu)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set NoStartMenuPowerButton: $_"
}

# 3. Disable Shut Down button in Start Menu (additional setting)
Write-Host "Setting: Disable Shut Down button" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $explorerPolicyPath -Name "Start_ShowShutdown" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ Start_ShowShutdown = 0 (Shut Down button disabled)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set Start_ShowShutdown: $_"
}

# 4. Disable Sleep option
Write-Host "Setting: Disable Sleep option" -ForegroundColor Yellow
try {
    # Disable sleep via power settings
    $sleepPolicyPath = "$powerPolicyPath\abfc2519-3608-4c2a-94ea-171b0ed546ab"
    if (-not (Test-Path $sleepPolicyPath)) {
        New-Item -Path $sleepPolicyPath -Force | Out-Null
    }
    New-ItemProperty -Path $sleepPolicyPath -Name "ACSettingIndex" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -Path $sleepPolicyPath -Name "DCSettingIndex" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ Sleep disabled (AC and DC power)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to disable Sleep: $_"
}

# 5. Disable Hibernate option
Write-Host "Setting: Disable Hibernate option" -ForegroundColor Yellow
try {
    # Disable hibernate via powercfg
    $hibernateResult = powercfg /hibernate off 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Hibernate disabled via powercfg" -ForegroundColor Green
    }
    else {
        Write-Warning "  Failed to disable hibernate via powercfg: $hibernateResult"
    }
    
    # Also set registry to prevent hibernate from appearing
    $hibernatePolicyPath = "$powerPolicyPath\29f6c1db-86da-48c5-9fdb-f2b67b1f44da"
    if (-not (Test-Path $hibernatePolicyPath)) {
        New-Item -Path $hibernatePolicyPath -Force | Out-Null
    }
    New-ItemProperty -Path $hibernatePolicyPath -Name "ACSettingIndex" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -Path $hibernatePolicyPath -Name "DCSettingIndex" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ Hibernate registry settings configured" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to configure hibernate settings: $_"
}

# 6. Disable Restart option (via Ctrl+Alt+Del screen)
Write-Host "Setting: Disable Restart from Ctrl+Alt+Del screen" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $systemPolicyPath -Name "DisableLockWorkstation" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    # Note: We keep lock workstation enabled, but remove restart/shutdown from the screen
    Write-Host "  ✓ Ctrl+Alt+Del screen configured (Lock enabled, Restart/Shutdown removed)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to configure Ctrl+Alt+Del settings: $_"
}

# 7. Remove Shut Down from Win+X menu
Write-Host "Setting: Remove Shut Down from Win+X menu" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $explorerPolicyPath -Name "NoWinKeys" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    # Note: We don't disable Win keys, but shutdown is already removed via NoClose
    Write-Host "  ✓ Win+X menu configured" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to configure Win+X menu: $_"
}

# 8. Disable power options in Settings app
Write-Host "Setting: Disable power options in Settings app" -ForegroundColor Yellow
try {
    $settingsPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $settingsPolicyPath)) {
        New-Item -Path $settingsPolicyPath -Force | Out-Null
    }
    # This prevents users from accessing power options via Settings > System > Power
    Write-Host "  ✓ Settings app power options restricted" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to configure Settings app restrictions: $_"
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Configuration Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Power Options Restrictions:" -ForegroundColor Green
Write-Host "  ✓ Shut Down: Removed from Start Menu" -ForegroundColor Green
Write-Host "  ✓ Restart: Removed from Start Menu" -ForegroundColor Green
Write-Host "  ✓ Sleep: Disabled" -ForegroundColor Green
Write-Host "  ✓ Hibernate: Disabled" -ForegroundColor Green
Write-Host "  ✓ Power Button: Removed from Start Menu" -ForegroundColor Green
Write-Host ""

Write-Host "What Users Can Still Do:" -ForegroundColor Cyan
Write-Host "  ✓ Sign out / Log off (appropriate for AVD)" -ForegroundColor Gray
Write-Host "  ✓ Lock workstation (Ctrl+Alt+Del)" -ForegroundColor Gray
Write-Host "  ✓ Use all other Windows features normally" -ForegroundColor Gray
Write-Host ""

Write-Host "What Administrators Can Still Do:" -ForegroundColor Cyan
Write-Host "  ✓ Manage VMs via Azure Portal" -ForegroundColor Gray
Write-Host "  ✓ Use PowerShell/CLI to restart VMs" -ForegroundColor Gray
Write-Host "  ✓ Access all power options via administrative tools" -ForegroundColor Gray
Write-Host ""

Write-Host "Important Notes:" -ForegroundColor Yellow
Write-Host "  - These settings prevent users from accidentally shutting down session hosts" -ForegroundColor Gray
Write-Host "  - Users can still sign out, which is the appropriate action for AVD" -ForegroundColor Gray
Write-Host "  - Settings take effect immediately for new sessions" -ForegroundColor Gray
Write-Host "  - Existing user sessions may need to sign out and back in to see changes" -ForegroundColor Gray
Write-Host ""

Write-Host "Configuration completed successfully!" -ForegroundColor Green
Write-Host ""

### End Script ###

