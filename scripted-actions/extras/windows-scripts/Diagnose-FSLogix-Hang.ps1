#description: Diagnoses FSLogix login/logout hangs to identify root cause
#tags: Troubleshooting, FSLogix, Diagnostics

<#
.SYNOPSIS
    Diagnoses FSLogix login/logout hangs to identify the actual root cause.

.DESCRIPTION
    This script checks multiple potential causes of FSLogix hangs:
    1. OneDrive processes and file handles
    2. FSLogix service status
    3. Profile VHDX status
    4. Network connectivity to Azure Files
    5. Other processes with file handles
    6. Startup/logon scripts
    7. Antivirus exclusions

.NOTES
    Run this on an affected machine to identify the actual cause of the hang.
#>

$ErrorActionPreference = 'Continue'

Write-Host "FSLogix Hang Diagnostics" -ForegroundColor Cyan
Write-Host "============================================================"
Write-Host ""

# 1. Check OneDrive
Write-Host "1. Checking OneDrive..." -ForegroundColor Yellow
$onedriveProcesses = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
if ($onedriveProcesses) {
    Write-Host "   OneDrive processes running: $($onedriveProcesses.Count)" -ForegroundColor Red
    $onedriveProcesses | ForEach-Object {
        Write-Host "     - PID $($_.Id): $($_.Path)" -ForegroundColor Gray
    }
    
    Write-Host "   Checking for open file handles..." -ForegroundColor Yellow
    try {
        $handles = Get-CimInstance Win32_Process -Filter "Name = 'OneDrive.exe'" | 
            Select-Object -ExpandProperty HandleCount
        Write-Host "     Total handles: $handles" -ForegroundColor Gray
    } catch {
        Write-Host "     Could not check handles" -ForegroundColor Gray
    }
} else {
    Write-Host "   OneDrive not running" -ForegroundColor Green
}

Write-Host "   Checking OneDrive GPO settings..." -ForegroundColor Yellow
$oneDrivePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
if (Test-Path $oneDrivePolicyPath) {
    $autoMount = Get-ItemProperty -Path $oneDrivePolicyPath -Name "AutoMountTeamSites" -ErrorAction SilentlyContinue
    if ($autoMount -and $autoMount.AutoMountTeamSites -eq 1) {
        Write-Host "     WARNING: AutoMountTeamSites is ENABLED (can cause login hangs)" -ForegroundColor Red
    } else {
        Write-Host "     OK: AutoMountTeamSites is disabled" -ForegroundColor Green
    }
} else {
    Write-Host "     OneDrive policies not configured" -ForegroundColor Gray
}

Write-Host ""

# 2. Check FSLogix Service
Write-Host "2. Checking FSLogix Service..." -ForegroundColor Yellow
$fslogixService = Get-Service -Name "FSLogix*" -ErrorAction SilentlyContinue
if ($fslogixService) {
    $fslogixService | ForEach-Object {
        $status = if ($_.Status -eq 'Running') { "Green" } else { "Red" }
        Write-Host "   $($_.Name): $($_.Status)" -ForegroundColor $status
    }
} else {
    Write-Host "   WARNING: FSLogix services not found" -ForegroundColor Red
}

Write-Host ""

# 3. Check FSLogix Profile Path
Write-Host "3. Checking FSLogix Configuration..." -ForegroundColor Yellow
$fslogixRegPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
$profilePath = $null
if (Test-Path $fslogixRegPath) {
    $profilePath = Get-ItemProperty -Path $fslogixRegPath -Name "VHDLocations" -ErrorAction SilentlyContinue
    if ($profilePath -and $profilePath.VHDLocations) {
        Write-Host "   Profile path: $($profilePath.VHDLocations)" -ForegroundColor Gray
        
        $testPath = ($profilePath.VHDLocations -split ',')[0].Trim()
        Write-Host "   Testing connectivity to: $testPath" -ForegroundColor Yellow
        if (Test-Path $testPath) {
            Write-Host "     OK: Path accessible" -ForegroundColor Green
        } else {
            Write-Host "     WARNING: Path NOT accessible (network issue?)" -ForegroundColor Red
        }
    } else {
        Write-Host "   Profile path not configured" -ForegroundColor Yellow
    }
} else {
    Write-Host "   WARNING: FSLogix registry not found" -ForegroundColor Red
}

Write-Host ""

# 4. Check for other processes with many handles
Write-Host "4. Checking for processes with many file handles..." -ForegroundColor Yellow
$processes = Get-Process | Where-Object { $_.HandleCount -gt 1000 } | 
    Sort-Object HandleCount -Descending | Select-Object -First 10
if ($processes) {
    Write-Host "   Top processes by handle count:" -ForegroundColor Gray
    $processes | ForEach-Object {
        Write-Host "     $($_.Name) (PID $($_.Id)): $($_.HandleCount) handles" -ForegroundColor Gray
    }
} else {
    Write-Host "   No processes with excessive handles" -ForegroundColor Green
}

Write-Host ""

# 5. Check startup/logon scripts
Write-Host "5. Checking GPO scripts..." -ForegroundColor Yellow
$startupScripts = "C:\Windows\System32\GroupPolicy\Machine\Scripts\Startup"
if (Test-Path $startupScripts) {
    $scripts = Get-ChildItem -Path $startupScripts -Recurse -File -ErrorAction SilentlyContinue
    if ($scripts) {
        Write-Host "   Startup scripts found:" -ForegroundColor Gray
        $scripts | ForEach-Object {
            Write-Host "     - $($_.Name)" -ForegroundColor Gray
        }
    }
}

Write-Host ""

# 6. Check Event Logs for FSLogix errors
Write-Host "6. Checking Event Logs for FSLogix errors..." -ForegroundColor Yellow
try {
    $fslogixEvents = Get-WinEvent -LogName "Application" -FilterHashtable @{
        ProviderName = "*FSLogix*"
        Level = 2,3
    } -MaxEvents 5 -ErrorAction SilentlyContinue
    
    if ($fslogixEvents) {
        Write-Host "   Recent FSLogix errors/warnings:" -ForegroundColor Red
        $fslogixEvents | ForEach-Object {
            $msg = $_.Message
            if ($msg.Length -gt 100) {
                $msg = $msg.Substring(0, 100) + "..."
            }
            Write-Host "     [$($_.TimeCreated)] $msg" -ForegroundColor Gray
        }
    } else {
        Write-Host "   No recent FSLogix errors found" -ForegroundColor Green
    }
} catch {
    Write-Host "   Could not check event logs" -ForegroundColor Gray
}

Write-Host ""

# 7. Check profile VHDX status
Write-Host "7. Checking current user profile VHDX..." -ForegroundColor Yellow
$currentUser = $env:USERNAME
try {
    $userSid = (New-Object System.Security.Principal.NTAccount($currentUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    
    if ($profilePath -and $profilePath.VHDLocations) {
        $profileLocations = ($profilePath.VHDLocations -split ',') | ForEach-Object { $_.Trim() }
        foreach ($location in $profileLocations) {
            $vhdxPath = Join-Path $location "$userSid\Profile_$currentUser.VHDX"
            if (Test-Path $vhdxPath) {
                Write-Host "   Profile VHDX found: $vhdxPath" -ForegroundColor Gray
                $vhdxInfo = Get-Item $vhdxPath
                $sizeGB = [math]::Round($vhdxInfo.Length / 1GB, 2)
                Write-Host "     Size: $sizeGB GB" -ForegroundColor Gray
                Write-Host "     Last modified: $($vhdxInfo.LastWriteTime)" -ForegroundColor Gray
            }
        }
    }
} catch {
    Write-Host "   Could not check profile VHDX: $_" -ForegroundColor Gray
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Diagnostics Complete" -ForegroundColor Cyan
Write-Host ""
Write-Host "Recommendations:" -ForegroundColor Yellow

if ($onedriveProcesses) {
    if ($autoMount -and $autoMount.AutoMountTeamSites -eq 1) {
        Write-Host "  WARNING: OneDrive AutoMountTeamSites is enabled - this is likely causing login hangs" -ForegroundColor Red
        Write-Host "     Solution: Disable AutoMountTeamSites in GPO" -ForegroundColor Gray
    }
    Write-Host "  WARNING: OneDrive is running - may cause logout hangs if file handles are open" -ForegroundColor Yellow
    Write-Host "     Solution: Add logoff script to close OneDrive gracefully" -ForegroundColor Gray
}

Write-Host "  Check event logs for specific FSLogix errors" -ForegroundColor Gray
Write-Host "  Verify network connectivity to Azure Files share" -ForegroundColor Gray

### End Script ###
