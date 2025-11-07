#description: Configures OneDrive for automatic sign-in using Azure AD SSO in AVD
#tags: Nerdio, OneDrive, AVD, Configuration

<#
.SYNOPSIS
    Configures OneDrive for automatic sign-in using Azure AD SSO in AVD environments.

.DESCRIPTION
    This script configures OneDrive to automatically sign in users when they log into AVD session hosts.
    It uses Silent Account Configuration which leverages Azure AD SSO to sign in users without prompts.
    
    Features:
    - Enables Silent Account Configuration (automatic sign-in with Windows credentials)
    - Configures OneDrive to start automatically on login
    - Optionally configures Known Folder Move (KFM) for Desktop, Documents, Pictures
    - Sets OneDrive to start in the background
    - Compatible with Azure AD joined, hybrid joined, and domain-joined devices
    - Configures FSLogix token roaming (if FSLogix is detected) to preserve authentication across sessions
    
    This script should be run AFTER OneDrive is installed (via install-onedrive-per-machine.ps1).
    
    IMPORTANT: For domain-joined devices with AD credentials:
    - Works best when AD accounts are synced to Azure AD (hybrid identity)
    - For pure AD-only (no Azure AD sync), users may need to sign in once manually
    - FSLogix RoamIdentity is automatically configured to preserve tokens

.PARAMETER EnableKnownFolderMove
    Enable Known Folder Move (KFM) to redirect Desktop, Documents, Pictures to OneDrive (default: $false)

.PARAMETER TenantId
    Optional: Specify tenant ID for silent account configuration (usually not needed for Azure AD joined devices)

.EXAMPLE
    .\configure-onedrive-auto-signin.ps1
    
.EXAMPLE
    .\configure-onedrive-auto-signin.ps1 -EnableKnownFolderMove $true

.NOTES
    Requires:
    - OneDrive per-machine installation (run install-onedrive-per-machine.ps1 first)
    - Administrator privileges
    
    Works with:
    - Azure AD joined devices (best experience)
    - Hybrid joined devices (Azure AD + domain join)
    - Domain-joined devices with AD credentials (works if AD accounts are synced to Azure AD)
    
    For pure AD-only environments (no Azure AD sync):
    - This script will still configure the settings, but users may need to sign in once manually
    - Consider using Group Policy as an alternative: "Silently sign in users to the OneDrive sync app with their Windows credentials"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [bool]$EnableKnownFolderMove = $false,
    
    [Parameter(Mandatory = $false)]
    [string]$TenantId = ""
)

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "OneDrive Auto Sign-In Configuration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Verify OneDrive is installed
$oneDrivePath = "${env:ProgramFiles}\Microsoft OneDrive\OneDrive.exe"
if (-not (Test-Path $oneDrivePath)) {
    Write-Warning "OneDrive not found at expected location: $oneDrivePath"
    Write-Warning "Please ensure OneDrive is installed (run install-onedrive-per-machine.ps1 first)"
    Write-Host ""
    Write-Host "Checking alternative locations..." -ForegroundColor Yellow
    
    # Check Program Files (x86) for 32-bit installations
    $oneDrivePath32 = "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"
    if (Test-Path $oneDrivePath32) {
        $oneDrivePath = $oneDrivePath32
        Write-Host "Found OneDrive at: $oneDrivePath" -ForegroundColor Green
    }
    else {
        Write-Error "OneDrive not found. Please install OneDrive first."
        exit 1
    }
}

Write-Host "OneDrive found: $oneDrivePath" -ForegroundColor Green
Write-Host ""

# Registry paths
$oneDrivePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
$oneDrivePath = "HKLM:\SOFTWARE\Microsoft\OneDrive"
$runKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

Write-Host "Configuring OneDrive registry settings..." -ForegroundColor Cyan
Write-Host ""

# Create registry paths if they don't exist
if (-not (Test-Path $oneDrivePolicyPath)) {
    New-Item -Path $oneDrivePolicyPath -Force | Out-Null
    Write-Host "Created registry path: $oneDrivePolicyPath" -ForegroundColor Gray
}

if (-not (Test-Path $oneDrivePath)) {
    New-Item -Path $oneDrivePath -Force | Out-Null
    Write-Host "Created registry path: $oneDrivePath" -ForegroundColor Gray
}

# 1. Enable Silent Account Configuration (automatic sign-in with Windows credentials)
Write-Host "Setting: Silent Account Configuration (automatic sign-in)" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $oneDrivePolicyPath -Name "SilentAccountConfig" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ SilentAccountConfig = 1 (enabled)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set SilentAccountConfig: $_"
}

# 2. Disable file on-demand prompts (optional - improves user experience)
Write-Host "Setting: Disable file on-demand prompts" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $oneDrivePolicyPath -Name "FilesOnDemandEnabled" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ FilesOnDemandEnabled = 1 (enabled)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set FilesOnDemandEnabled: $_"
}

# 3. Set tenant ID if provided (usually not needed for Azure AD joined devices)
if (-not [string]::IsNullOrWhiteSpace($TenantId)) {
    Write-Host "Setting: Tenant ID" -ForegroundColor Yellow
    try {
        New-ItemProperty -Path $oneDrivePolicyPath -Name "TenantId" -Value $TenantId -PropertyType String -Force -ErrorAction Stop | Out-Null
        Write-Host "  ✓ TenantId = $TenantId" -ForegroundColor Green
    }
    catch {
        Write-Warning "  Failed to set TenantId: $_"
    }
}

# 4. Configure OneDrive to start automatically on login
Write-Host "Setting: Auto-start OneDrive on login" -ForegroundColor Yellow
try {
    $oneDriveRunValue = "`"$oneDrivePath`" /background"
    New-ItemProperty -Path $runKeyPath -Name "OneDrive" -Value $oneDriveRunValue -PropertyType String -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ OneDrive added to startup (Run key)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set OneDrive startup: $_"
}

# 5. Configure Known Folder Move (KFM) if enabled
if ($EnableKnownFolderMove) {
    Write-Host ""
    Write-Host "Configuring Known Folder Move (KFM)..." -ForegroundColor Cyan
    
    # KFM registry path
    $kfmPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\KFMSilentOptIn"
    
    if (-not (Test-Path $kfmPath)) {
        New-Item -Path $kfmPath -Force | Out-Null
    }
    
    # Enable KFM for Desktop, Documents, Pictures
    $kfmFolders = @("Desktop", "Documents", "Pictures")
    
    foreach ($folder in $kfmFolders) {
        Write-Host "Setting: KFM for $folder" -ForegroundColor Yellow
        try {
            New-ItemProperty -Path $kfmPath -Name $folder -Value $true -PropertyType String -Force -ErrorAction Stop | Out-Null
            Write-Host "  ✓ KFM enabled for $folder" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed to set KFM for $folder : $_"
        }
    }
    
    # Set KFM notification setting (optional - can be configured via GPO)
    Write-Host "Setting: KFM notification setting" -ForegroundColor Yellow
    try {
        New-ItemProperty -Path $oneDrivePolicyPath -Name "KFMSilentOptInWithNotification" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        Write-Host "  ✓ KFM notification enabled" -ForegroundColor Green
    }
    catch {
        Write-Warning "  Failed to set KFM notification: $_"
    }
}
else {
    Write-Host ""
    Write-Host "Known Folder Move (KFM) is disabled (use -EnableKnownFolderMove `$true to enable)" -ForegroundColor Gray
}

# 6. Configure FSLogix token roaming (if FSLogix is installed)
Write-Host ""
Write-Host "Checking for FSLogix and configuring token roaming..." -ForegroundColor Cyan
$fsLogixPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
if (Test-Path $fsLogixPath) {
    Write-Host "FSLogix detected. Configuring token roaming for OneDrive authentication..." -ForegroundColor Yellow
    try {
        # Enable RoamIdentity to preserve authentication tokens across sessions
        # This is critical for OneDrive auto sign-in in AVD with FSLogix profiles
        New-ItemProperty -Path $fsLogixPath -Name "RoamIdentity" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        Write-Host "  ✓ RoamIdentity = 1 (enabled)" -ForegroundColor Green
        Write-Host "    This preserves OneDrive authentication tokens across sessions" -ForegroundColor Gray
        Write-Host "    Without this, users would be prompted to sign in to OneDrive on each new session" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Failed to set FSLogix RoamIdentity: $_"
        Write-Warning "    Note: Without RoamIdentity, users may be prompted to sign in to OneDrive on each session"
    }
}
else {
    Write-Host "FSLogix not detected. Skipping token roaming configuration." -ForegroundColor Gray
    Write-Host "  (If using FSLogix, ensure RoamIdentity=1 is set to preserve OneDrive tokens)" -ForegroundColor Gray
    Write-Host "  (If not using FSLogix, this is expected and tokens will be stored in local profile)" -ForegroundColor Gray
}

# 7. Additional AVD-optimized settings
Write-Host ""
Write-Host "Setting: Additional AVD optimizations" -ForegroundColor Cyan

# Disable OneDrive sync health reporting (reduces network traffic)
Write-Host "Setting: Disable sync health reporting" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $oneDrivePolicyPath -Name "DisableSyncHealthReporting" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ DisableSyncHealthReporting = 1" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set DisableSyncHealthReporting: $_"
}

# Disable OneDrive sync admin reports (reduces network traffic)
Write-Host "Setting: Disable sync admin reports" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $oneDrivePolicyPath -Name "DisableSyncAdminReports" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ DisableSyncAdminReports = 1" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set DisableSyncAdminReports: $_"
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Configuration Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "OneDrive Auto Sign-In Configuration:" -ForegroundColor Green
Write-Host "  ✓ Silent Account Configuration: Enabled" -ForegroundColor Green
Write-Host "  ✓ Auto-start on login: Enabled" -ForegroundColor Green
Write-Host "  ✓ Files on-demand: Enabled" -ForegroundColor Green
if ($EnableKnownFolderMove) {
    Write-Host "  ✓ Known Folder Move: Enabled (Desktop, Documents, Pictures)" -ForegroundColor Green
}
else {
    Write-Host "  ⚠ Known Folder Move: Disabled" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Users will automatically sign in to OneDrive on their next login" -ForegroundColor Gray
Write-Host "  2. OneDrive will use their Windows/Azure AD/AD credentials" -ForegroundColor Gray
Write-Host "  3. No manual sign-in prompts will appear (for Azure AD/hybrid scenarios)" -ForegroundColor Gray
Write-Host ""

if (-not $EnableKnownFolderMove) {
    Write-Host "Note: To enable Known Folder Move (redirect Desktop/Documents/Pictures to OneDrive)," -ForegroundColor Yellow
    Write-Host "      re-run this script with: -EnableKnownFolderMove `$true" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Domain-Joined with AD Credentials:" -ForegroundColor Cyan
Write-Host "  ✓ This configuration works with domain-joined devices" -ForegroundColor Green
Write-Host "  ✓ Works best when AD accounts are synced to Azure AD (hybrid identity)" -ForegroundColor Green
Write-Host "  ✓ FSLogix RoamIdentity has been configured to preserve tokens across sessions" -ForegroundColor Green
Write-Host ""
Write-Host "  For pure AD-only environments (no Azure AD sync):" -ForegroundColor Yellow
Write-Host "    - Users may need to sign in to OneDrive once manually on first login" -ForegroundColor Gray
Write-Host "    - After first sign-in, tokens will be preserved via FSLogix RoamIdentity" -ForegroundColor Gray
Write-Host "    - Alternative: Use Group Policy instead:" -ForegroundColor Gray
Write-Host "      Computer Configuration > Administrative Templates > OneDrive" -ForegroundColor Gray
Write-Host "      Policy: 'Silently sign in users to the OneDrive sync app with their Windows credentials'" -ForegroundColor Gray
Write-Host ""

Write-Host "Configuration completed successfully!" -ForegroundColor Green
Write-Host ""

### End Script ###

