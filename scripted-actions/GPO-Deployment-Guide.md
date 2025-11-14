# OneDrive GPO Deployment Guide

This guide covers multiple methods to deploy the OneDrive GPO, including scripting and backup import options.

## Prerequisites

- Domain Controller or machine with RSAT (Remote Server Administration Tools) installed
- Domain Admin or GPO creation permissions
- PowerShell execution policy allowing scripts
- Group Policy Management Console (GPMC) cmdlets available

---

## Method 1: PowerShell Script (Recommended)

### Step 1: Copy Scripts to Network Location

1. Copy `configure-onedrive-gpo-settings.ps1` to a network share accessible by all domain controllers:
   ```
   \\yourdomain.com\NETLOGON\Scripts\configure-onedrive-gpo-settings.ps1
   ```
   
   Or create a shared folder:
   ```
   \\yourdomain.com\Scripts\configure-onedrive-gpo-settings.ps1
   ```

### Step 2: Run GPO Creation Script

On your Domain Controller, run:

```powershell
# Basic usage (creates GPO, you'll link manually)
.\create-onedrive-gpo.ps1

# With automatic OU linking
.\create-onedrive-gpo.ps1 -TargetOU "OU=AVD Session Hosts,DC=contoso,DC=com" -LinkGPO

# Specify custom script path
.\create-onedrive-gpo.ps1 -ScriptPath "\\contoso.com\NETLOGON\Scripts\configure-onedrive-gpo-settings.ps1"
```

### Step 3: Link GPO to OU (if not done automatically)

1. Open Group Policy Management Console (`gpmc.msc`)
2. Navigate to your AVD Session Host OU
3. Right-click OU → Link an Existing GPO
4. Select "AVD - OneDrive & SharePoint Settings"
5. Click OK

### Step 4: Verify

Run on a test machine:
```powershell
gpupdate /force
```

Check registry:
```powershell
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
```

---

## Method 2: Import GPO from Backup

### Step 1: Export GPO (on source DC)

If you've already created the GPO on one DC and want to import it elsewhere:

```powershell
# Export the GPO
.\export-onedrive-gpo.ps1

# Or specify custom path
.\export-onedrive-gpo.ps1 -BackupPath "C:\GPO-Backups"
```

This creates a backup folder with the GPO export.

### Step 2: Copy Backup Folder

Copy the entire backup folder to the target Domain Controller:
```
GPO-Backup\
  └── {GUID}\
      ├── gpo.xml
      ├── gpreport.xml
      └── ...
```

### Step 3: Import GPO (on target DC)

**Option A: Using PowerShell**

```powershell
# Get backup ID
$backups = Get-GPOBackup -Path "C:\GPO-Backup"
$backup = $backups | Where-Object { $_.DisplayName -eq "AVD - OneDrive & SharePoint Settings" } | Sort-Object BackupTime -Descending | Select-Object -First 1

# Import GPO
Import-GPO -BackupId $backup.Id -Path "C:\GPO-Backup" -TargetName "AVD - OneDrive & SharePoint Settings" -CreateIfNeeded
```

**Option B: Using Group Policy Management Console**

1. Open Group Policy Management Console
2. Right-click "Group Policy Objects" → Import Settings
3. Click Next → Browse to backup folder
4. Select the backup → Next
5. Choose import options → Next
6. Review settings → Next → Finish

### Step 4: Update Script Path

After importing, you may need to update the startup script path:

1. Edit the imported GPO
2. Navigate to: `Computer Configuration` → `Policies` → `Windows Settings` → `Scripts` → `Startup`
3. Update script path to match your environment

### Step 5: Link GPO

Link the imported GPO to your AVD Session Host OU (same as Method 1, Step 3).

---

## Method 3: Manual GPO Creation (If Scripts Don't Work)

If you don't have permissions to run scripts, you can create the GPO manually:

### Step 1: Create GPO

1. Open Group Policy Management Console
2. Right-click "Group Policy Objects" → New
3. Name: `AVD - OneDrive & SharePoint Settings`
4. Click OK

### Step 2: Configure Startup Script

1. Right-click GPO → Edit
2. Navigate to: `Computer Configuration` → `Policies` → `Windows Settings` → `Scripts` → `Startup`
3. Double-click "Startup"
4. Click "Add" → Browse
5. Navigate to script location (must be network path accessible by all DCs)
6. Select `configure-onedrive-gpo-settings.ps1`
7. Click OK

### Step 3: Enable PowerShell Execution

1. In GPO Editor, navigate to: `Computer Configuration` → `Administrative Templates` → `Windows Components` → `Windows PowerShell`
2. Double-click "Turn on Script Execution"
3. Select "Enabled"
4. Set "Execution Policy" to "Allow all scripts"
5. Click OK

### Step 4: Link GPO

Link to your AVD Session Host OU (same as Method 1, Step 3).

---

## Troubleshooting

### "Cannot add script" Error

**Problem:** Don't have permission to add scripts to GPO

**Solutions:**
1. Use Method 1 (PowerShell script) - may work even if GUI doesn't
2. Ask Domain Admin to add script
3. Use Method 2 (backup import) - import from a DC where it was created
4. Use Method 3 (manual) but have admin copy script to SYSVOL first

### Script Not Running

**Check:**
1. Script path is accessible from target machines (use UNC path)
2. PowerShell execution policy is enabled in GPO
3. Script exists at specified path
4. GPO is linked to correct OU
5. Run `gpupdate /force` on target machine

### GPO Not Applying

**Check:**
1. GPO is linked to correct OU
2. Computer objects are in the OU
3. GPO is not blocked or disabled
4. No conflicting GPOs with higher precedence
5. Run `gpresult /h gpresult.html` to see applied policies

### PowerShell Module Not Found

**Solution:**
```powershell
# Install RSAT on Windows 10/11
Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

# Or install on Server
Install-WindowsFeature -Name GPMC
```

---

## Verification Commands

### Check GPO Created

```powershell
Get-GPO -Name "AVD - OneDrive & SharePoint Settings"
```

### Check GPO Linked

```powershell
Get-GPInheritance -Target "OU=AVD Session Hosts,DC=contoso,DC=com"
```

### Check Script Configured

```powershell
Get-GPStartupScript -Name "AVD - OneDrive & SharePoint Settings"
```

### Test on Target Machine

```powershell
# Force policy update
gpupdate /force

# Check registry settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"

# Check if script ran (check logs)
Get-Content "C:\Windows\Temp\*.log" | Select-String "OneDrive"
```

---

## Files Included

- `create-onedrive-gpo.ps1` - Creates GPO with startup script
- `export-onedrive-gpo.ps1` - Exports GPO to backup file
- `configure-onedrive-gpo-settings.ps1` - The actual OneDrive configuration script
- `GPO-OneDrive-Settings-Registry.reg` - Registry file (for reference)

---

## Quick Start (Recommended)

1. Copy `configure-onedrive-gpo-settings.ps1` to `\\yourdomain.com\NETLOGON\Scripts\`
2. Run `.\create-onedrive-gpo.ps1` on Domain Controller
3. Link GPO to AVD Session Host OU in GPMC
4. Run `gpupdate /force` on test machine
5. Verify registry settings applied

Done! ✅

