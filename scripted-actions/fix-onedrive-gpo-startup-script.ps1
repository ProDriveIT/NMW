#description: Fixes startup script registration for existing OneDrive GPO
#tags: GPO, Fix, Startup Script

<#
.SYNOPSIS
    Registers the startup script in an existing OneDrive GPO by creating scripts.ini file.

.DESCRIPTION
    This script fixes the startup script registration for the "AVD - OneDrive & SharePoint Settings" GPO
    by creating the scripts.ini file that tells Group Policy which scripts to run.

.PARAMETER GPOName
    Name of the GPO to fix. Default: "AVD - OneDrive & SharePoint Settings"

.NOTES
    - Requires Domain Admin or GPO modification permissions
    - Must be run on Domain Controller or machine with access to SYSVOL

.EXAMPLE
    .\fix-onedrive-gpo-startup-script.ps1
#>

[CmdletBinding()]
param(
    [string]$GPOName = "AVD - OneDrive & SharePoint Settings"
)

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# Check if Group Policy module is available
try {
    Import-Module GroupPolicy -ErrorAction Stop
} catch {
    Write-Error "Group Policy module not found. Please install RSAT (Remote Server Administration Tools) or run this on a Domain Controller."
    exit 1
}

# Get GPO
$gpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if (-not $gpo) {
    Write-Error "GPO '$GPOName' not found."
    exit 1
}

Write-Host "Fixing startup script registration for GPO: $GPOName" -ForegroundColor Cyan
Write-Host "GPO ID: $($gpo.Id)" -ForegroundColor Gray
Write-Host "=" * 60

# Get GPO path
$gpoPath = "\\$($env:USERDNSDOMAIN)\SYSVOL\$($env:USERDNSDOMAIN)\Policies\{$($gpo.Id)}\Machine\Scripts\Startup"
# PowerShell scripts use psscripts.ini, not scripts.ini
$scriptsIniPath = Join-Path $gpoPath "psscripts.ini"
$scriptFileName = "configure-onedrive-gpo-settings.ps1"
$gpoScriptPath = Join-Path $gpoPath $scriptFileName

# Check if script exists in GPO folder
if (-not (Test-Path $gpoScriptPath)) {
    Write-Warning "Script not found in GPO folder: $gpoScriptPath"
    Write-Host "Please copy configure-onedrive-gpo-settings.ps1 to: $gpoScriptPath" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nScript found: $gpoScriptPath" -ForegroundColor Green

# Create/update psscripts.ini file (PowerShell scripts use psscripts.ini)
Write-Host "`nCreating psscripts.ini file..." -ForegroundColor Yellow

try {
    # Read existing psscripts.ini if it exists
    $scriptsIniContent = @()
    if (Test-Path $scriptsIniPath) {
        $scriptsIniContent = Get-Content $scriptsIniPath
        Write-Host "Found existing psscripts.ini, checking for script registration..." -ForegroundColor Gray
    }
    
    # Check if script is already registered
    $scriptRegistered = $scriptsIniContent | Where-Object { $_ -match "^\d+Scripts=.*$scriptFileName" -or $_ -match "^\d+Parameters=" }
    
    if ($scriptRegistered) {
        Write-Host "Script is already registered in psscripts.ini" -ForegroundColor Green
        Write-Host "Current psscripts.ini content:" -ForegroundColor Gray
        $scriptsIniContent | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        # Find next script number (PowerShell scripts use different format)
        $scriptNumbers = $scriptsIniContent | Where-Object { $_ -match "^\[(\d+)\]" } | ForEach-Object {
            if ($_ -match "\[(\d+)\]") { [int]$matches[1] }
        }
        $nextScriptNumber = if ($scriptNumbers) { ($scriptNumbers | Measure-Object -Maximum).Maximum + 1 } else { 0 }
        
        # PowerShell scripts.ini format:
        # [0]
        # 0Scripts=scriptname.ps1
        # 0Parameters=
        # ExecutionPolicy=Bypass
        $scriptsIniContent += "[$nextScriptNumber]"
        $scriptsIniContent += "0Scripts=$scriptFileName"
        $scriptsIniContent += "0Parameters="
        $scriptsIniContent += "ExecutionPolicy=Bypass"
        
        # Write psscripts.ini
        $scriptsIniContent | Set-Content -Path $scriptsIniPath -Encoding ASCII -Force
        Write-Host "Script registered successfully!" -ForegroundColor Green
        Write-Host "`npsscripts.ini content:" -ForegroundColor Cyan
        $scriptsIniContent | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
} catch {
    Write-Error "Failed to create psscripts.ini: $_"
    exit 1
}

Write-Host "`n" + ("=" * 60)
Write-Host "Startup script registration complete!" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Verify in GPO Editor:" -ForegroundColor Gray
Write-Host "     Computer Configuration > Policies > Windows Settings > Scripts > Startup" -ForegroundColor Gray
Write-Host "  2. Link GPO to your AVD Session Host OU (if not already linked)" -ForegroundColor Gray
Write-Host "  3. Run 'gpupdate /force' on target machines" -ForegroundColor Gray
Write-Host "  4. Verify registry settings applied on target machine" -ForegroundColor Gray

### End Script ###

