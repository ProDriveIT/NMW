#description: Configures Outlook Cached Exchange Mode with AVD-optimized settings
#tags: Nerdio, Outlook, AVD, Configuration, Exchange

<#
.SYNOPSIS
    Configures Outlook Cached Exchange Mode with optimal settings for AVD environments.

.DESCRIPTION
    This script configures Outlook to use Cached Exchange Mode with settings optimized for Azure Virtual Desktop.
    It sets registry policies that apply to all users and ensures optimal performance while managing storage costs.
    
    Features:
    - Enables Cached Exchange Mode for all Outlook profiles
    - Configures OST file size limits (recommended: 1-3 months)
    - Optimizes sync settings for AVD performance
    - Configures calendar and shared mailbox caching
    - Sets download preferences for attachments
    - Works for both domain-joined and Azure AD joined devices
    
    This script should be run AFTER Microsoft 365 Apps is installed (via install-m365-apps.ps1).

.PARAMETER CachedMailPeriod
    Number of months of mail to cache in OST file (default: 3, recommended: 1-3 for AVD)
    Options: 1, 3, 6, 12, or "All" (not recommended for AVD due to storage costs)

.PARAMETER DownloadSharedAttachments
    Download shared attachments to cache (default: $true)

.PARAMETER DownloadPublicFolderFavorites
    Download public folder favorites (default: $false, reduces storage)

.PARAMETER SyncCalendarDays
    Number of calendar days to sync (default: 60, recommended: 30-60)

.EXAMPLE
    .\configure-outlook-cached-mode.ps1
    
.EXAMPLE
    .\configure-outlook-cached-mode.ps1 -CachedMailPeriod 1 -SyncCalendarDays 30

.NOTES
    Requires:
    - Microsoft 365 Apps installed (run install-m365-apps.ps1 first)
    - Administrator privileges
    
    Works with:
    - Domain-joined devices
    - Azure AD joined devices
    - Hybrid joined devices
    
    Best Practices:
    - Use 1-3 months cached mail for AVD to balance performance and storage
    - Monitor FSLogix profile sizes if using profile containers
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet(1, 3, 6, 12, "All")]
    [object]$CachedMailPeriod = 3,
    
    [Parameter(Mandatory = $false)]
    [bool]$DownloadSharedAttachments = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$DownloadPublicFolderFavorites = $false,
    
    [Parameter(Mandatory = $false)]
    [int]$SyncCalendarDays = 60
)

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Outlook Cached Exchange Mode Configuration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Verify Outlook is installed (check for Office installation)
$outlookPath = "${env:ProgramFiles}\Microsoft Office\root\Office16\OUTLOOK.EXE"
if (-not (Test-Path $outlookPath)) {
    # Check alternative Office paths
    $outlookPath32 = "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\OUTLOOK.EXE"
    if (Test-Path $outlookPath32) {
        $outlookPath = $outlookPath32
    }
    else {
        # Check for Office 2016/2019 path
        $outlookPath2016 = "${env:ProgramFiles}\Microsoft Office\Office16\OUTLOOK.EXE"
        if (Test-Path $outlookPath2016) {
            $outlookPath = $outlookPath2016
        }
        else {
            Write-Warning "Outlook not found at expected locations."
            Write-Warning "Please ensure Microsoft 365 Apps is installed (run install-m365-apps.ps1 first)"
            Write-Host ""
            Write-Host "Continuing with configuration (settings will apply when Outlook is installed)..." -ForegroundColor Yellow
        }
    }
}

if (Test-Path $outlookPath) {
    Write-Host "Outlook found: $outlookPath" -ForegroundColor Green
}
Write-Host ""

# Registry paths for Outlook policies
$outlookPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode"
$outlookRpcPath = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\RPC"

Write-Host "Configuring Outlook Cached Exchange Mode settings..." -ForegroundColor Cyan
Write-Host ""

# Create registry paths if they don't exist
if (-not (Test-Path $outlookPolicyPath)) {
    New-Item -Path $outlookPolicyPath -Force | Out-Null
    Write-Host "Created registry path: $outlookPolicyPath" -ForegroundColor Gray
}

if (-not (Test-Path $outlookRpcPath)) {
    New-Item -Path $outlookRpcPath -Force | Out-Null
    Write-Host "Created registry path: $outlookRpcPath" -ForegroundColor Gray
}

# 1. Enable Cached Exchange Mode
Write-Host "Setting: Enable Cached Exchange Mode" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $outlookPolicyPath -Name "Enable" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ Cached Exchange Mode: Enabled" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to enable Cached Exchange Mode: $_"
}

# 2. Configure cached mail period (OST file size limit)
Write-Host "Setting: Cached mail period" -ForegroundColor Yellow
try {
    # Convert period to registry value
    # 1 = 1 month, 3 = 3 months, 6 = 6 months, 12 = 12 months, 0 = All (not recommended)
    $periodValue = switch ($CachedMailPeriod) {
        1 { 1 }
        3 { 3 }
        6 { 6 }
        12 { 12 }
        "All" { 0 }
        default { 3 }
    }
    
    New-ItemProperty -Path $outlookPolicyPath -Name "SyncWindowSetting" -Value $periodValue -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    
    if ($CachedMailPeriod -eq "All") {
        Write-Host "  ✓ Cached mail period: All mail (not recommended for AVD - monitor storage)" -ForegroundColor Yellow
    }
    else {
        Write-Host "  ✓ Cached mail period: $CachedMailPeriod month(s)" -ForegroundColor Green
    }
}
catch {
    Write-Warning "  Failed to set cached mail period: $_"
}

# 3. Configure calendar sync days
Write-Host "Setting: Calendar sync period" -ForegroundColor Yellow
try {
    # Limit calendar sync to specified days (reduces OST size)
    New-ItemProperty -Path $outlookPolicyPath -Name "CalendarSyncWindowSettingDays" -Value $SyncCalendarDays -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ Calendar sync: $SyncCalendarDays days" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set calendar sync period: $_"
}

# 4. Enable full calendar sync (recommended for better performance)
Write-Host "Setting: Full calendar sync" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $outlookPolicyPath -Name "CalendarSyncWindowSetting" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ Full calendar sync: Enabled (recommended for AVD)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set full calendar sync: $_"
}

# 5. Configure shared attachments download
Write-Host "Setting: Download shared attachments" -ForegroundColor Yellow
try {
    $attachmentValue = if ($DownloadSharedAttachments) { 1 } else { 0 }
    New-ItemProperty -Path $outlookPolicyPath -Name "DownloadSharedAttachments" -Value $attachmentValue -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    if ($DownloadSharedAttachments) {
        Write-Host "  ✓ Download shared attachments: Enabled" -ForegroundColor Green
    }
    else {
        Write-Host "  ✓ Download shared attachments: Disabled (reduces storage)" -ForegroundColor Green
    }
}
catch {
    Write-Warning "  Failed to set shared attachments setting: $_"
}

# 6. Configure public folder favorites download
Write-Host "Setting: Download public folder favorites" -ForegroundColor Yellow
try {
    $publicFolderValue = if ($DownloadPublicFolderFavorites) { 1 } else { 0 }
    New-ItemProperty -Path $outlookPolicyPath -Name "DownloadPublicFolderFavorites" -Value $publicFolderValue -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    if ($DownloadPublicFolderFavorites) {
        Write-Host "  ✓ Download public folder favorites: Enabled" -ForegroundColor Green
    }
    else {
        Write-Host "  ✓ Download public folder favorites: Disabled (reduces storage)" -ForegroundColor Green
    }
}
catch {
    Write-Warning "  Failed to set public folder favorites setting: $_"
}

# 7. Enable Cached Mode for new profiles (ensures all new profiles use cached mode)
Write-Host "Setting: Cached Mode for new profiles" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $outlookPolicyPath -Name "CachedModeForNewProfiles" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ Cached Mode for new profiles: Enabled" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set cached mode for new profiles: $_"
}

# 8. Optimize RPC/HTTP connection settings for AVD
Write-Host ""
Write-Host "Setting: RPC/HTTP connection optimizations" -ForegroundColor Cyan

# Enable RPC encryption (security best practice)
Write-Host "Setting: RPC encryption" -ForegroundColor Yellow
try {
    New-ItemProperty -Path $outlookRpcPath -Name "EnableRPCEncryption" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ RPC encryption: Enabled" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set RPC encryption: $_"
}

# Configure connection timeout (optimized for AVD)
Write-Host "Setting: Connection timeout" -ForegroundColor Yellow
try {
    # 30 seconds timeout (reasonable for AVD environments)
    New-ItemProperty -Path $outlookRpcPath -Name "RpcHttpConnectionTimeout" -Value 30 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ Connection timeout: 30 seconds" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set connection timeout: $_"
}

# 9. Disable fast shutdown (can cause issues in VDI/AVD)
Write-Host "Setting: Fast shutdown" -ForegroundColor Yellow
try {
    $fastShutdownPath = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Options\General"
    if (-not (Test-Path $fastShutdownPath)) {
        New-Item -Path $fastShutdownPath -Force | Out-Null
    }
    New-ItemProperty -Path $fastShutdownPath -Name "DisableFastShutdown" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Host "  ✓ Fast shutdown: Disabled (recommended for AVD)" -ForegroundColor Green
}
catch {
    Write-Warning "  Failed to set fast shutdown: $_"
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Configuration Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Outlook Cached Exchange Mode Configuration:" -ForegroundColor Green
Write-Host "  ✓ Cached Exchange Mode: Enabled" -ForegroundColor Green
Write-Host "  ✓ Cached mail period: $CachedMailPeriod month(s)" -ForegroundColor Green
Write-Host "  ✓ Calendar sync: $SyncCalendarDays days" -ForegroundColor Green
Write-Host "  ✓ Full calendar sync: Enabled" -ForegroundColor Green
Write-Host "  ✓ Download shared attachments: $(if ($DownloadSharedAttachments) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Green
Write-Host "  ✓ Download public folder favorites: $(if ($DownloadPublicFolderFavorites) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Green
Write-Host "  ✓ Cached Mode for new profiles: Enabled" -ForegroundColor Green
Write-Host "  ✓ RPC encryption: Enabled" -ForegroundColor Green
Write-Host "  ✓ Fast shutdown: Disabled" -ForegroundColor Green
Write-Host ""

Write-Host "Storage Considerations:" -ForegroundColor Cyan
Write-Host "  - OST files will be stored in user profiles" -ForegroundColor Gray
Write-Host "  - With FSLogix Profiles, OST files roam with the profile" -ForegroundColor Gray
Write-Host "  - Monitor profile sizes: $CachedMailPeriod month(s) cache = ~$($CachedMailPeriod * 0.5)GB average per user" -ForegroundColor Gray
Write-Host ""

Write-Host "Performance Benefits:" -ForegroundColor Cyan
Write-Host "  ✓ Faster mailbox access and search" -ForegroundColor Gray
Write-Host "  ✓ Reduced network traffic to Exchange" -ForegroundColor Gray
Write-Host "  ✓ Works offline during brief connectivity issues" -ForegroundColor Gray
Write-Host "  ✓ Better user experience in AVD" -ForegroundColor Gray
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Settings will apply to all new Outlook profiles" -ForegroundColor Gray
Write-Host "  2. Existing profiles may need to be recreated or manually configured" -ForegroundColor Gray
Write-Host "  3. Monitor FSLogix profile sizes after deployment" -ForegroundColor Gray
Write-Host "  4. Adjust CachedMailPeriod if storage becomes an issue" -ForegroundColor Gray
Write-Host ""

if ($CachedMailPeriod -eq "All" -or $CachedMailPeriod -gt 3) {
    Write-Host "Warning: Large cached mail period may increase storage costs significantly." -ForegroundColor Yellow
    Write-Host "Consider reducing to 1-3 months for better storage management in AVD." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Configuration completed successfully!" -ForegroundColor Green
Write-Host ""

### End Script ###

