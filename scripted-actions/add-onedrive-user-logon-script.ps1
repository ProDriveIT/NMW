#description: Adds user logon script to OneDrive GPO for post-profile-load configuration
#tags: GPO, OneDrive, User Logon Script

<#
.SYNOPSIS
    Adds the OneDrive user logon script to an existing OneDrive GPO.

.DESCRIPTION
    This script adds configure-onedrive-user-logon.ps1 as a user logon script to the
    existing "AVD - OneDrive & SharePoint Settings" GPO.
    
    The user logon script runs AFTER FSLogix profile load and:
    - Sets Timerautomount registry value (fixes SharePoint sync)
    - Ensures OneDrive starts properly
    - Does NOT interfere with profile loading

.PARAMETER GPOName
    Name of the GPO. Default: "AVD - OneDrive & SharePoint Settings"

.PARAMETER ScriptPath
    Path to configure-onedrive-user-logon.ps1 script. If not provided, searches common locations.

.NOTES
    - Requires Group Policy Management Console (GPMC) cmdlets
    - Must be run on a Domain Controller or machine with RSAT installed
    - Requires Domain Admin or GPO modification permissions
#>

[CmdletBinding()]
param(
    [string]$GPOName = "AVD - OneDrive & SharePoint Settings",
    [string]$ScriptPath = ""
)

# Import GroupPolicy module
try {
    Import-Module GroupPolicy -ErrorAction Stop
} catch {
    Write-Error "Failed to import GroupPolicy module. Install RSAT: Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0"
    exit 1
}

Write-Host "Adding OneDrive user logon script to GPO..." -ForegroundColor Cyan
Write-Host "=" * 60

# Find the GPO
try {
    $gpo = Get-GPO -Name $GPOName -ErrorAction Stop
    Write-Host "Found GPO: $GPOName (ID: $($gpo.Id))" -ForegroundColor Green
} catch {
    Write-Error "GPO '$GPOName' not found. Create it first using create-onedrive-gpo.ps1"
    exit 1
}

# Find the user logon script
if ([string]::IsNullOrEmpty($ScriptPath)) {
    $scriptName = "configure-onedrive-user-logon.ps1"
    
    # Search common locations
    $searchPaths = @(
        ".\windows-scripts\$scriptName",
        ".\scripted-actions\windows-scripts\$scriptName",
        "\\$env:USERDOMAIN\NETLOGON\$scriptName",
        "$PSScriptRoot\$scriptName",
        "$PSScriptRoot\windows-scripts\$scriptName"
    )
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $ScriptPath = (Resolve-Path $path).Path
            Write-Host "Found script at: $ScriptPath" -ForegroundColor Green
            break
        }
    }
    
    if ([string]::IsNullOrEmpty($ScriptPath)) {
        Write-Error "Script not found. Please specify -ScriptPath parameter or place script in one of these locations:"
        $searchPaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        exit 1
    }
} else {
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Script not found at: $ScriptPath"
        exit 1
    }
    $ScriptPath = (Resolve-Path $ScriptPath).Path
}

# Get GPO domain and SYSVOL path
$domain = (Get-ADDomain).DNSRoot
$gpoSysvolPath = "\\$domain\SYSVOL\$domain\Policies\{$($gpo.Id)}\User\Scripts\Logon"

# Create logon scripts directory if it doesn't exist
if (-not (Test-Path $gpoSysvolPath)) {
    Write-Host "Creating logon scripts directory..." -ForegroundColor Yellow
    New-Item -Path $gpoSysvolPath -ItemType Directory -Force | Out-Null
}

# Copy script to GPO folder
$scriptFileName = Split-Path -Leaf $ScriptPath
$gpoScriptPath = Join-Path $gpoSysvolPath $scriptFileName

Write-Host "Copying script to GPO folder..." -ForegroundColor Yellow
Copy-Item -Path $ScriptPath -Destination $gpoScriptPath -Force
Write-Host "Script copied to: $gpoScriptPath" -ForegroundColor Green

# Create/update scripts.ini file for user logon scripts
$scriptsIniPath = Join-Path $gpoSysvolPath "scripts.ini"

try {
    # Read existing scripts.ini if it exists
    $scriptsIniContent = @()
    if (Test-Path $scriptsIniPath) {
        $scriptsIniContent = Get-Content $scriptsIniPath
    }
    
    # Check if script is already registered
    $scriptRegistered = $scriptsIniContent | Where-Object { $_ -match "^\d+CmdLine=.*$scriptFileName" }
    
    if (-not $scriptRegistered) {
        # Find next script number
        $scriptNumbers = $scriptsIniContent | Where-Object { $_ -match "^\d+CmdLine=" } | ForEach-Object {
            if ($_ -match "^(\d+)CmdLine=") { [int]$matches[1] }
        }
        $nextScriptNumber = if ($scriptNumbers) { ($scriptNumbers | Measure-Object -Maximum).Maximum + 1 } else { 0 }
        
        # User logon scripts.ini format:
        # [Logon]
        # 0CmdLine=scriptname.ps1
        # 0Parameters=
        if ($scriptsIniContent -notmatch "\[Logon\]") {
            $scriptsIniContent += "[Logon]"
        }
        $scriptsIniContent += "$nextScriptNumber`CmdLine=$scriptFileName"
        $scriptsIniContent += "$nextScriptNumber`Parameters="
        
        # Write scripts.ini
        $scriptsIniContent | Set-Content -Path $scriptsIniPath -Encoding ASCII -Force
        Write-Host "User logon script registered in scripts.ini" -ForegroundColor Green
        Write-Host "Script will appear in 'Logon' tab in GPO Editor (User Configuration)" -ForegroundColor Gray
    } else {
        Write-Host "User logon script already registered in scripts.ini" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Failed to create scripts.ini: $_"
    Write-Host "You may need to configure the logon script manually in GPO Editor:" -ForegroundColor Yellow
    Write-Host "  User Configuration > Policies > Windows Settings > Scripts > Logon" -ForegroundColor Gray
    Write-Host "  Click 'Add...' button and select: $gpoScriptPath" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=" * 60
Write-Host "User Logon Script Added Successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  GPO: $GPOName" -ForegroundColor Gray
Write-Host "  Script: $scriptFileName" -ForegroundColor Gray
Write-Host "  Location: $gpoScriptPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Verify script appears in GPO Editor:" -ForegroundColor Gray
Write-Host "     User Configuration > Policies > Windows Settings > Scripts > Logon" -ForegroundColor Gray
Write-Host "  2. Run 'gpupdate /force' on target machines" -ForegroundColor Gray
Write-Host "  3. Have users log out and log back in to test" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: This script runs AFTER FSLogix profile load, so it won't cause login hangs." -ForegroundColor Cyan

### End Script ###

