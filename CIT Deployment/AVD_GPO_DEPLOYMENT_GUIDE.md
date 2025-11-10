# AVD Group Policy Deployment Guide

This guide documents the Group Policy Objects (GPOs) that should be deployed to AVD session hosts. These settings were previously configured via scripts but are better managed as GPOs for centralized enforcement and automatic reapplication.

## Overview

These GPOs should be linked to the **Organizational Unit (OU)** containing your AVD session host computer objects. The recommended OU path format is:
```
OU=AVD,OU=Azure Active Directory,OU=Admin Accounts,OU=Cheesman,DC=ca,DC=local
```

**Important:** GPOs apply to **Computer objects**, not User objects. Ensure the GPOs are linked to the correct OU and that session host VMs are in that OU.

---

## GPO 1: AVD Session Host - Outlook Cached Exchange Mode

**GPO Name:** `AVD Session Host - Outlook Cached Exchange Mode`

**Purpose:** Configures Outlook to use Cached Exchange Mode with AVD-optimized settings to balance performance and storage costs.

### GPO Path:
```
Computer Configuration
└── Administrative Templates
    └── Microsoft Office 2016
        └── Outlook
            └── Account Settings
                └── Exchange
```

### Settings to Configure:

1. **Use Cached Exchange Mode**
   - **Path:** `Account Settings > Exchange > Use Cached Exchange Mode`
   - **Setting:** Enabled
   - **Registry:** `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode\Enable = 1`

2. **Download shared non-mail folders**
   - **Path:** `Account Settings > Exchange > Download shared non-mail folders`
   - **Setting:** Enabled (default: Yes)
   - **Registry:** `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode\DownloadSharedAttachments = 1`

3. **Download public folder favorites**
   - **Path:** `Account Settings > Exchange > Download public folder favorites`
   - **Setting:** Disabled (to reduce storage)
   - **Registry:** `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode\DownloadPublicFolderFavorites = 0`

4. **Cached Exchange Mode sync settings**
   - **Path:** `Account Settings > Exchange > Cached Exchange Mode sync settings`
   - **Setting:** Enabled
   - **Configure:** 
     - **Sync slider setting:** `3 months` (recommended for AVD)
     - **Calendar sync slider setting:** `60 days` (or your preferred value)
   - **Registry:** 
     - `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode\SyncWindowSetting = 3`
     - `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode\CalendarSyncWindowSettingDays = 60`
     - `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode\CalendarSyncWindowSetting = 0` (Full calendar sync)

5. **Use Cached Exchange Mode for new and existing Outlook profiles**
   - **Path:** `Account Settings > Exchange > Use Cached Exchange Mode for new and existing Outlook profiles`
   - **Setting:** Enabled
   - **Registry:** `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode\CachedModeForNewProfiles = 1`

6. **RPC/HTTP connection settings**
   - **Path:** `Account Settings > Exchange > RPC/HTTP connection settings`
   - **Setting:** Enabled
   - **Configure:**
     - **Enable RPC encryption:** Enabled
     - **RPC/HTTP connection timeout:** `30 seconds`
   - **Registry:**
     - `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\RPC\EnableRPCEncryption = 1`
     - `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\RPC\RpcHttpConnectionTimeout = 30`

7. **Disable fast shutdown**
   - **Path:** `Outlook Options > General > Disable fast shutdown`
   - **Setting:** Enabled
   - **Registry:** `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Options\General\DisableFastShutdown = 1`

### Verification:
```powershell
# Check registry values
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode" | Select-Object Enable, SyncWindowSetting, CalendarSyncWindowSettingDays
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\RPC" | Select-Object EnableRPCEncryption, RpcHttpConnectionTimeout
```

---

## GPO 2: AVD Session Host - Power Options Restrictions

**GPO Name:** `AVD Session Host - Power Options Restrictions`

**Purpose:** Removes and prevents access to Shut Down, Restart, Sleep, and Hibernate commands to prevent users from accidentally shutting down session host VMs.

### GPO Path:
```
Computer Configuration
└── Administrative Templates
    └── Start Menu and Taskbar
```

### Settings to Configure:

1. **Remove and prevent access to the Shut Down, Restart, Sleep, and Hibernate commands**
   - **Path:** `Start Menu and Taskbar > Remove and prevent access to the Shut Down, Restart, Sleep, and Hibernate commands`
   - **Setting:** Enabled
   - **Registry:** `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoClose = 1`

2. **Remove the Power Button from the Start Menu**
   - **Path:** `Start Menu and Taskbar > Remove the Power Button from the Start Menu`
   - **Setting:** Enabled
   - **Registry:** `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer\NoStartMenuPowerButton = 1`

3. **Disable Shut Down button**
   - **Path:** `Start Menu and Taskbar > Disable Shut Down button` (if available)
   - **Setting:** Enabled
   - **Registry:** `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Start_ShowShutdown = 0`

### Additional Power Settings (via Registry Preferences or Power Policy):

4. **Disable Sleep**
   - **Registry:** `HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab`
   - **Values:**
     - `ACSettingIndex = 0`
     - `DCSettingIndex = 0`

5. **Disable Hibernate**
   - **Registry:** `HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\29f6c1db-86da-48c5-9fdb-f2b67b1f44da`
   - **Values:**
     - `ACSettingIndex = 0`
     - `DCSettingIndex = 0`
   - **Note:** Also run `powercfg /hibernate off` via GPO startup script or manually

### Alternative: Use Registry Preferences

If the Administrative Templates don't have all the settings, use **Registry Preferences**:

1. **Computer Configuration > Preferences > Windows Settings > Registry**
2. Create registry items for:
   - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoClose = 1 (DWORD)`
   - `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer\NoStartMenuPowerButton = 1 (DWORD)`
   - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Start_ShowShutdown = 0 (DWORD)`

### Verification:
```powershell
# Check registry values
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" | Select-Object NoClose, Start_ShowShutdown
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" | Select-Object NoStartMenuPowerButton
```

---

## GPO 3: AVD Session Host - Windows Installer RDS Compatibility

**GPO Name:** `AVD Session Host - Windows Installer RDS Compatibility`

**Purpose:** Prevents Windows Installer from applying RDS compatibility fixes, which can cause issues with applications in AVD environments.

### GPO Path:
```
Computer Configuration
└── Administrative Templates
    └── Windows Components
        └── Remote Desktop Services
            └── Remote Desktop Session Host
                └── Application Compatibility
```

### Settings to Configure:

1. **Turn off Windows Installer RDS Compatibility**
   - **Path:** `Application Compatibility > Turn off Windows Installer RDS Compatibility`
   - **Setting:** Enabled
   - **Registry:** `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\Application Compatibility\DisableMsi = 1`

### Verification:
```powershell
# Check registry value
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\Application Compatibility" | Select-Object DisableMsi
```

---

## Deploying GPOs via Script

Yes, you can deploy GPOs via PowerShell script on the Domain Controller. Here are the methods:

### Method 1: Using Group Policy Management Console (GPMC) PowerShell Module

**Prerequisites:**
- Run on Domain Controller or management machine with RSAT installed
- Install GPMC: `Install-WindowsFeature -Name GPMC`
- Import module: `Import-Module GroupPolicy`

**Example Script:**
```powershell
# Import GPMC module
Import-Module GroupPolicy

# Define OU path
$OUPath = "OU=AVD,OU=Azure Active Directory,OU=Admin Accounts,OU=Cheesman,DC=ca,DC=local"

# Create GPOs
$gpos = @(
    @{Name="AVD Session Host - Outlook Cached Exchange Mode"; Comment="Configures Outlook Cached Exchange Mode for AVD"},
    @{Name="AVD Session Host - Power Options Restrictions"; Comment="Removes power options from Start Menu for AVD session hosts"},
    @{Name="AVD Session Host - Windows Installer RDS Compatibility"; Comment="Disables Windows Installer RDS Compatibility for AVD"}
)

foreach ($gpo in $gpos) {
    # Check if GPO exists
    $existingGPO = Get-GPO -Name $gpo.Name -ErrorAction SilentlyContinue
    
    if (-not $existingGPO) {
        Write-Host "Creating GPO: $($gpo.Name)" -ForegroundColor Yellow
        New-GPO -Name $gpo.Name -Comment $gpo.Comment
    } else {
        Write-Host "GPO already exists: $($gpo.Name)" -ForegroundColor Green
    }
    
    # Link GPO to OU
    Write-Host "Linking GPO to OU: $OUPath" -ForegroundColor Yellow
    New-GPLink -Name $gpo.Name -Target $OUPath -ErrorAction SilentlyContinue
}

Write-Host "GPOs created and linked successfully!" -ForegroundColor Green
```

### Method 2: Using LGPO.exe (Local Group Policy Object Utility)

**Note:** LGPO.exe is for local policies, not domain policies. For domain GPOs, use Method 1 or Method 3.

### Method 3: Using Registry Preferences + GPO Backup/Restore

1. Create GPOs manually in GPMC
2. Export GPOs: `Backup-GPO -Name "GPO Name" -Path "C:\GPOBackup"`
3. Import on another DC: `Import-GPO -BackupId <GUID> -Path "C:\GPOBackup" -TargetName "GPO Name"`

### Method 4: Using ADMX Templates + Registry Settings

For settings not available in Administrative Templates, use **Registry Preferences**:

```powershell
# Example: Set registry preference via GPO
# This requires creating the GPO first, then setting registry preferences
# Best done via GPMC GUI or using Set-GPRegistryValue cmdlet

Import-Module GroupPolicy

# Set registry value in GPO
Set-GPRegistryValue -Name "AVD Session Host - Power Options Restrictions" `
    -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -ValueName "NoClose" `
    -Type DWord `
    -Value 1
```

### Recommended Approach

**For initial setup:** Use Method 1 (GPMC PowerShell) to create and link GPOs, then configure settings manually in GPMC or via `Set-GPRegistryValue`.

**For automation:** Create a comprehensive PowerShell script that:
1. Creates GPOs
2. Links GPOs to OU
3. Configures all registry settings via `Set-GPRegistryValue`
4. Sets Administrative Template policies (if available via cmdlets)

---

## Deployment Steps

### Step 1: Create GPOs
Run the PowerShell script (Method 1) on your Domain Controller to create and link the GPOs.

### Step 2: Configure GPO Settings
Configure the settings in each GPO using Group Policy Management Console:
1. Open **Group Policy Management** (`gpmc.msc`)
2. Navigate to each GPO
3. Right-click > **Edit**
4. Configure settings as documented above

### Step 3: Verify GPO Application
1. On an AVD session host, run: `gpupdate /force`
2. Restart the session host
3. Verify settings using the verification commands above

### Step 4: Test
1. Deploy a new session host
2. Verify GPOs apply automatically
3. Verify settings are enforced

---

## Troubleshooting

### GPOs Not Applying

1. **Check GPO Link:**
   ```powershell
   Get-GPInheritance -Target "OU=AVD,OU=Azure Active Directory,OU=Admin Accounts,OU=Cheesman,DC=ca,DC=local"
   ```

2. **Check GPO Status:**
   ```powershell
   Get-GPO -Name "AVD Session Host - Outlook Cached Exchange Mode" | Select-Object DisplayName, GpoStatus
   ```

3. **Force GPO Update:**
   ```powershell
   # On session host
   gpupdate /force
   ```

4. **Check GPO Results:**
   ```powershell
   # On session host
   gpresult /h gpresult.html
   ```

### Settings Not Taking Effect

- Some settings require **Outlook to be restarted**
- Some settings require **user logoff/logon**
- Some settings require **system restart**
- Check if settings are being overridden by other GPOs (higher precedence)

---

## Notes

- **OneDrive Configuration:** OneDrive auto-signin is managed via **Intune Configuration Profile**, not GPO. The script `configure-onedrive-auto-signin.ps1` has been removed.

- **FSLogix Tray:** The FSLogix tray startup script (`configure-fslogix-tray-startup.ps1`) remains as a script as it's a simple startup configuration better suited for CIT.

- **Edge Optimizations:** Edge optimization settings are documented separately (see Edge optimization settings below).

---

## Edge Optimization Settings (Reference)

For Microsoft Edge optimizations, configure these registry settings (can be done via GPO Registry Preferences):

**Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Edge`

| Setting | Value | Description |
|---------|-------|-------------|
| `SleepingTabsEnabled` | `1` (DWORD) | Enable Sleeping Tabs (reduces memory usage) |
| `StartupBoostEnabled` | `0` (DWORD) | Disable Startup Boost (reduces resource usage) |
| `BackgroundModeEnabled` | `0` (DWORD) | Disable Background Mode (prevents Edge running in background) |
| `EfficiencyMode` | `1` (DWORD) | Enable Efficiency Mode (reduces resource consumption) |
| `HideFirstRunExperience` | `1` (DWORD) | Hide First Run Experience (improves login performance) |
| `ShowRecommendationsEnabled` | `0` (DWORD) | Disable Recommendations (reduces background activity) |
| `WebWidgetAllowed` | `0` (DWORD) | Disable Web Widget (reduces background activity) |

**GPO Path (if available):**
```
Computer Configuration
└── Administrative Templates
    └── Microsoft Edge
```

If Administrative Templates are not available, use **Registry Preferences** to set these values.

