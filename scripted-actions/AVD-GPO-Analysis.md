# AVD GPO Settings Analysis

**Generated:** 2025-11-10  
**Total GPOs Analyzed:** 7

---

## Summary by GPO

### 1. **AVD: System Optimizations**

**Computer Configuration:**
- ✅ **Allow time zone redirection:** Enabled
- ✅ **Do not set default client printer to be default printer in a session:** Enabled
- ✅ **Allow Cloud Search:** Enabled
- ❌ **Allow Cortana:** Disabled
- ❌ **Allow Cortana above lock screen:** Disabled
- ❌ **Allow search and Cortana to use location:** Disabled
- ❌ **Do not allow web search:** Enabled
- ❌ **Don't search the web or display web results in Search:** Enabled
- ❌ **Don't search the web or display web results in Search over metered connections:** Enabled
- ❌ **Allow Windows Ink Workspace:** Disabled

**User Configuration:**
- ❌ **Enable mail logging (troubleshooting):** Disabled
- ✅ **Intranet Sites: Include all network paths (UNCs):** Enabled
- ❌ **Show security warning for potentially unsafe files:** Enabled

**Notes:** Registry settings present but not extracted (XML parsing issue). This GPO appears to optimize Windows search behavior and disable Cortana for AVD.

---

### 2. **AVD-CachedExchangeMode**

**Computer Configuration:**
- ✅ **Configure user Group Policy loopback processing mode:** Enabled (Merge mode)

**User Configuration:**
- ✅ **RPC/HTTP Connection Flags:** Enabled
- ✅ **Cached Exchange Mode:** Enabled
- ✅ **Cached Exchange Mode Sync Settings:** Enabled
- ❌ **Download Public Folder Favorites:** Disabled (reduces storage)
- ✅ **Download shared non-mail folders:** Enabled
- ✅ **Use Cached Exchange Mode for new and existing Outlook profiles:** Enabled

**Analysis:** ✅ **Correctly configured** for AVD. Matches the settings documented in `AVD_GPO_DEPLOYMENT_GUIDE.md`.

**Notes:** Loopback processing is enabled, which means user policies apply to computer objects. This is correct for AVD session hosts.

---

### 3. **AVD-Turn Off Windows Installer RDS Compatibility**

**Computer Configuration:**
- ✅ **Turn off Windows Installer RDS Compatibility:** Enabled

**Analysis:** ✅ **Correctly configured**. This prevents Windows Installer from using per-user installation mode in RDS environments.

---

### 4. **AVD-Profiles**

**Computer Configuration:**
- ✅ **Delete local profile when FSLogix Profile should apply:** Enabled
- ✅ **Enabled:** Enabled (FSLogix Profiles)
- ✅ **Set Outlook cached mode on successful container attach:** Enabled
- ❌ **VHD location:** Disabled (should be configured with path)
- ✅ **Swap directory name components:** Enabled
- ✅ **Virtual disk type:** Enabled
- ✅ **Run these programs at user logon:** Enabled

**Analysis:** ⚠️ **Partially configured**. FSLogix is enabled, but:
- **VHD location is disabled** - This should be enabled with the path to your FSLogix storage (e.g., `\\scstfslavdproduks001.file.core.windows.net\avd-profiles`)
- Other settings appear correct

**Action Required:** Enable and configure the VHD location setting.

---

### 5. **AVD-MEMEnrollment**

**Computer Configuration:**
- ✅ **Enable automatic MDM enrollment using default Azure AD credentials:** Enabled

**Analysis:** ✅ **Correctly configured** for automatic Intune/MDM enrollment.

**Notes:** Registry settings present but not extracted (XML parsing issue).

---

### 6. **AVD-DesktopLockdown**

**Computer Configuration:**
- ✅ **Configure user Group Policy loopback processing mode:** Enabled (Merge mode)
- ✅ **Set time limit for active but idle Remote Desktop Services sessions:** Enabled
- ✅ **Set time limit for disconnected sessions:** Enabled

**User Configuration:**
- ✅ **Enable screen saver:** Enabled
- ✅ **Screen saver timeout:** Enabled
- ✅ **Remove and prevent access to the Shut Down, Restart, Sleep, and Hibernate commands:** Enabled
- ✅ **Prevent access to registry editing tools:** Enabled
- ✅ **Hide these specified drives in My Computer:** Enabled

**Analysis:** ✅ **Correctly configured** for AVD session host lockdown. All security and power restriction settings are in place.

**Notes:** Loopback processing is enabled, which is correct for applying user policies to session hosts.

---

### 7. **AVD-RegionalSettings**

**Computer Configuration:**
- Registry settings present but not extracted (XML parsing issue)

**User Configuration:**
- Registry settings present but not extracted (XML parsing issue)

**Analysis:** ⚠️ **Cannot fully analyze** - registry values not extracted. This GPO likely contains regional/locale settings (time zone, date format, etc.).

**Action Required:** Review the HTML report for this GPO to see the actual registry values.

---

## Overall Assessment

### ✅ **Well Configured:**
1. **AVD-CachedExchangeMode** - All Outlook settings correct
2. **AVD-Turn Off Windows Installer RDS Compatibility** - Correct
3. **AVD-MEMEnrollment** - MDM enrollment enabled
4. **AVD-DesktopLockdown** - All security restrictions in place

### ⚠️ **Needs Attention:**
1. **AVD-Profiles** - VHD location is disabled. Should be enabled with the FSLogix storage path.
2. **AVD-RegionalSettings** - Cannot verify due to XML parsing issue. Review HTML report manually.

### 📝 **Notes:**
- **Loopback Processing:** Both `AVD-CachedExchangeMode` and `AVD-DesktopLockdown` use loopback processing (Merge mode). This is correct for AVD.
- **Registry Values:** The comparison script has a limitation - it's not extracting registry key names and values from the XML. Use the HTML reports for detailed registry information.
- **System Optimizations:** The first GPO has many registry settings that aren't showing. Review the HTML report for full details.

---

## Recommendations

1. **Fix AVD-Profiles GPO:**
   - Enable "VHD location" setting
   - Configure with path: `\\scstfslavdproduks001.file.core.windows.net\avd-profiles`

2. **Review HTML Reports:**
   - Open the HTML reports for `AVD: System Optimizations` and `AVD-RegionalSettings` to see full registry settings
   - Verify all registry preferences are configured correctly

3. **Verify GPO Application:**
   - Run `gpresult /h gpresult.html` on an AVD session host
   - Confirm all GPOs are applying correctly
   - Check for any conflicts or overrides

4. **Improve Comparison Script:**
   - The XML parsing needs improvement to extract registry key paths and values
   - Consider using the HTML reports directly or improving the XML parsing logic

---

## GPO Precedence Order

Based on typical GPO linking order (highest to lowest precedence):
1. AVD-DesktopLockdown (user restrictions)
2. AVD-CachedExchangeMode (Outlook settings)
3. AVD-Profiles (FSLogix)
4. AVD-MEMEnrollment (MDM)
5. AVD-RegionalSettings (locale)
6. AVD: System Optimizations (Windows optimizations)
7. AVD-Turn Off Windows Installer RDS Compatibility (RDS compatibility)

**Note:** Actual precedence depends on GPO link order in Active Directory. Check GPO link order in GPMC.

