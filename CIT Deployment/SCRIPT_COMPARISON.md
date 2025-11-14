# CIT Guide Script Comparison

This document compares scripts listed in the CIT guide with scripts available in `windows-scripts/` folder.

## Scripts Listed in CIT Guide (Should be in Template)

### Currently in Guide (13 scripts):

1. ✅ `install-m365-apps.ps1`
2. ✅ `install-onedrive-per-machine.ps1`
3. ✅ `configure-outlook-cached-mode.ps1`
4. ✅ `enable-mdm-enrollment.ps1`
5. ✅ `configure-fslogix-tray-startup.ps1`
6. ✅ `install-fslogix-status-to-pd-scripts.ps1` (NEW - just added)
7. ✅ `configure-windows-installer-rds-compatibility.ps1`
8. ✅ `disable-power-options.ps1`
9. ✅ `optimize-microsoft-edge.ps1`
10. ✅ `install-winget.ps1`
11. ✅ `install-chrome-per-machine.ps1`
12. ✅ `install-adobe-reader-per-machine.ps1`
13. ✅ `install-datto-rmm-stewart-co.ps1`

### Mentioned in Reference Section (but not in template steps):

- `configure-onedrive-auto-signin.ps1` - Listed as alternative to Intune (not needed if using Intune)

---

## Scripts in windows-scripts/ Folder (32 total)

### ✅ Already in CIT Guide (13 scripts):
1. `install-m365-apps.ps1`
2. `install-onedrive-per-machine.ps1`
3. `configure-outlook-cached-mode.ps1`
4. `enable-mdm-enrollment.ps1`
5. `configure-fslogix-tray-startup.ps1`
6. `install-fslogix-status-to-pd-scripts.ps1` ⭐ NEW
7. `configure-windows-installer-rds-compatibility.ps1`
8. `disable-power-options.ps1`
9. `optimize-microsoft-edge.ps1`
10. `install-winget.ps1`
11. `install-chrome-per-machine.ps1`
12. `install-adobe-reader-per-machine.ps1`
13. `install-datto-rmm-stewart-co.ps1`

### ❌ NOT in CIT Guide (19 scripts):

#### **Should Consider Adding:**

1. **`install-powershell7.ps1`** ⭐ **RECOMMENDED**
   - **Why**: FSLogix Status script requires PowerShell 7.2+
   - **When**: Add BEFORE `install-fslogix-status-to-pd-scripts.ps1`
   - **Priority**: High - Required dependency

2. **`enable-screen-capture-protection.ps1`** ⭐ **RECOMMENDED**
   - **Why**: Security feature for AVD - prevents screen capture/recording
   - **When**: Add after domain join/MDM enrollment
   - **Priority**: Medium-High - Security best practice

3. **`install-microsoft-teams-new.ps1`** ⚠️ **CONDITIONAL**
   - **Why**: Built-in script installs Teams, but this might be newer version
   - **When**: Check if built-in script is sufficient
   - **Priority**: Low - Built-in script may be enough

4. **`configure-onedrive-gpo-settings.ps1`** ⚠️ **CONDITIONAL**
   - **Why**: Alternative to Intune for OneDrive settings
   - **When**: Only if NOT using Intune
   - **Priority**: Low - Intune is preferred method

#### **Client-Specific (Add as needed):**

5. **`install-datto-rmm-cheesmans.ps1`**
   - **Why**: Client-specific Datto RMM agent
   - **When**: For Cheesman client deployments
   - **Priority**: Client-specific

6. **`install-firefox-per-machine.ps1`**
   - **Why**: Installs Firefox browser
   - **When**: If client requires Firefox
   - **Priority**: Client-specific

7. **`install-lastpass-per-machine.ps1`**
   - **Why**: Installs LastPass password manager
   - **When**: If client requires LastPass
   - **Priority**: Client-specific

8. **`install-onvio-link-per-machine.ps1`**
   - **Why**: Installs Onvio Link application
   - **When**: If client requires Onvio
   - **Priority**: Client-specific

9. **`install-sage50-accounts.ps1`**
   - **Why**: Installs Sage 50 Accounts
   - **When**: If client requires Sage
   - **Priority**: Client-specific

10. **`install-xerox-workplace-cloud-client.ps1`**
    - **Why**: Installs Xerox Workplace Cloud client
    - **When**: If client requires Xerox printing solution
    - **Priority**: Client-specific

#### **Utility/Debugging Scripts (Not for CIT):**

11. **`analyze-fslogix-profile-size.ps1`**
    - **Why**: Analysis/debugging tool
    - **When**: Run manually, not during CIT build
    - **Priority**: N/A - Not for CIT

12. **`check-session-timeout-settings.ps1`**
    - **Why**: Verification/checking script
    - **When**: Run manually for verification
    - **Priority**: N/A - Not for CIT

13. **`cheesman-enrollment.ps1`**
    - **Why**: Client-specific enrollment script
    - **When**: Post-build, not during CIT
    - **Priority**: N/A - Runs post-domain-join

14. **`compare-avd-gpos.ps1`**
    - **Why**: Analysis/comparison tool
    - **When**: Run manually for analysis
    - **Priority**: N/A - Not for CIT

15. **`install-fslogix-status-script.ps1`**
    - **Why**: Installs to Program Files (we use `install-fslogix-status-to-pd-scripts.ps1` instead)
    - **When**: Not needed - replaced by PD-Scripts version
    - **Priority**: N/A - Superseded

16. **`install-interactive-checklist-shortcut.ps1`**
    - **Why**: Client-specific shortcut creation
    - **When**: If client requires interactive checklist
    - **Priority**: Client-specific

17. **`join-domain.ps1`**
    - **Why**: Domain join script
    - **When**: Handled by Azure Image Builder built-in action
    - **Priority**: N/A - Built-in handles this

18. **`pin-apps-to-taskbar-all-users.ps1`**
    - **Why**: Pins apps to taskbar
    - **When**: If client requires specific taskbar pins
    - **Priority**: Client-specific

19. **`run-cch-rollout-script.ps1`**
    - **Why**: Client-specific CCH rollout
    - **When**: For CCH client deployments
    - **Priority**: Client-specific

20. **`setup-cch-rollout-scheduled-task.ps1`**
    - **Why**: Sets up CCH scheduled task
    - **When**: For CCH client deployments
    - **Priority**: Client-specific

21. **`upload-cch-apps.ps1`**
    - **Why**: Uploads CCH apps
    - **When**: For CCH client deployments
    - **Priority**: Client-specific

22. **`upload-folder-to-c-drive.ps1`**
    - **Why**: Utility to upload folders
    - **When**: Client-specific use case
    - **Priority**: Client-specific

23. **`verify-cit-settings.ps1`**
    - **Why**: Verification script
    - **When**: Run manually after build
    - **Priority**: N/A - Not for CIT

24. **`Autopilot2_OnboardingScript.ps1`**
    - **Why**: Autopilot onboarding
    - **When**: Not applicable to AVD CIT
    - **Priority**: N/A - Not for AVD

---

## Recommendations

### ⭐ **High Priority - Should Add:**

1. **`install-powershell7.ps1`**
   - **Required** for FSLogix Status script
   - Add BEFORE script #6 (`install-fslogix-status-to-pd-scripts.ps1`)
   - **Action**: Add to CIT guide

2. **`enable-screen-capture-protection.ps1`**
   - Security best practice for AVD
   - Add after MDM enrollment
   - **Action**: Add to CIT guide

### ⚠️ **Medium Priority - Consider:**

3. **`install-microsoft-teams-new.ps1`**
   - Check if built-in Teams script is sufficient
   - If newer version needed, add this
   - **Action**: Evaluate need

### 📋 **Client-Specific - Add as Needed:**

- `install-datto-rmm-cheesmans.ps1` (for Cheesman client)
- `install-firefox-per-machine.ps1` (if Firefox needed)
- `install-lastpass-per-machine.ps1` (if LastPass needed)
- `install-onvio-link-per-machine.ps1` (if Onvio needed)
- `install-sage50-accounts.ps1` (if Sage needed)
- `install-xerox-workplace-cloud-client.ps1` (if Xerox needed)
- `pin-apps-to-taskbar-all-users.ps1` (if taskbar pins needed)
- CCH-related scripts (if CCH client)

### ❌ **Not for CIT:**

- Analysis/debugging scripts (`analyze-*`, `check-*`, `compare-*`, `verify-*`)
- Post-build scripts (`cheesman-enrollment.ps1`)
- Superseded scripts (`install-fslogix-status-script.ps1`)
- Autopilot scripts (not applicable to AVD)

---

## Summary

**Total Scripts in windows-scripts/**: 32  
**In CIT Guide**: 13  
**Should Add**: 2 (install-powershell7.ps1, enable-screen-capture-protection.ps1)  
**Client-Specific**: 8  
**Not for CIT**: 9

---

## Next Steps

1. ✅ Add `install-fslogix-status-to-pd-scripts.ps1` to CIT guide (DONE)
2. ⭐ Add `install-powershell7.ps1` to CIT guide (REQUIRED)
3. ⭐ Add `enable-screen-capture-protection.ps1` to CIT guide (RECOMMENDED)
4. 📋 Document client-specific scripts for reference
5. 🗑️ Consider removing/archiving scripts not used

