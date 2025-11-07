#description: Enables automatic MDM enrollment using default Azure AD credentials for Intune management
#tags: Nerdio, AVD, Intune, MDM, Azure AD

<#
.SYNOPSIS
    Enables automatic MDM enrollment for devices to automatically enroll in Microsoft Intune.

.DESCRIPTION
    This script configures Windows to automatically enroll devices into Microsoft Intune (MDM) when they are
    Azure AD joined or hybrid Azure AD joined. This is essential for receiving Intune configuration profiles,
    such as OneDrive auto-signin and SharePoint library sync policies.
    
    Features:
    - Enables automatic MDM enrollment using device credentials
    - Configures Azure AD Workplace Join (if needed)
    - Works for Azure AD joined and hybrid Azure AD joined devices
    - Required for Intune configuration profiles to apply to AVD session hosts
    
    Workflow:
    1. Domain join the VM (or Azure AD join)
    2. Enable MDM enrollment (this script)
    3. Device automatically enrolls in Intune
    4. Device receives Intune configuration profiles
    5. OneDrive auto-signs in and SharePoint libraries sync (via Intune profile)
    
    This script should be run AFTER domain join (or as part of Azure AD join process).

.PARAMETER EnableWorkplaceJoin
    Allow Azure AD Workplace Join (default: $true). Set to $false if you only want full Azure AD Join.

.EXAMPLE
    .\enable-mdm-enrollment.ps1
    
.EXAMPLE
    .\enable-mdm-enrollment.ps1 -EnableWorkplaceJoin $false

.NOTES
    Requires:
    - Administrator privileges
    - Device must be Azure AD joined or hybrid Azure AD joined for MDM enrollment to work
    - Intune licenses and MDM enrollment configured in Azure AD
    
    Works with:
    - Azure AD joined devices (automatic enrollment)
    - Hybrid Azure AD joined devices (automatic enrollment)
    - Domain-joined devices (requires hybrid Azure AD join for MDM enrollment)
    
    Important:
    - For domain-joined devices, ensure hybrid Azure AD join is configured
    - MDM enrollment happens automatically after device restart/login
    - Intune configuration profiles will apply after successful enrollment
    - This works in conjunction with Intune profiles for OneDrive/SharePoint sync
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [bool]$EnableWorkplaceJoin = $true
)

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Enable MDM Enrollment for Intune" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuring automatic MDM enrollment..." -ForegroundColor Cyan
Write-Host ""

# Registry paths
$mdmPolicyPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\DeviceManagement"
$workplaceJoinPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$workplaceJoinRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows Settings\WorkPlaceJoin"

# Create registry paths if they don't exist
if (-not (Test-Path $mdmPolicyPath)) {
    New-Item -Path $mdmPolicyPath -Force | Out-Null
    Write-Host "Created registry path: $mdmPolicyPath" -ForegroundColor Gray
}

if (-not (Test-Path $workplaceJoinPath)) {
    New-Item -Path $workplaceJoinPath -Force | Out-Null
    Write-Host "Created registry path: $workplaceJoinPath" -ForegroundColor Gray
}

if (-not (Test-Path $workplaceJoinRegistryPath)) {
    New-Item -Path $workplaceJoinRegistryPath -Force | Out-Null
    Write-Host "Created registry path: $workplaceJoinRegistryPath" -ForegroundColor Gray
}

Write-Host ""

# 1. Enable automatic MDM enrollment using default Azure AD credentials
Write-Host "Setting: Enable automatic MDM enrollment" -ForegroundColor Yellow
try {
    # This is the Group Policy setting: "Enable automatic MDM enrollment using default Azure AD credentials"
    # Registry path for the policy
    $mdmEnrollmentPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM"
    if (-not (Test-Path $mdmEnrollmentPath)) {
        New-Item -Path $mdmEnrollmentPath -Force | Out-Null
    }
    
    # Enable automatic MDM enrollment
    # Value 1 = Enable with Device Credential (recommended for AVD)
    # Value 2 = Enable with User Credential
    New-ItemProperty -Path $mdmEnrollmentPath -Name "AutoEnrollMDM" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ AutoEnrollMDM = 1 (Enabled with Device Credential)" -ForegroundColor Green
    Write-Host "    Devices will automatically enroll in Intune when Azure AD joined or hybrid joined" -ForegroundColor Gray
}
catch {
    Write-Warning "  Failed to enable MDM enrollment: $_"
}

# 2. Configure credential type (Device Credential - recommended for AVD)
Write-Host "Setting: MDM enrollment credential type" -ForegroundColor Yellow
try {
    # 0 = Device Credential (recommended for AVD session hosts)
    # 1 = User Credential
    New-ItemProperty -Path $mdmEnrollmentPath -Name "UseAADCredentialType" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ UseAADCredentialType = 0 (Device Credential)" -ForegroundColor Green
    Write-Host "    Using device credentials for MDM enrollment (recommended for AVD)" -ForegroundColor Gray
}
catch {
    Write-Warning "  Failed to set credential type: $_"
}

# 3. Configure Azure AD Workplace Join (if enabled)
if ($EnableWorkplaceJoin) {
    Write-Host "Setting: Allow Azure AD Workplace Join" -ForegroundColor Yellow
    try {
        # BlockAADWorkplaceJoin = 0 means Workplace Join is allowed
        # BlockAADWorkplaceJoin = 1 means Workplace Join is blocked
        New-ItemProperty -Path $workplaceJoinRegistryPath -Name "BlockAADWorkplaceJoin" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        Write-Host "  ✓ BlockAADWorkplaceJoin = 0 (Workplace Join allowed)" -ForegroundColor Green
        Write-Host "    Note: For AVD session hosts, full Azure AD Join is typically used instead" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Failed to configure Workplace Join: $_"
    }
}
else {
    Write-Host "Setting: Block Azure AD Workplace Join" -ForegroundColor Yellow
    try {
        New-ItemProperty -Path $workplaceJoinRegistryPath -Name "BlockAADWorkplaceJoin" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        Write-Host "  ✓ BlockAADWorkplaceJoin = 1 (Workplace Join blocked)" -ForegroundColor Green
    }
    catch {
        Write-Warning "  Failed to block Workplace Join: $_"
    }
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Configuration Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "MDM Enrollment Configuration:" -ForegroundColor Green
Write-Host "  ✓ Automatic MDM enrollment: Enabled" -ForegroundColor Green
Write-Host "  ✓ Credential type: Device Credential" -ForegroundColor Green
Write-Host "  ✓ Workplace Join: $(if ($EnableWorkplaceJoin) { 'Allowed' } else { 'Blocked' })" -ForegroundColor Green
Write-Host ""

Write-Host "Enrollment Workflow:" -ForegroundColor Cyan
Write-Host "  1. Device is domain-joined (or Azure AD joined)" -ForegroundColor Gray
Write-Host "  2. MDM enrollment is enabled (this script)" -ForegroundColor Gray
Write-Host "  3. Device automatically enrolls in Intune on next login/restart" -ForegroundColor Gray
Write-Host "  4. Device receives Intune configuration profiles" -ForegroundColor Gray
Write-Host "  5. OneDrive auto-signs in and SharePoint libraries sync (via Intune profile)" -ForegroundColor Gray
Write-Host ""

Write-Host "Important Notes:" -ForegroundColor Yellow
Write-Host "  - For domain-joined devices: Ensure hybrid Azure AD join is configured" -ForegroundColor Gray
Write-Host "  - MDM enrollment happens automatically after device restart or user login" -ForegroundColor Gray
Write-Host "  - Intune configuration profiles will apply after successful enrollment" -ForegroundColor Gray
Write-Host "  - Enrollment status can be checked in Azure Portal > Intune > Devices" -ForegroundColor Gray
Write-Host ""

Write-Host "Verification:" -ForegroundColor Cyan
Write-Host "  - Check enrollment: Azure Portal > Microsoft Intune > Devices" -ForegroundColor Gray
Write-Host "  - Verify Intune profile assignment: Devices > Configuration profiles" -ForegroundColor Gray
Write-Host "  - Check OneDrive sign-in: Users should be automatically signed in" -ForegroundColor Gray
Write-Host "  - Verify SharePoint sync: Libraries should sync automatically" -ForegroundColor Gray
Write-Host ""

Write-Host "Configuration completed successfully!" -ForegroundColor Green
Write-Host "Device will enroll in Intune on next restart or login." -ForegroundColor Green
Write-Host ""

### End Script ###

