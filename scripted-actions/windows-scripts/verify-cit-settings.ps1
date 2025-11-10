#description: Verifies all CIT script registry settings are applied correctly
#tags: Nerdio, AVD, Verification, Registry

<#
.SYNOPSIS
    Verifies that all CIT script registry settings have been applied correctly.

.DESCRIPTION
    This script checks all registry paths and values that are set by the CIT scripts
    to ensure they have been applied correctly. It provides a summary of passed/failed checks.

.EXAMPLE
    .\verify-cit-settings.ps1
    
.NOTES
    Requires:
    - Administrator privileges (for reading HKLM registry)
    
    This script checks:
    - OneDrive auto sign-in settings
    - Outlook cached mode settings
    - Power options restrictions
    - FSLogix tray startup
    - Windows Installer RDS compatibility
    - MDM enrollment settings
#>

$ErrorActionPreference = 'Continue'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script should be run with administrative privileges for best results."
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CIT Settings Verification" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Define all checks
$allChecks = @(
    @{Name="OneDrive SilentAccountConfig"; Path="HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"; Property="SilentAccountConfig"; Expected=1},
    @{Name="OneDrive Startup"; Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Property="OneDrive"; Expected="*OneDrive.exe*"},
    @{Name="FSLogix RoamIdentity"; Path="HKLM:\SOFTWARE\FSLogix\Profiles"; Property="RoamIdentity"; Expected=1},
    @{Name="Outlook Cached Mode"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode"; Property="Enable"; Expected=1},
    @{Name="Outlook Sync Window"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode"; Property="SyncWindowSetting"; Expected=3},
    @{Name="Power Options - NoClose"; Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Property="NoClose"; Expected=1},
    @{Name="Windows Installer RDS"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\Application Compatibility"; Property="DisableMsi"; Expected=1},
    @{Name="MDM AutoEnroll"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM"; Property="AutoEnrollMDM"; Expected=1}
)

$passed = 0
$failed = 0
$skipped = 0

foreach ($check in $allChecks) {
    Write-Host "$($check.Name)..." -NoNewline -ForegroundColor Yellow
    
    if (Test-Path $check.Path) {
        $value = Get-ItemProperty -Path $check.Path -Name $check.Property -ErrorAction SilentlyContinue
        
        if ($value) {
            $actualValue = $value.$($check.Property)
            
            # Handle optional checks (FSLogix, MDM)
            if ($check.Name -eq "FSLogix RoamIdentity" -and -not (Test-Path "HKLM:\SOFTWARE\FSLogix\Profiles")) {
                Write-Host " [SKIP] (FSLogix not installed, skipping)" -ForegroundColor Gray
                $skipped++
                continue
            }
            
            if ($check.Name -eq "MDM AutoEnroll" -and -not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM")) {
                Write-Host " [SKIP] (MDM not configured, skipping)" -ForegroundColor Gray
                $skipped++
                continue
            }
            
            if ($check.Expected -is [string] -and $check.Expected -like "*") {
                # Pattern match
                if ($actualValue -like $check.Expected) {
                    Write-Host " [PASS]" -ForegroundColor Green
                    $passed++
                } else {
                    Write-Host " [FAIL] (Expected: $($check.Expected), Got: $actualValue)" -ForegroundColor Red
                    $failed++
                }
            } else {
                # Exact match
                if ($actualValue -eq $check.Expected) {
                    Write-Host " [PASS]" -ForegroundColor Green
                    $passed++
                } else {
                    Write-Host " [FAIL] (Expected: $($check.Expected), Got: $actualValue)" -ForegroundColor Red
                    $failed++
                }
            }
        } else {
            Write-Host " [FAIL] (Property not found)" -ForegroundColor Red
            $failed++
        }
    } else {
        # Check if this is an optional setting
        if ($check.Name -eq "FSLogix RoamIdentity") {
            Write-Host " [SKIP] (FSLogix not installed, skipping)" -ForegroundColor Gray
            $skipped++
        } elseif ($check.Name -eq "MDM AutoEnroll") {
            Write-Host " [SKIP] (MDM not configured, skipping)" -ForegroundColor Gray
            $skipped++
        } else {
            Write-Host " [FAIL] (Path does not exist)" -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
if ($skipped -gt 0) {
    Write-Host "Summary: $passed passed, $failed failed, $skipped skipped" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
} else {
    Write-Host "Summary: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
}
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if ($failed -eq 0) {
    Write-Host "All required settings are configured correctly!" -ForegroundColor Green
} else {
    Write-Host "Some settings are missing or incorrect. Please review the failed checks above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For detailed information, see REGISTRY_VERIFICATION_GUIDE.md" -ForegroundColor Gray
}

