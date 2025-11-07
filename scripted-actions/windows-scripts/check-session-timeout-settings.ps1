# Check AVD Session Timeout Settings
# This script displays the current session timeout configuration on an AVD session host

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "AVD Session Timeout Settings Check" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Registry path for Terminal Services policies
$regPath = "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services"

# Check if the registry path exists
if (-not (Test-Path $regPath)) {
    Write-Host "Registry path not found: $regPath" -ForegroundColor Yellow
    Write-Host "Session timeout settings may not be configured via Group Policy." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Note: Settings may be configured via:" -ForegroundColor Yellow
    Write-Host "  - Local Group Policy Editor (gpedit.msc)" -ForegroundColor Gray
    Write-Host "  - Domain Group Policy" -ForegroundColor Gray
    Write-Host "  - Azure Portal (Host Pool settings)" -ForegroundColor Gray
    exit 0
}

Write-Host "Registry Path: $regPath" -ForegroundColor Gray
Write-Host ""

# Function to convert minutes to readable format
function Convert-MinutesToReadable {
    param([int]$Minutes)
    
    if ($Minutes -eq 0) {
        return "Not configured (unlimited)"
    }
    
    $hours = [math]::Floor($Minutes / 60)
    $mins = $Minutes % 60
    
    if ($hours -gt 0 -and $mins -gt 0) {
        return "$hours hour(s) $mins minute(s) ($Minutes minutes)"
    }
    elseif ($hours -gt 0) {
        return "$hours hour(s) ($Minutes minutes)"
    }
    else {
        return "$Minutes minute(s)"
    }
}

# Check each timeout setting
$settings = @(
    @{
        Name = "MaxConnectionTime"
        DisplayName = "Time limit for active sessions"
        Description = "Maximum duration a session can remain active"
    },
    @{
        Name = "MaxDisconnectionTime"
        DisplayName = "Time limit for disconnected sessions"
        Description = "How long a disconnected session remains before being terminated"
    },
    @{
        Name = "MaxIdleTime"
        DisplayName = "Time limit for active but idle sessions"
        Description = "How long an idle session remains before being disconnected"
    },
    @{
        Name = "RemoteAppLogoffTimeLimit"
        DisplayName = "Time limit to sign out sessions"
        Description = "Time to wait before signing out a disconnected session"
    }
)

$allConfigured = $true

foreach ($setting in $settings) {
    $value = Get-ItemProperty -Path $regPath -Name $setting.Name -ErrorAction SilentlyContinue
    
    if ($null -ne $value -and $null -ne $value.$($setting.Name)) {
        $minutes = $value.$($setting.Name)
        $readable = Convert-MinutesToReadable -Minutes $minutes
        Write-Host "✓ $($setting.DisplayName):" -ForegroundColor Green
        Write-Host "    Value: $readable" -ForegroundColor White
        Write-Host "    Registry: $($setting.Name) = $minutes (minutes)" -ForegroundColor Gray
        Write-Host "    Description: $($setting.Description)" -ForegroundColor Gray
    }
    else {
        Write-Host "✗ $($setting.DisplayName):" -ForegroundColor Yellow
        Write-Host "    Status: Not configured" -ForegroundColor Gray
        Write-Host "    Description: $($setting.Description)" -ForegroundColor Gray
        $allConfigured = $false
    }
    Write-Host ""
}

# Summary
Write-Host "===========================================" -ForegroundColor Cyan
if ($allConfigured) {
    Write-Host "All session timeout settings are configured." -ForegroundColor Green
}
else {
    Write-Host "Some session timeout settings are not configured." -ForegroundColor Yellow
    Write-Host "Unconfigured settings will use default behavior (typically unlimited)." -ForegroundColor Gray
}
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Additional information
Write-Host "Additional Check Methods:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Group Policy Editor (gpedit.msc):" -ForegroundColor Yellow
Write-Host "   Computer Configuration > Policies > Administrative Templates >" -ForegroundColor Gray
Write-Host "   Windows Components > Remote Desktop Services > Remote Desktop Session Host >" -ForegroundColor Gray
Write-Host "   Session Time Limits" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Azure Portal - Host Pool Settings:" -ForegroundColor Yellow
Write-Host "   Host pools > [Your Host Pool] > Properties > Session limits" -ForegroundColor Gray
Write-Host ""
Write-Host "3. PowerShell (Alternative registry location):" -ForegroundColor Yellow
Write-Host "   Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'" -ForegroundColor Gray
Write-Host ""

