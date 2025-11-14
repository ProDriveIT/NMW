#description: Configures OneDrive and SharePoint settings via registry (GPO equivalent)
#tags: Nerdio, OneDrive, SharePoint, GPO, Registry

<#
.SYNOPSIS
    Configures OneDrive and SharePoint settings via registry to match Intune Configuration Policy.
    This script sets the equivalent registry values that would be set by a GPO.

.DESCRIPTION
    This script configures the following OneDrive settings:
    1. Auto-mount Team Sites (enabled)
    2. Dehydrate synced Team Sites (enabled)
    3. KFM opt-in without wizard (enabled) with tenant ID
    4. Silent account configuration (enabled)
    5. Files On Demand enabled (enabled)

    These settings match the Intune Configuration Policy:
    "CA - CONFIG - AVD - OneDrive & Sharepoint"

.NOTES
    - Requires administrative privileges
    - Settings are applied to HKLM (Computer Configuration)
    - Tenant ID: 2106f27c-fb2e-4787-b960-3dc6aac54826 (Cheesman)
    - Can be deployed as a GPO startup script or registry preference

.AUTHOR
    Converted from Intune Configuration Policy
#>

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# ============================================================================
# CONFIGURATION: Tenant ID
# ============================================================================
# MODIFY THIS VALUE FOR EACH CLIENT
# Get tenant ID from: Azure Portal > Azure Active Directory > Overview > Tenant ID
# ============================================================================
$tenantId = "2106f27c-fb2e-4787-b960-3dc6aac54826"  # Cheesman Tenant - CHANGE THIS FOR OTHER CLIENTS
# ============================================================================

# Base registry path for OneDrive policies
$oneDrivePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
$kfmPath = "$oneDrivePolicyPath\KFMSilentOptIn"

# Function to set registry value
function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord"
    )
    
    try {
        # Create path if it doesn't exist
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-Host "Created registry path: $Path"
        }
        
        # Set the value
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Host "Set $Path\$Name = $Value ($Type)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to set $Path\$Name : $_"
    }
}

Write-Host "Configuring OneDrive and SharePoint settings..." -ForegroundColor Cyan
Write-Host "=" * 60

# 1. Auto-mount Team Sites (DISABLED BY DEFAULT - can cause FSLogix login hangs)
# Registry: HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\AutoMountTeamSites
# Value: 1 = Enabled
# WARNING: Enabling this can cause FSLogix profile load to hang if user has many SharePoint sites
#          or if there are network/connectivity issues during login.
#          Users can manually sync SharePoint sites after login instead.
# This will auto-mount all SharePoint/Teams sites the user has access to (permissions are enforced)
# Write-Host "`n1. Configuring Auto-mount Team Sites..." -ForegroundColor Yellow
# Set-RegistryValue -Path $oneDrivePolicyPath -Name "AutoMountTeamSites" -Value 1 -Type "DWord"
# Write-Host "   All SharePoint sites the user has access to will be auto-mounted" -ForegroundColor Gray
Write-Host "`n1. Auto-mount Team Sites: DISABLED (to prevent FSLogix login hangs)" -ForegroundColor Yellow
Write-Host "   Users can manually sync SharePoint sites after login" -ForegroundColor Gray

# 2. Dehydrate synced Team Sites (enabled)
# Registry: HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\DehydrateSyncedTeamSites
# Value: 1 = Enabled
Write-Host "`n2. Configuring Dehydrate synced Team Sites..." -ForegroundColor Yellow
Set-RegistryValue -Path $oneDrivePolicyPath -Name "DehydrateSyncedTeamSites" -Value 1 -Type "DWord"

# 3. KFM opt-in without wizard (enabled) with tenant ID
# Registry: HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\KFMSilentOptIn
# Values: 
#   - TenantId = tenant ID (String)
#   - KFMOptInWithWizard = 0 (DWord) - 0 = Silent opt-in, 1 = Show wizard
Write-Host "`n3. Configuring KFM opt-in without wizard..." -ForegroundColor Yellow
Set-RegistryValue -Path $kfmPath -Name "TenantId" -Value $tenantId -Type "String"
Set-RegistryValue -Path $kfmPath -Name "KFMOptInWithWizard" -Value 0 -Type "DWord"

# Note: The JSON shows dropdown value 0, which typically means "Silent opt-in" (no wizard)
# Setting KFMOptInWithWizard = 0 enables silent opt-in

# 4. Silent account configuration (enabled)
# Registry: HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\SilentAccountConfig
# Value: 1 = Enabled
Write-Host "`n4. Configuring Silent account configuration..." -ForegroundColor Yellow
Set-RegistryValue -Path $oneDrivePolicyPath -Name "SilentAccountConfig" -Value 1 -Type "DWord"

# 5. Files On Demand enabled (enabled)
# Registry: HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\FilesOnDemandEnabled
# Value: 1 = Enabled
Write-Host "`n5. Configuring Files On Demand..." -ForegroundColor Yellow
Set-RegistryValue -Path $oneDrivePolicyPath -Name "FilesOnDemandEnabled" -Value 1 -Type "DWord"

Write-Host "`n" + ("=" * 60)
Write-Host "OneDrive and SharePoint settings configured successfully!" -ForegroundColor Green
Write-Host "`nSettings Summary:" -ForegroundColor Cyan
Write-Host "  - Auto-mount Team Sites: DISABLED (prevents FSLogix login hangs)"
Write-Host "  - Dehydrate synced Team Sites: Enabled"
Write-Host "  - KFM opt-in without wizard: Enabled (Tenant: $tenantId)"
Write-Host "  - Silent account configuration: Enabled"
Write-Host "  - Files On Demand: Enabled"
Write-Host "`nNote: These settings will take effect after OneDrive restart or user logon." -ForegroundColor Gray
Write-Host "`nWARNING: AutoMountTeamSites is disabled to prevent FSLogix profile load hangs." -ForegroundColor Yellow
Write-Host "         If you need auto-mount, enable it but be aware it may cause login delays." -ForegroundColor Yellow

### End Script ###

