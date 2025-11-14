#description: Checks if OneDrive GPO scripts are configured
#tags: GPO, OneDrive, Verification

<#
.SYNOPSIS
    Checks if OneDrive GPO scripts (startup, logon, logoff) are configured correctly.
#>

$ErrorActionPreference = 'Continue'

Write-Host "Checking OneDrive GPO Scripts Configuration" -ForegroundColor Cyan
Write-Host "============================================================"
Write-Host ""

# Get GPO name
$gpoName = "AVD - OneDrive & SharePoint Settings"

try {
    Import-Module GroupPolicy -ErrorAction Stop
} catch {
    Write-Host "ERROR: GroupPolicy module not found. Install RSAT or run on Domain Controller." -ForegroundColor Red
    exit 1
}

# Find the GPO
try {
    $gpo = Get-GPO -Name $gpoName -ErrorAction Stop
    Write-Host "Found GPO: $gpoName" -ForegroundColor Green
    Write-Host "GPO ID: $($gpo.Id)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "ERROR: GPO '$gpoName' not found!" -ForegroundColor Red
    exit 1
}

# Get domain and SYSVOL paths
$domain = (Get-ADDomain).DNSRoot
$gpoBasePath = "\\$domain\SYSVOL\$domain\Policies\{$($gpo.Id)}"

Write-Host "GPO Path: $gpoBasePath" -ForegroundColor Gray
Write-Host ""

# 1. Check Startup Script (Computer Configuration)
Write-Host "1. Startup Script (Computer Configuration)" -ForegroundColor Yellow
Write-Host "   Path: $gpoBasePath\Machine\Scripts\Startup" -ForegroundColor Gray
$startupPath = "$gpoBasePath\Machine\Scripts\Startup"
if (Test-Path $startupPath) {
    $startupScript = Get-ChildItem -Path $startupPath -Filter "configure-onedrive-gpo-settings.ps1" -ErrorAction SilentlyContinue
    if ($startupScript) {
        Write-Host "   Status: FOUND" -ForegroundColor Green
        Write-Host "   File: $($startupScript.Name)" -ForegroundColor Gray
        Write-Host "   Size: $([math]::Round($startupScript.Length / 1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "   Modified: $($startupScript.LastWriteTime)" -ForegroundColor Gray
        
        # Check psscripts.ini
        $psscriptsIni = Join-Path $startupPath "psscripts.ini"
        if (Test-Path $psscriptsIni) {
            Write-Host "   psscripts.ini: FOUND" -ForegroundColor Green
            $iniContent = Get-Content $psscriptsIni -ErrorAction SilentlyContinue
            if ($iniContent -match "configure-onedrive-gpo-settings.ps1") {
                Write-Host "   Script registered in psscripts.ini: YES" -ForegroundColor Green
            } else {
                Write-Host "   Script registered in psscripts.ini: NO" -ForegroundColor Red
            }
        } else {
            Write-Host "   psscripts.ini: NOT FOUND" -ForegroundColor Red
        }
    } else {
        Write-Host "   Status: NOT FOUND" -ForegroundColor Red
    }
} else {
    Write-Host "   Status: Directory does not exist" -ForegroundColor Red
}

Write-Host ""

# 2. Check Logon Script (User Configuration)
Write-Host "2. Logon Script (User Configuration)" -ForegroundColor Yellow
Write-Host "   Path: $gpoBasePath\User\Scripts\Logon" -ForegroundColor Gray
$logonPath = "$gpoBasePath\User\Scripts\Logon"
if (Test-Path $logonPath) {
    $logonScript = Get-ChildItem -Path $logonPath -Filter "configure-onedrive-user-logon.ps1" -ErrorAction SilentlyContinue
    if ($logonScript) {
        Write-Host "   Status: FOUND" -ForegroundColor Green
        Write-Host "   File: $($logonScript.Name)" -ForegroundColor Gray
        Write-Host "   Size: $([math]::Round($logonScript.Length / 1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "   Modified: $($logonScript.LastWriteTime)" -ForegroundColor Gray
        
        # Check scripts.ini
        $scriptsIni = Join-Path $logonPath "scripts.ini"
        if (Test-Path $scriptsIni) {
            Write-Host "   scripts.ini: FOUND" -ForegroundColor Green
            $iniContent = Get-Content $scriptsIni -ErrorAction SilentlyContinue
            if ($iniContent -match "configure-onedrive-user-logon.ps1") {
                Write-Host "   Script registered in scripts.ini: YES" -ForegroundColor Green
            } else {
                Write-Host "   Script registered in scripts.ini: NO" -ForegroundColor Red
            }
        } else {
            Write-Host "   scripts.ini: NOT FOUND" -ForegroundColor Red
        }
    } else {
        Write-Host "   Status: NOT FOUND" -ForegroundColor Red
    }
} else {
    Write-Host "   Status: Directory does not exist" -ForegroundColor Red
}

Write-Host ""

# 3. Check Logoff Script (User Configuration)
Write-Host "3. Logoff Script (User Configuration)" -ForegroundColor Yellow
Write-Host "   Path: $gpoBasePath\User\Scripts\Logoff" -ForegroundColor Gray
$logoffPath = "$gpoBasePath\User\Scripts\Logoff"
if (Test-Path $logoffPath) {
    $logoffScript = Get-ChildItem -Path $logoffPath -Filter "configure-onedrive-user-logoff.ps1" -ErrorAction SilentlyContinue
    if ($logoffScript) {
        Write-Host "   Status: FOUND" -ForegroundColor Green
        Write-Host "   File: $($logoffScript.Name)" -ForegroundColor Gray
        Write-Host "   Size: $([math]::Round($logoffScript.Length / 1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "   Modified: $($logoffScript.LastWriteTime)" -ForegroundColor Gray
        
        # Check scripts.ini
        $scriptsIni = Join-Path $logoffPath "scripts.ini"
        if (Test-Path $scriptsIni) {
            Write-Host "   scripts.ini: FOUND" -ForegroundColor Green
            $iniContent = Get-Content $scriptsIni -ErrorAction SilentlyContinue
            if ($iniContent -match "configure-onedrive-user-logoff.ps1") {
                Write-Host "   Script registered in scripts.ini: YES" -ForegroundColor Green
            } else {
                Write-Host "   Script registered in scripts.ini: NO" -ForegroundColor Red
            }
        } else {
            Write-Host "   scripts.ini: NOT FOUND" -ForegroundColor Red
        }
    } else {
        Write-Host "   Status: NOT FOUND" -ForegroundColor Red
    }
} else {
    Write-Host "   Status: Directory does not exist" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Summary" -ForegroundColor Cyan
Write-Host ""
Write-Host "To verify in GPO Editor:" -ForegroundColor Yellow
Write-Host "  1. Open Group Policy Management Console (GPMC)" -ForegroundColor Gray
Write-Host "  2. Right-click GPO > Edit" -ForegroundColor Gray
Write-Host "  3. Computer Configuration > Policies > Windows Settings > Scripts > Startup" -ForegroundColor Gray
Write-Host "     - Check 'PowerShell Scripts' tab" -ForegroundColor Gray
Write-Host "  4. User Configuration > Policies > Windows Settings > Scripts > Logon" -ForegroundColor Gray
Write-Host "  5. User Configuration > Policies > Windows Settings > Scripts > Logoff" -ForegroundColor Gray

### End Script ###

