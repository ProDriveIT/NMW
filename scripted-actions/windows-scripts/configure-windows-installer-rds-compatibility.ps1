#description: Configures 'Turn off Windows Installer RDS Compatibility' policy for AVD session hosts
#tags: Nerdio, AVD, RDS, Windows Installer, Compatibility

<#
.SYNOPSIS
    Configures the 'Turn off Windows Installer RDS Compatibility' policy for AVD session hosts.

.DESCRIPTION
    This script enables the Group Policy setting "Turn off Windows Installer RDS Compatibility"
    under Computer Configuration\Administrative Templates\Windows Components\Remote Desktop Services\
    Remote Desktop Session Host\Application Compatibility.

    When enabled, this policy prevents Windows Installer from applying its compatibility fixes
    for Remote Desktop Services (RDS). This can be beneficial in AVD environments to ensure
    applications install and behave as expected without RDS-specific modifications, especially
    when applications are already designed for multi-user environments or when compatibility
    issues arise from the RDS compatibility layer.
    
    Features:
    - Enables "Turn off Windows Installer RDS Compatibility" policy
    - Configures registry setting for all users
    - Prevents Windows Installer from applying RDS compatibility fixes
    - Useful for applications that don't need RDS compatibility layer

.EXAMPLE
    .\configure-windows-installer-rds-compatibility.ps1
    
.NOTES
    Requires:
    - Administrator privileges
    
    Registry Location:
    - HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\Application Compatibility\DisableMsi
    
    Policy Path:
    - Computer Configuration\Administrative Templates\Windows Components\Remote Desktop Services\
      Remote Desktop Session Host\Application Compatibility\Turn off Windows Installer RDS Compatibility
    
    When to use:
    - Applications install incorrectly due to RDS compatibility layer
    - Applications are already designed for multi-user environments
    - You want to prevent Windows Installer from modifying application behavior for RDS
#>

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Configure Windows Installer RDS Compatibility" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Registry path for the policy
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\Application Compatibility"
$regPropertyName = "DisableMsi"
$regPropertyValue = 1  # 1 = Enabled (Turn off RDS Compatibility), 0 = Disabled

Write-Host "Configuring 'Turn off Windows Installer RDS Compatibility' policy..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Policy: Turn off Windows Installer RDS Compatibility" -ForegroundColor Yellow
Write-Host "Setting: Enabled" -ForegroundColor Yellow
Write-Host "Registry Path: $regPath" -ForegroundColor Gray
Write-Host "Registry Property: $regPropertyName" -ForegroundColor Gray
Write-Host ""

# Create registry path if it doesn't exist
if (-not (Test-Path $regPath)) {
    Write-Host "Creating registry path..." -ForegroundColor Yellow
    try {
        New-Item -Path $regPath -Force | Out-Null
        Write-Host "  ✓ Registry path created" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create registry path: $_"
        exit 1
    }
}

# Check current value
$currentValue = Get-ItemProperty -Path $regPath -Name $regPropertyName -ErrorAction SilentlyContinue
if ($currentValue -and $currentValue.$regPropertyName -eq $regPropertyValue) {
    Write-Host "Policy is already configured correctly." -ForegroundColor Green
    Write-Host "  Current value: $($currentValue.$regPropertyName) (Enabled)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Configuration completed successfully!" -ForegroundColor Green
    exit 0
}

# Set the registry property
Write-Host "Setting registry property..." -ForegroundColor Yellow
try {
    New-ItemProperty -Path $regPath -Name $regPropertyName -Value $regPropertyValue -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ DisableMsi = $regPropertyValue (Enabled)" -ForegroundColor Green
    Write-Host "    Windows Installer RDS Compatibility is now disabled" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to set registry property: $_"
    exit 1
}

# Verify the setting
Write-Host ""
Write-Host "Verifying configuration..." -ForegroundColor Cyan
$verifyValue = Get-ItemProperty -Path $regPath -Name $regPropertyName -ErrorAction SilentlyContinue
if ($verifyValue -and $verifyValue.$regPropertyName -eq $regPropertyValue) {
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
Write-Host "Windows Installer RDS Compatibility:" -ForegroundColor Green
Write-Host "  ✓ Policy: Turn off Windows Installer RDS Compatibility" -ForegroundColor Green
Write-Host "  ✓ Status: Enabled" -ForegroundColor Green
Write-Host "  ✓ Registry: $regPath\$regPropertyName = $regPropertyValue" -ForegroundColor Green
Write-Host ""

Write-Host "What This Does:" -ForegroundColor Cyan
Write-Host "  - Prevents Windows Installer from applying RDS compatibility fixes" -ForegroundColor Gray
Write-Host "  - Applications install without RDS-specific modifications" -ForegroundColor Gray
Write-Host "  - Useful for applications already designed for multi-user environments" -ForegroundColor Gray
Write-Host ""

Write-Host "When to Use:" -ForegroundColor Cyan
Write-Host "  - Applications install incorrectly due to RDS compatibility layer" -ForegroundColor Gray
Write-Host "  - Applications are already designed for AVD/multi-user environments" -ForegroundColor Gray
Write-Host "  - You want to prevent Windows Installer from modifying application behavior" -ForegroundColor Gray
Write-Host ""

Write-Host "Important Notes:" -ForegroundColor Yellow
Write-Host "  - Changes take effect immediately" -ForegroundColor Gray
Write-Host "  - Affects all Windows Installer-based applications" -ForegroundColor Gray
Write-Host "  - Some applications may require RDS compatibility - test thoroughly" -ForegroundColor Gray
Write-Host ""

Write-Host "Configuration completed successfully!" -ForegroundColor Green
Write-Host ""

### End Script ###

