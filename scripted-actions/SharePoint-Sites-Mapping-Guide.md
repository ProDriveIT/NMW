# OneDrive SharePoint Sites Auto-Mount Guide

## Overview

When `AutoMountTeamSites` is enabled, OneDrive automatically syncs **all** SharePoint/Teams sites that each user has access to. **User permissions are fully enforced** - users will only see and sync sites they have permission to access.

## How It Works

1. **Permission-Based Sync**: OneDrive queries Microsoft Graph/SharePoint to determine which sites each user can access
2. **Automatic Discovery**: Sites are automatically discovered and synced based on user permissions
3. **Security Enforced**: Users cannot sync sites they don't have access to, even if they know the URL
4. **Dynamic Updates**: As permissions change, OneDrive automatically reflects those changes

## Configuration

The script `configure-onedrive-gpo-settings.ps1` configures:

- **AutoMountTeamSites** = `1` (Enabled)
- **No site list configured** = All accessible sites will sync

This is the recommended configuration for most environments.

## Permission Levels

OneDrive will sync sites where users have:
- ✅ Read access or higher
- ✅ Member or Owner role in Teams
- ✅ Access via SharePoint group membership
- ✅ Direct permissions

OneDrive will **not** sync sites where:
- ❌ User has no access
- ❌ Access was revoked
- ❌ User is explicitly denied access

## Verification

### Check What Sites Are Syncing

**Via OneDrive Settings:**
1. Right-click OneDrive icon → Settings
2. Go to **Account** tab
3. View **Sync and backup** section
4. Only sites the user has access to will appear

**Via PowerShell:**
```powershell
# Check OneDrive sync folder
Get-ChildItem "$env:USERPROFILE\OneDrive - YourTenant" -Directory
```

**Via Registry:**
```powershell
# Check if auto-mount is enabled
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Name "AutoMountTeamSites"
```

## Benefits

✅ **Automatic**: No manual configuration needed  
✅ **Secure**: Permissions are enforced by SharePoint/OneDrive  
✅ **Dynamic**: Automatically adapts as permissions change  
✅ **User-Friendly**: Users get access to sites they need automatically  
✅ **Compliant**: Respects all SharePoint security settings  

## Related Settings

- **DehydrateSyncedTeamSites** - Recommended to enable to save storage space
- **FilesOnDemandEnabled** - Recommended to enable for better storage management
- **SilentAccountConfig** - Enables automatic OneDrive sign-in

## Troubleshooting

### Sites Not Syncing

1. **Check user permissions** - User must have at least Read access to the site
2. **Verify OneDrive version** - Ensure OneDrive is up to date
3. **Restart OneDrive** - Close and restart OneDrive application
4. **User logoff/logon** - Some settings require user logoff/logon to take effect

### Too Many Sites Syncing

If users have access to many sites and storage is a concern:
- Enable **DehydrateSyncedTeamSites** (already configured)
- Enable **FilesOnDemandEnabled** (already configured)
- Consider using **AutoMountTeamSitesList** to limit to specific sites (see advanced section below)

---

## Advanced: Limiting to Specific Sites

If you need to limit syncing to specific SharePoint sites only (not recommended for most environments):

### Option 1: PowerShell Script

Edit `configure-onedrive-gpo-settings.ps1` and add:

```powershell
# Add this after $tenantId definition
$sharePointSites = @(
    "https://yourtenant.sharepoint.com/sites/SiteName1",
    "https://yourtenant.sharepoint.com/sites/SiteName2"
)

# Then modify the AutoMountTeamSites section to include:
if ($sharePointSites.Count -gt 0) {
    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Policies\Microsoft\OneDrive", $true)
    if ($null -eq $regKey) {
        $regKey = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey("SOFTWARE\Policies\Microsoft\OneDrive", $true)
    }
    $regKey.SetValue("AutoMountTeamSitesList", $sharePointSites, [Microsoft.Win32.RegistryValueKind]::MultiString)
    $regKey.Close()
}
```

### Option 2: GPO Registry Preferences

1. Open Group Policy Management Console
2. Navigate to: `Computer Configuration` → `Preferences` → `Windows Settings` → `Registry`
3. Create Registry Item:
   - **Hive:** HKEY_LOCAL_MACHINE
   - **Key Path:** `SOFTWARE\Policies\Microsoft\OneDrive`
   - **Value name:** `AutoMountTeamSitesList`
   - **Value type:** REG_MULTI_SZ
   - **Value data:** Enter site URLs (one per line)

**Note:** Limiting to specific sites is typically only needed for:
- Performance optimization (very large number of sites)
- Compliance requirements
- Storage management in specific scenarios

For most environments, the default "all accessible sites" approach is recommended.

---

## Additional Resources

- [OneDrive Group Policy Settings](https://learn.microsoft.com/en-us/sharepoint/use-group-policy)
- [OneDrive Sync Client Settings](https://learn.microsoft.com/en-us/sharepoint/use-group-policy#onedrive-sync-client-settings)
- [SharePoint Site Permissions](https://learn.microsoft.com/en-us/sharepoint/understanding-permission-levels)
