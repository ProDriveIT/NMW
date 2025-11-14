#description: Creates GPO for OneDrive settings with startup script
#tags: GPO, OneDrive, PowerShell, Group Policy

<#
.SYNOPSIS
    Creates a Group Policy Object (GPO) for OneDrive and SharePoint settings.
    Configures the GPO to run the OneDrive configuration script at startup.

.DESCRIPTION
    This script creates a new GPO named "AVD - OneDrive & SharePoint Settings" and:
    1. Configures a startup script to run configure-onedrive-gpo-settings.ps1
    2. Enables PowerShell script execution
    3. Optionally links the GPO to a specified OU

.PARAMETER GPOName
    Name of the GPO to create. Default: "AVD - OneDrive & SharePoint Settings"

.PARAMETER ScriptPath
    Network path to the configure-onedrive-gpo-settings.ps1 script.
    Default: Assumes script is in same directory or NETLOGON share

.PARAMETER TargetOU
    Distinguished name of the OU to link the GPO to (optional).
    Example: "OU=AVD Session Hosts,DC=contoso,DC=com"

.PARAMETER LinkGPO
    If specified, links the GPO to the TargetOU. Default: false

.NOTES
    - Requires Group Policy Management Console (GPMC) cmdlets
    - Must be run on a Domain Controller or machine with RSAT installed
    - Requires Domain Admin or GPO creation permissions
    - Script assumes configure-onedrive-gpo-settings.ps1 is accessible via network path

.EXAMPLE
    .\create-onedrive-gpo.ps1
    
.EXAMPLE
    .\create-onedrive-gpo.ps1 -TargetOU "OU=AVD Session Hosts,DC=contoso,DC=com" -LinkGPO

.EXAMPLE
    .\create-onedrive-gpo.ps1 -ScriptPath "\\contoso.com\NETLOGON\Scripts\configure-onedrive-gpo-settings.ps1"
#>

[CmdletBinding()]
param(
    [string]$GPOName = "AVD - OneDrive & SharePoint Settings",
    [string]$ScriptPath = "",
    [string]$TargetOU = "",
    [switch]$LinkGPO = $false
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

# Determine script path
if ([string]::IsNullOrEmpty($ScriptPath)) {
    $scriptName = "configure-onedrive-gpo-settings.ps1"
    $searchPaths = @()
    
    # 1. Try windows-scripts subdirectory (relative to this script)
    $windowsScriptsPath = Join-Path $PSScriptRoot "windows-scripts\$scriptName"
    $searchPaths += $windowsScriptsPath
    
    # 2. Try scripted-actions\windows-scripts (if running from repo root)
    $repoPath = Join-Path $PSScriptRoot "scripted-actions\windows-scripts\$scriptName"
    $searchPaths += $repoPath
    
    # 3. Try current directory
    $currentScript = Join-Path $PSScriptRoot $scriptName
    $searchPaths += $currentScript
    
    # 4. Try current working directory
    $cwdScript = Join-Path (Get-Location).Path $scriptName
    $searchPaths += $cwdScript
    
    # 5. Try NETLOGON share
    $domain = $env:USERDNSDOMAIN
    if ($domain) {
        $netlogonPath = "\\$domain\NETLOGON\Scripts\$scriptName"
        $searchPaths += $netlogonPath
    }
    
    # Search all paths
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $ScriptPath = (Resolve-Path $path).Path
            Write-Host "Found script at: $ScriptPath" -ForegroundColor Green
            break
        }
    }
    
    # If still not found, use default NETLOGON path
    if ([string]::IsNullOrEmpty($ScriptPath)) {
        Write-Warning "Script not found in common locations. Please specify -ScriptPath parameter."
        Write-Host "Searched locations:" -ForegroundColor Yellow
        $searchPaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        if ($domain) {
            $ScriptPath = "\\$domain\NETLOGON\Scripts\$scriptName"
            Write-Host "`nUsing default path: $ScriptPath" -ForegroundColor Yellow
            Write-Host "Note: Script will be copied to GPO folder, but source should be accessible." -ForegroundColor Yellow
        } else {
            Write-Error "Could not determine domain. Please specify -ScriptPath parameter."
            exit 1
        }
    }
}

# Store original script path for reference
$originalScriptPath = $ScriptPath

# Verify script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Warning "Script not found at: $ScriptPath"
    Write-Host "Please copy configure-onedrive-gpo-settings.ps1 to the network location first." -ForegroundColor Yellow
    $continue = Read-Host "Continue creating GPO anyway? (y/n)"
    if ($continue -ne "y") {
        exit 1
    }
}

Write-Host "Creating GPO: $GPOName" -ForegroundColor Cyan
Write-Host "=" * 60

# Check if GPO already exists
$existingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if ($existingGPO) {
    Write-Warning "GPO '$GPOName' already exists!"
    $overwrite = Read-Host "Do you want to delete and recreate it? (y/n)"
    if ($overwrite -eq "y") {
        Remove-GPO -Name $GPOName -Confirm:$false
        Write-Host "Deleted existing GPO." -ForegroundColor Yellow
    } else {
        Write-Host "Exiting. Please delete or rename the existing GPO first." -ForegroundColor Red
        exit 1
    }
}

# Create the GPO
try {
    Write-Host "`nCreating new GPO..." -ForegroundColor Yellow
    $gpo = New-GPO -Name $GPOName -Comment "OneDrive and SharePoint settings for AVD session hosts"
    Write-Host "GPO created successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to create GPO: $_"
    exit 1
}

# Configure startup script
Write-Host "`nConfiguring startup script..." -ForegroundColor Yellow

# Get GPO path
$gpoPath = "\\$($env:USERDNSDOMAIN)\SYSVOL\$($env:USERDNSDOMAIN)\Policies\{$($gpo.Id)}\Machine\Scripts\Startup"
# PowerShell scripts use psscripts.ini, not scripts.ini
$scriptsIniPath = Join-Path $gpoPath "psscripts.ini"

# Create directory if it doesn't exist
if (-not (Test-Path $gpoPath)) {
    New-Item -Path $gpoPath -ItemType Directory -Force | Out-Null
    Write-Host "Created GPO scripts directory: $gpoPath" -ForegroundColor Gray
}

# Copy script to GPO folder (must be in GPO folder for it to work)
$scriptFileName = "configure-onedrive-gpo-settings.ps1"
$gpoScriptPath = Join-Path $gpoPath $scriptFileName

if (Test-Path $ScriptPath) {
    Copy-Item -Path $ScriptPath -Destination $gpoScriptPath -Force
    Write-Host "Script copied to GPO folder: $gpoScriptPath" -ForegroundColor Green
} else {
    Write-Warning "Source script not found at: $ScriptPath"
    Write-Host "Please ensure the script exists, or copy it manually to: $gpoScriptPath" -ForegroundColor Yellow
}

# Create/update psscripts.ini file to register the PowerShell script
try {
    # Read existing psscripts.ini if it exists
    $scriptsIniContent = @()
    if (Test-Path $scriptsIniPath) {
        $scriptsIniContent = Get-Content $scriptsIniPath
    }
    
    # Check if script is already registered
    $scriptRegistered = $scriptsIniContent | Where-Object { $_ -match "^\d+Scripts=.*$scriptFileName" }
    
    if (-not $scriptRegistered) {
        # Find next script number (PowerShell scripts use [number] format)
        $scriptNumbers = $scriptsIniContent | Where-Object { $_ -match "\[(\d+)\]" } | ForEach-Object {
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
        Write-Host "Startup script registered in psscripts.ini" -ForegroundColor Green
        Write-Host "Script will appear in 'PowerShell Scripts' tab in GPO Editor" -ForegroundColor Gray
    } else {
        Write-Host "Startup script already registered in psscripts.ini" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Failed to create psscripts.ini: $_"
    Write-Host "You may need to configure the startup script manually in GPO Editor:" -ForegroundColor Yellow
    Write-Host "  Computer Configuration > Policies > Windows Settings > Scripts > Startup" -ForegroundColor Gray
    Write-Host "  Click 'PowerShell Scripts' tab, then 'Add...' button" -ForegroundColor Gray
}

# Enable PowerShell script execution
Write-Host "`nEnabling PowerShell script execution..." -ForegroundColor Yellow
try {
    # Set PowerShell execution policy via registry
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -ValueName "ExecutionPolicy" -Type String -Value "Bypass" -ErrorAction SilentlyContinue
    
    # Also set via Administrative Template (more reliable)
    $regPath = "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell"
    Set-GPRegistryValue -Name $GPOName -Key $regPath -ValueName "EnableScripts" -Type DWord -Value 1 -ErrorAction SilentlyContinue
    
    Write-Host "PowerShell script execution enabled." -ForegroundColor Green
} catch {
    Write-Warning "Failed to enable PowerShell execution policy: $_"
    Write-Host "You may need to configure this manually in GPO Editor:" -ForegroundColor Yellow
    Write-Host "  Computer Configuration > Administrative Templates > Windows Components > Windows PowerShell" -ForegroundColor Gray
    Write-Host "  Enable: Turn on Script Execution" -ForegroundColor Gray
}

# Link GPO to OU if specified
if ($LinkGPO -and -not [string]::IsNullOrEmpty($TargetOU)) {
    Write-Host "`nLinking GPO to OU: $TargetOU" -ForegroundColor Yellow
    try {
        New-GPLink -Name $GPOName -Target $TargetOU -ErrorAction Stop
        Write-Host "GPO linked successfully!" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to link GPO to OU: $_"
        Write-Host "You can link it manually in Group Policy Management Console." -ForegroundColor Yellow
    }
} elseif ($LinkGPO) {
    Write-Warning "LinkGPO specified but TargetOU not provided. Skipping link."
}

# Summary
Write-Host "`n" + ("=" * 60)
Write-Host "GPO Creation Summary" -ForegroundColor Cyan
Write-Host "  GPO Name: $GPOName"
Write-Host "  GPO ID: $($gpo.Id)"
Write-Host "  Script Path: $ScriptPath"
if ($LinkGPO -and -not [string]::IsNullOrEmpty($TargetOU)) {
    Write-Host "  Linked to OU: $TargetOU"
} else {
    Write-Host "  Linked to OU: Not linked (link manually in GPMC)"
}
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Verify script exists in GPO folder: $gpoScriptPath" -ForegroundColor Gray
if ($originalScriptPath -ne $gpoScriptPath) {
    Write-Host "     (Copied from: $originalScriptPath)" -ForegroundColor Gray
}
Write-Host "  2. Link GPO to your AVD Session Host OU (if not already linked)" -ForegroundColor Gray
Write-Host "  3. Run 'gpupdate /force' on target machines or wait for next refresh" -ForegroundColor Gray
Write-Host "  4. Verify settings applied: Check registry on target machine" -ForegroundColor Gray
Write-Host "`nNote: The script is configured to run at startup. Verify in GPO Editor:" -ForegroundColor Cyan
Write-Host "  Computer Configuration > Policies > Windows Settings > Scripts > Startup" -ForegroundColor Gray

### End Script ###

