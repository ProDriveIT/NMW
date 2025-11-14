#description: Verifies OneDrive GPO configuration
#tags: GPO, Verification, OneDrive

<#
.SYNOPSIS
    Verifies that the OneDrive GPO is configured correctly.

.DESCRIPTION
    Checks:
    1. GPO exists
    2. Startup script is configured
    3. PowerShell execution is enabled
    4. Script file exists in GPO folder

.PARAMETER GPOName
    Name of the GPO to verify. Default: "AVD - OneDrive & SharePoint Settings"
#>

[CmdletBinding()]
param(
    [string]$GPOName = "AVD - OneDrive & SharePoint Settings"
)

Import-Module GroupPolicy -ErrorAction SilentlyContinue

Write-Host "Verifying OneDrive GPO Configuration" -ForegroundColor Cyan
Write-Host "=" * 60

# Check if GPO exists
$gpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if (-not $gpo) {
    Write-Host "`n❌ GPO '$GPOName' not found!" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ GPO Found: $GPOName" -ForegroundColor Green
Write-Host "   GPO ID: $($gpo.Id)" -ForegroundColor Gray

# Check startup script
$gpoPath = "\\$($env:USERDNSDOMAIN)\SYSVOL\$($env:USERDNSDOMAIN)\Policies\{$($gpo.Id)}\Machine\Scripts\Startup"
$scriptsIniPath = Join-Path $gpoPath "scripts.ini"
$scriptPath = Join-Path $gpoPath "configure-onedrive-gpo-settings.ps1"

Write-Host "`nChecking Startup Script Configuration..." -ForegroundColor Yellow

# Check if scripts.ini exists
if (Test-Path $scriptsIniPath) {
    Write-Host "✅ scripts.ini found" -ForegroundColor Green
    $scriptsIni = Get-Content $scriptsIniPath
    Write-Host "   Content:" -ForegroundColor Gray
    $scriptsIni | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ scripts.ini NOT found!" -ForegroundColor Red
    Write-Host "   Run fix-onedrive-gpo-startup-script.ps1 to fix this" -ForegroundColor Yellow
}

# Check if script file exists
if (Test-Path $scriptPath) {
    Write-Host "✅ Script file found: $scriptPath" -ForegroundColor Green
    $scriptInfo = Get-Item $scriptPath
    Write-Host "   Size: $($scriptInfo.Length) bytes" -ForegroundColor Gray
    Write-Host "   Modified: $($scriptInfo.LastWriteTime)" -ForegroundColor Gray
} else {
    Write-Host "❌ Script file NOT found: $scriptPath" -ForegroundColor Red
}

# Check PowerShell execution policy
Write-Host "`nChecking PowerShell Execution Policy..." -ForegroundColor Yellow
$psPolicy = Get-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -ValueName "EnableScripts" -ErrorAction SilentlyContinue
if ($psPolicy) {
    Write-Host "✅ PowerShell script execution enabled" -ForegroundColor Green
    Write-Host "   Value: $($psPolicy.Value)" -ForegroundColor Gray
} else {
    Write-Host "⚠️  PowerShell execution policy not found (may be set via ADMX template)" -ForegroundColor Yellow
}

# Check GPO links
Write-Host "`nChecking GPO Links..." -ForegroundColor Yellow
$links = Get-GPInheritance -Target (Get-ADDomain).DistinguishedName | Select-Object -ExpandProperty GpoLinks | Where-Object { $_.DisplayName -eq $GPOName }
if ($links) {
    Write-Host "✅ GPO is linked to:" -ForegroundColor Green
    $links | ForEach-Object {
        Write-Host "   - $($_.Target)" -ForegroundColor Gray
        Write-Host "     Enabled: $($_.Enabled)" -ForegroundColor Gray
    }
} else {
    Write-Host "⚠️  GPO is not linked to any OU" -ForegroundColor Yellow
    Write-Host "   Link it to your AVD Session Host OU in GPMC" -ForegroundColor Gray
}

Write-Host "`n" + ("=" * 60)
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "`nThe OneDrive settings are NOT directly in the GPO." -ForegroundColor Yellow
Write-Host "They are applied by the startup script when it runs on target machines." -ForegroundColor Yellow
Write-Host "`nTo see the actual OneDrive registry settings:" -ForegroundColor Cyan
Write-Host "  1. Run 'gpupdate /force' on a target machine" -ForegroundColor Gray
Write-Host "  2. Check registry: HKLM\SOFTWARE\Policies\Microsoft\OneDrive" -ForegroundColor Gray
Write-Host "`nOr verify the script will run by checking:" -ForegroundColor Cyan
Write-Host "  GPO Editor > Computer Configuration > Policies > Windows Settings > Scripts > Startup" -ForegroundColor Gray

### End Script ###

