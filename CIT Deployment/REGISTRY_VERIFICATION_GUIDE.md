# Registry Verification Guide for AVD CIT Scripts

This guide lists all registry paths to verify that settings from our CIT scripts have been applied correctly. These settings were moved from Group Policy Objects (GPOs) to scripted configurations.

## Quick Verification Commands

You can use PowerShell to quickly check all settings:

```powershell
# Run this in PowerShell (as Administrator) to check all settings
$checks = @{
    "OneDrive Auto Sign-In" = @{
        Path = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
        Properties = @("SilentAccountConfig", "FilesOnDemandEnabled", "DisableSyncHealthReporting", "DisableSyncAdminReports")
    }
    "OneDrive Startup" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        Properties = @("OneDrive")
    }
    "FSLogix Token Roaming" = @{
        Path = "HKLM:\SOFTWARE\FSLogix\Profiles"
        Properties = @("RoamIdentity")
    }
    "Outlook Cached Mode" = @{
        Path = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode"
        Properties = @("Enable", "SyncWindowSetting", "CalendarSyncWindowSettingDays", "CalendarSyncWindowSetting", "DownloadSharedAttachments", "DownloadPublicFolderFavorites", "CachedModeForNewProfiles")
    }
    "Outlook RPC Settings" = @{
        Path = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\RPC"
        Properties = @("EnableRPCEncryption", "RpcHttpConnectionTimeout")
    }
    "Outlook Fast Shutdown" = @{
        Path = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Options\General"
        Properties = @("DisableFastShutdown")
    }
    "Power Options - NoClose" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        Properties = @("NoClose", "Start_ShowShutdown")
    }
    "Power Options - NoStartMenuPowerButton" = @{
        Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        Properties = @("NoStartMenuPowerButton")
    }
    "FSLogix Tray Startup" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        Properties = @("FSLogixTray")
    }
    "Windows Installer RDS Compatibility" = @{
        Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\Application Compatibility"
        Properties = @("DisableMsi")
    }
    "MDM Enrollment" = @{
        Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM"
        Properties = @("AutoEnrollMDM", "UseAADCredentialType")
    }
    "Workplace Join" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows Settings\WorkPlaceJoin"
        Properties = @("BlockAADWorkplaceJoin")
    }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Registry Settings Verification" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($check in $checks.GetEnumerator()) {
    $name = $check.Key
    $config = $check.Value
    $path = $config.Path
    $properties = $config.Properties
    
    Write-Host "$name" -ForegroundColor Yellow
    Write-Host "  Path: $path" -ForegroundColor Gray
    
    if (Test-Path $path) {
        foreach ($prop in $properties) {
            $value = Get-ItemProperty -Path $path -Name $prop -ErrorAction SilentlyContinue
            if ($value) {
                $propValue = $value.$prop
                Write-Host "    ✓ $prop = $propValue" -ForegroundColor Green
            } else {
                Write-Host "    ✗ $prop = NOT SET" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "    ✗ Registry path does not exist" -ForegroundColor Red
    }
    Write-Host ""
}
```

---

## Detailed Registry Paths by Script

### 1. OneDrive Auto Sign-In (`configure-onedrive-auto-signin.ps1`)

**Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\OneDrive`

| Property | Expected Value | Description |
|----------|----------------|-------------|
| `SilentAccountConfig` | `1` (DWord) | Enables automatic sign-in with Windows credentials |
| `FilesOnDemandEnabled` | `1` (DWord) | Enables files on-demand (reduces storage) |
| `DisableSyncHealthReporting` | `1` (DWord) | Disables sync health reporting (reduces network traffic) |
| `DisableSyncAdminReports` | `1` (DWord) | Disables sync admin reports (reduces network traffic) |
| `TenantId` | (String, optional) | Tenant ID for silent account configuration (usually not needed) |

**OneDrive Startup:**
- **Registry Path:** `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`
- **Property:** `OneDrive`
- **Expected Value:** `"C:\Program Files\Microsoft OneDrive\OneDrive.exe" /background`

**FSLogix Token Roaming (if FSLogix is installed):**
- **Registry Path:** `HKLM:\SOFTWARE\FSLogix\Profiles`
- **Property:** `RoamIdentity`
- **Expected Value:** `1` (DWord) - Preserves OneDrive authentication tokens across sessions

**Known Folder Move (if enabled):**
- **Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\KFMSilentOptIn`
- **Properties:** `Desktop`, `Documents`, `Pictures` (all set to `"True"` as String)

---

### 2. Outlook Cached Exchange Mode (`configure-outlook-cached-mode.ps1`)

**Cached Mode Settings:**
- **Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode`

| Property | Expected Value | Description |
|----------|----------------|-------------|
| `Enable` | `1` (DWord) | Enables Cached Exchange Mode |
| `SyncWindowSetting` | `1`, `3`, `6`, `12`, or `0` (DWord) | Cached mail period (1=1 month, 3=3 months, 6=6 months, 12=12 months, 0=All) |
| `CalendarSyncWindowSettingDays` | `60` (DWord, default) | Number of calendar days to sync |
| `CalendarSyncWindowSetting` | `0` (DWord) | Full calendar sync enabled |
| `DownloadSharedAttachments` | `1` or `0` (DWord) | Download shared attachments (default: 1) |
| `DownloadPublicFolderFavorites` | `1` or `0` (DWord) | Download public folder favorites (default: 0) |
| `CachedModeForNewProfiles` | `1` (DWord) | Ensures all new profiles use cached mode |

**RPC/HTTP Settings:**
- **Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\RPC`

| Property | Expected Value | Description |
|----------|----------------|-------------|
| `EnableRPCEncryption` | `1` (DWord) | Enables RPC encryption |
| `RpcHttpConnectionTimeout` | `30` (DWord) | Connection timeout in seconds |

**Fast Shutdown:**
- **Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Options\General`
- **Property:** `DisableFastShutdown`
- **Expected Value:** `1` (DWord) - Disables fast shutdown (recommended for AVD)

---

### 3. Disable Power Options (`disable-power-options.ps1`)

**Remove Shut Down from Start Menu:**
- **Registry Path:** `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer`
- **Property:** `NoClose`
- **Expected Value:** `1` (DWord) - Removes Shut Down option from Start Menu

**Disable Shut Down Button:**
- **Registry Path:** `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer`
- **Property:** `Start_ShowShutdown`
- **Expected Value:** `0` (DWord) - Disables shutdown button

**Remove Power Button from Start Menu:**
- **Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer`
- **Property:** `NoStartMenuPowerButton`
- **Expected Value:** `1` (DWord) - Removes Power button from Start Menu

**Disable Sleep:**
- **Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab`
- **Properties:** `ACSettingIndex`, `DCSettingIndex`
- **Expected Value:** `0` (DWord) for both - Disables sleep on AC and battery

**Disable Hibernate:**
- **Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\29f6c1db-86da-48c5-9fdb-f2b67b1f44da`
- **Properties:** `ACSettingIndex`, `DCSettingIndex`
- **Expected Value:** `0` (DWord) for both - Disables hibernate on AC and battery
- **Note:** Also check `powercfg /hibernate` - should show "Hibernation is disabled"

---

### 4. FSLogix Tray Startup (`configure-fslogix-tray-startup.ps1`)

**Registry Path:** `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`
- **Property:** `FSLogixTray`
- **Expected Value:** `C:\Program Files\FSLogix\Apps\frxtray.exe` (String)

**Verification:**
- Check that `frxtray.exe` exists at: `C:\Program Files\FSLogix\Apps\frxtray.exe`
- The tray icon should appear in the system tray when users log in

---

### 5. Windows Installer RDS Compatibility (`configure-windows-installer-rds-compatibility.ps1`)

**Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\Application Compatibility`
- **Property:** `DisableMsi`
- **Expected Value:** `1` (DWord) - Enables "Turn off Windows Installer RDS Compatibility" policy

**GPO Equivalent:**
- Computer Configuration > Administrative Templates > Windows Components > Remote Desktop Services > Remote Desktop Session Host > Application Compatibility > Turn off Windows Installer RDS Compatibility

---

### 6. MDM Enrollment (`enable-mdm-enrollment.ps1`)

**MDM Enrollment Settings:**
- **Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM`

| Property | Expected Value | Description |
|----------|----------------|-------------|
| `AutoEnrollMDM` | `1` (DWord) | Enables automatic MDM enrollment |
| `UseAADCredentialType` | `0` (DWord) | Uses Device Credential (recommended for AVD) |

**Workplace Join (if enabled):**
- **Registry Path:** `HKLM:\SOFTWARE\Microsoft\Windows Settings\WorkPlaceJoin`
- **Property:** `BlockAADWorkplaceJoin`
- **Expected Value:** `0` (DWord) - Allows Workplace Join (if `-EnableWorkplaceJoin $true` was used)

**Verification:**
- Check enrollment status in Azure Portal > Microsoft Intune > Devices
- Device should show as "Enrolled" in Intune

---

## Manual Verification Steps

### Using Registry Editor (regedit.exe)

1. Press `Win + R`, type `regedit`, press Enter
2. Navigate to each registry path listed above
3. Verify the properties and values match the expected values

### Using PowerShell

```powershell
# Example: Check OneDrive SilentAccountConfig
$path = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
$value = Get-ItemProperty -Path $path -Name "SilentAccountConfig" -ErrorAction SilentlyContinue
if ($value.SilentAccountConfig -eq 1) {
    Write-Host "✓ OneDrive SilentAccountConfig is enabled" -ForegroundColor Green
} else {
    Write-Host "✗ OneDrive SilentAccountConfig is NOT enabled" -ForegroundColor Red
}
```

### Using Group Policy Results (gpresult)

If you want to verify that GPOs are NOT overriding these settings:

```powershell
# Run as Administrator
gpresult /h gpresult.html
```

Then open `gpresult.html` and check:
- **Computer Configuration** > **Administrative Templates** - Should NOT show conflicting policies
- **Registry** section - Check for any conflicting registry settings

---

## Common Issues and Troubleshooting

### Settings Not Applied

1. **Check script execution:** Verify scripts ran successfully (check logs)
2. **Check permissions:** Scripts must run as Administrator
3. **Check registry path exists:** Some paths are created by the scripts
4. **Check for GPO conflicts:** GPOs can override registry settings

### Settings Overridden by GPO

If settings are being overridden by Group Policy:

1. Check `gpresult /h gpresult.html` for conflicting policies
2. Either:
   - Remove the conflicting GPO, OR
   - Ensure the GPO is configured to match the script settings

### Settings Not Taking Effect

Some settings require:
- **User logoff/logon** - For user-specific settings (OneDrive, FSLogix tray)
- **System restart** - For system-level settings (MDM enrollment, power options)
- **Application restart** - For Outlook settings (restart Outlook)

---

## Quick Check Script

Save this as `verify-cit-settings.ps1` and run it to check all settings:

```powershell
# Run as Administrator
# Verify all CIT script settings

$allChecks = @(
    @{Name="OneDrive SilentAccountConfig"; Path="HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"; Property="SilentAccountConfig"; Expected=1},
    @{Name="OneDrive Startup"; Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Property="OneDrive"; Expected="*OneDrive.exe*"},
    @{Name="FSLogix RoamIdentity"; Path="HKLM:\SOFTWARE\FSLogix\Profiles"; Property="RoamIdentity"; Expected=1},
    @{Name="Outlook Cached Mode"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode"; Property="Enable"; Expected=1},
    @{Name="Outlook Sync Window"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode"; Property="SyncWindowSetting"; Expected=3},
    @{Name="Power Options - NoClose"; Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Property="NoClose"; Expected=1},
    @{Name="FSLogix Tray"; Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Property="FSLogixTray"; Expected="*frxtray.exe*"},
    @{Name="Windows Installer RDS"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\Application Compatibility"; Property="DisableMsi"; Expected=1},
    @{Name="MDM AutoEnroll"; Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM"; Property="AutoEnrollMDM"; Expected=1}
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CIT Settings Verification" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0

foreach ($check in $allChecks) {
    Write-Host "$($check.Name)..." -NoNewline -ForegroundColor Yellow
    
    if (Test-Path $check.Path) {
        $value = Get-ItemProperty -Path $check.Path -Name $check.Property -ErrorAction SilentlyContinue
        
        if ($value) {
            $actualValue = $value.$($check.Property)
            
            if ($check.Expected -is [string] -and $check.Expected -like "*") {
                # Pattern match
                if ($actualValue -like $check.Expected) {
                    Write-Host " ✓" -ForegroundColor Green
                    $passed++
                } else {
                    Write-Host " ✗ (Expected: $($check.Expected), Got: $actualValue)" -ForegroundColor Red
                    $failed++
                }
            } else {
                # Exact match
                if ($actualValue -eq $check.Expected) {
                    Write-Host " ✓" -ForegroundColor Green
                    $passed++
                } else {
                    Write-Host " ✗ (Expected: $($check.Expected), Got: $actualValue)" -ForegroundColor Red
                    $failed++
                }
            }
        } else {
            Write-Host " ✗ (Property not found)" -ForegroundColor Red
            $failed++
        }
    } else {
        Write-Host " ✗ (Path does not exist)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Summary: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "==========================================" -ForegroundColor Cyan
```

---

## Notes

- All registry paths use `HKLM` (HKEY_LOCAL_MACHINE) for machine-wide settings
- Some settings may require user logoff/logon or system restart to take effect
- If using Intune for OneDrive configuration, the `configure-onedrive-auto-signin.ps1` script is optional
- FSLogix settings are only relevant if FSLogix is installed
- MDM enrollment only works for Azure AD joined or hybrid Azure AD joined devices

