# OneDrive GPO Deployment Guide

This guide explains how to deploy OneDrive and SharePoint settings as a Group Policy Object (GPO) instead of using Intune Configuration Policies.

## Overview

The deployment consists of two scripts:
1. **`configure-onedrive-gpo-settings.ps1`** - Configures OneDrive registry settings (runs on target machines)
2. **`create-onedrive-gpo.ps1`** - Creates the GPO and configures it to run the script at startup

## Prerequisites

- Domain Controller or machine with RSAT (Remote Server Administration Tools) installed
- Domain Admin or GPO creation permissions
- PowerShell execution policy allowing scripts
- Group Policy Management Console (GPMC) cmdlets available

---

## Step 1: Configure Tenant ID

**Before deploying, you MUST update the tenant ID for each client.**

1. Open `windows-scripts\configure-onedrive-gpo-settings.ps1`
2. Find this section near the top:
   ```powershell
   # ============================================================================
   # CONFIGURATION: Tenant ID
   # ============================================================================
   $tenantId = "2106f27c-fb2e-4787-b960-3dc6aac54826"  # Cheesman Tenant - CHANGE THIS FOR OTHER CLIENTS
   # ============================================================================
   ```
3. Replace the tenant ID with the client's tenant ID
4. To find tenant ID:
   - Azure Portal → Azure Active Directory → Overview → Tenant ID
   - Or run: `(Get-AzContext).Tenant.Id`

**Example for different client:**
```powershell
$tenantId = "12345678-1234-1234-1234-123456789abc"  # Client Name Tenant
```

---

## Step 2: Copy Script to Network Location

Copy `configure-onedrive-gpo-settings.ps1` to a network share accessible by all domain controllers:

**Option A: NETLOGON Share (Recommended)**
```
\\yourdomain.com\NETLOGON\Scripts\configure-onedrive-gpo-settings.ps1
```

**Option B: Custom Network Share**
```
\\yourdomain.com\Scripts\configure-onedrive-gpo-settings.ps1
```

---

## Step 3: Create the GPO

On your Domain Controller, run:

```powershell
# Basic usage - creates GPO, you'll link it manually
.\create-onedrive-gpo.ps1

# With automatic OU linking
.\create-onedrive-gpo.ps1 -TargetOU "OU=AVD Session Hosts,DC=contoso,DC=com" -LinkGPO

# Specify custom script path
.\create-onedrive-gpo.ps1 -ScriptPath "\\contoso.com\NETLOGON\Scripts\configure-onedrive-gpo-settings.ps1"
```

**What the script does:**
- Creates GPO: "AVD - OneDrive & SharePoint Settings"
- Copies script to GPO folder
- Registers script as PowerShell startup script
- Enables PowerShell script execution

---

## Step 4: Link GPO to OU

If not auto-linked, link the GPO manually:

1. Open Group Policy Management Console (`gpmc.msc`)
2. Navigate to your AVD Session Host OU
3. Right-click OU → **Link an Existing GPO**
4. Select **"AVD - OneDrive & SharePoint Settings"**
5. Click **OK**

---

## Step 5: Verify Deployment

### Verify in GPO Editor

1. Right-click GPO → **Edit**
2. Navigate to: `Computer Configuration` → `Policies` → `Windows Settings` → `Scripts` → `Startup`
3. Click **"PowerShell Scripts"** tab
4. Verify `configure-onedrive-gpo-settings.ps1` is listed

### Verify on Target Machine

**After reboot or manual script execution:**

```powershell
# Check registry settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"

# Should show:
# AutoMountTeamSites          : 1
# DehydrateSyncedTeamSites    : 1
# SilentAccountConfig          : 1
# FilesOnDemandEnabled         : 1

# Check KFM settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\KFMSilentOptIn"

# Should show:
# TenantId                     : <your-tenant-id>
# KFMOptInWithWizard           : 0
```

---

## Settings Configured

| Setting | Registry Path | Value | Description |
|---------|---------------|-------|-------------|
| Auto-mount Team Sites | `HKLM\SOFTWARE\Policies\Microsoft\OneDrive\AutoMountTeamSites` | `1` | Auto-mounts all SharePoint sites user has access to |
| Dehydrate synced Team Sites | `HKLM\SOFTWARE\Policies\Microsoft\OneDrive\DehydrateSyncedTeamSites` | `1` | Saves storage by dehydrating synced sites |
| Silent account config | `HKLM\SOFTWARE\Policies\Microsoft\OneDrive\SilentAccountConfig` | `1` | Auto-signs in with Windows credentials |
| Files On Demand | `HKLM\SOFTWARE\Policies\Microsoft\OneDrive\FilesOnDemandEnabled` | `1` | Enables files on-demand |
| KFM Tenant ID | `HKLM\SOFTWARE\Policies\Microsoft\OneDrive\KFMSilentOptIn\TenantId` | `<tenant-id>` | Tenant ID for Known Folder Move |
| KFM Silent Opt-in | `HKLM\SOFTWARE\Policies\Microsoft\OneDrive\KFMSilentOptIn\KFMOptInWithWizard` | `0` | Silent opt-in (no wizard) |

---

## When Settings Take Effect

- **Startup scripts run at system startup** (not during `gpupdate`)
- Settings are applied when:
  - System reboots (startup script runs automatically), OR
  - Script is run manually (no reboot needed)

**To apply immediately without reboot:**
```powershell
# Run script manually on target machine
C:\Windows\System32\GroupPolicy\Machine\Scripts\Startup\configure-onedrive-gpo-settings.ps1
```

---

## Troubleshooting

### Script Not Showing in GPO Editor

1. Refresh GPO Editor (press F5)
2. Check **"PowerShell Scripts"** tab (not "Scripts" tab)
3. Verify `psscripts.ini` exists in GPO folder:
   ```
   \\domain.com\SYSVOL\domain.com\Policies\{GPO-ID}\Machine\Scripts\Startup\psscripts.ini
   ```

### Settings Not Applied

1. **Check script ran:** Look for script execution logs
2. **Check GPO applied:** Run `gpresult /h gpresult.html` on target machine
3. **Check registry:** Verify registry values exist
4. **Restart OneDrive:** Close and restart OneDrive application

### PowerShell Module Not Found

```powershell
# Install RSAT on Windows 10/11
Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

# Or install on Server
Install-WindowsFeature -Name GPMC
```

---

## Files Included

- **`windows-scripts\configure-onedrive-gpo-settings.ps1`** - OneDrive configuration script (modify tenant ID here)
- **`create-onedrive-gpo.ps1`** - GPO creation script
- **`OneDrive-GPO-Deployment-Guide.md`** - This guide

---

## Quick Reference: Changing Tenant ID

**File to edit:** `windows-scripts\configure-onedrive-gpo-settings.ps1`

**Line to change:** Line 38 (approximately)

**Change from:**
```powershell
$tenantId = "2106f27c-fb2e-4787-b960-3dc6aac54826"  # Cheesman Tenant
```

**Change to:**
```powershell
$tenantId = "NEW-TENANT-ID-HERE"  # Client Name Tenant
```

**Then:** Re-copy script to network location and recreate GPO (or update existing GPO script)

---

## Additional Resources

- [OneDrive Group Policy Settings](https://learn.microsoft.com/en-us/sharepoint/use-group-policy)
- [Group Policy Management Console](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/group-policy-management-console)

