# AVD Optimization Script vs GPO Conflict Analysis

**Date:** 2025-11-10  
**Script Analyzed:** `optimize-microsoft-edge.ps1`  
**GPOs Analyzed:** All AVD GPOs (7 total)

---

## Executive Summary

✅ **NO CONFLICTS DETECTED**

The Edge optimization script and AVD GPOs configure different settings:
- **Edge Script:** Configures Microsoft Edge browser policies
- **AVD GPOs:** Configure Chrome, Windows, Outlook, FSLogix, and security settings

**Recommendation:** Both can coexist without issues. The script runs during CIT (image creation), and GPOs apply after domain join.

---

## Detailed Comparison

### Edge Optimization Script Settings

**Script:** `optimize-microsoft-edge.ps1`  
**Registry Path:** `HKLM:\SOFTWARE\Policies\Microsoft\Edge`

| Setting | Value | Purpose |
|---------|-------|---------|
| `SleepingTabsEnabled` | `1` (Enabled) | Reduces memory usage for inactive tabs |
| `StartupBoostEnabled` | `0` (Disabled) | Prevents Edge preloading at login |
| `BackgroundModeEnabled` | `0` (Disabled) | Prevents Edge running in background |
| `EfficiencyMode` | `1` (Enabled) | Reduces resource consumption in VDI |
| `HideFirstRunExperience` | `1` (Enabled) | Improves login performance |
| `ShowRecommendationsEnabled` | `0` (Disabled) | Reduces background activity |
| `WebWidgetAllowed` | `0` (Disabled) | Reduces background activity |

---

### AVD GPO Settings Comparison

#### 1. AVD: System Optimizations

**Chrome Settings (User Configuration):**
- `HKLM:\Software\Policies\Google\Chrome\HardwareAccelerationModeEnabled` = `0`
- `HKLM:\Software\Policies\Google\Chrome\SearchSuggestEnabled` = `0`
- `HKLM:\Software\Policies\Google\Chrome\AllowDinosaurEasterEgg` = `0`
- `HKLM:\Software\Policies\Google\Chrome\HighEfficiencyModeEnabled` = `1`

**Chrome Settings (Computer Configuration):**
- `HKLM:\Software\Policies\Google\Chrome\BackgroundModeEnabled` = `0`
- `HKLM:\Software\Policies\Google\Chrome\HardwareAccelerationModeEnabled` = `0`

**Analysis:** ✅ **No Conflict** - These are **Chrome** settings, not Edge settings. Different browsers, different registry paths.

**Windows/Explorer Settings:**
- Visual effects, animations, search/Cortana settings
- **Analysis:** ✅ **No Conflict** - Completely different settings

#### 2. AVD-CachedExchangeMode

**Settings:** Outlook cached mode, RPC/HTTP settings  
**Analysis:** ✅ **No Conflict** - Different application (Outlook vs Edge)

#### 3. AVD-DesktopLockdown

**Settings:** Power options, screen saver, registry editing restrictions  
**Analysis:** ✅ **No Conflict** - Different category (security vs browser optimization)

#### 4. AVD-Profiles

**Settings:** FSLogix profile container settings  
**Analysis:** ✅ **No Conflict** - Different category (profiles vs browser)

#### 5. AVD-MEMEnrollment

**Settings:** MDM enrollment  
**Analysis:** ✅ **No Conflict** - Different category

#### 6. AVD-RegionalSettings

**Settings:** Regional/locale settings  
**Analysis:** ✅ **No Conflict** - Different category

#### 7. AVD-Turn Off Windows Installer RDS Compatibility

**Settings:** Windows Installer RDS compatibility  
**Analysis:** ✅ **No Conflict** - Different category

---

## Potential Issues & Considerations

### 1. **GPO Precedence (If Edge Settings Were Added to GPO)**

**Scenario:** If Edge settings are added to a GPO in the future, GPOs will override script settings.

**Why:** GPOs apply continuously and have higher precedence than one-time script settings.

**Impact:** If Edge settings are added to GPO:
- Script settings would be overridden on each GPO refresh
- GPO settings would take precedence
- This is actually **desired behavior** - GPOs provide centralized management

**Recommendation:** If Edge settings need to be managed centrally, add them to a GPO (e.g., "AVD: System Optimizations") and remove from CIT script.

### 2. **Script Runs Before Domain Join**

**Timeline:**
1. CIT image creation (script runs) → Edge settings applied
2. Domain join → GPOs apply
3. GPO refresh → GPOs reapply (if Edge settings exist in GPO)

**Current State:** No Edge settings in GPOs, so script settings remain.

**Future State:** If Edge settings added to GPO, they would override script settings.

### 3. **Registry Path Comparison**

| Script | GPO |
|--------|-----|
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `HKLM:\Software\Policies\Google\Chrome` |

**Analysis:** ✅ **Different paths** - No overlap

**Note:** Case sensitivity doesn't matter in Windows registry, but these are completely different paths.

---

## Recommendations

### ✅ **Current Setup is Correct**

1. **Keep Edge script in CIT** - No conflicts with existing GPOs
2. **Keep Chrome settings in GPO** - Centralized management
3. **No changes needed** - Both can coexist

### 🔄 **Future Considerations**

1. **If Edge settings need centralized management:**
   - Add Edge settings to "AVD: System Optimizations" GPO
   - Remove Edge script from CIT
   - Use GPO Registry Preferences or Administrative Templates

2. **If keeping script approach:**
   - Document that Edge settings are set via CIT script
   - Note that GPOs will override if Edge settings are added later
   - Consider adding Edge settings to GPO for consistency with Chrome

### 📋 **Best Practice Recommendation**

**Option A: Keep Current Setup (Script + GPO)**
- ✅ Edge optimized via script during image creation
- ✅ Chrome optimized via GPO for centralized management
- ⚠️ Inconsistent approach (script vs GPO)

**Option B: Move Edge to GPO (Recommended for Consistency)**
- ✅ Both browsers managed via GPO
- ✅ Centralized management
- ✅ Consistent approach
- ⚠️ Requires GPO update

**Recommendation:** **Option B** - Move Edge settings to GPO for consistency, but current setup works fine.

---

## Verification Steps

To verify no conflicts exist:

1. **Check Edge registry on AVD session host:**
   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" | Select-Object *
   ```

2. **Check Chrome registry on AVD session host:**
   ```powershell
   Get-ItemProperty -Path "HKLM:\Software\Policies\Google\Chrome" | Select-Object *
   ```

3. **Verify GPO application:**
   ```powershell
   gpresult /h gpresult.html
   ```

4. **Check for Edge settings in GPOs:**
   - Open Group Policy Management
   - Search all AVD GPOs for "Edge" or "Microsoft\Edge"
   - Currently: **None found** ✅

---

## Conclusion

✅ **No conflicts detected between Edge optimization script and AVD GPOs.**

The script and GPOs configure different applications and settings:
- **Script:** Microsoft Edge browser optimization
- **GPOs:** Chrome, Windows, Outlook, FSLogix, security settings

Both can coexist without issues. The script runs during CIT (pre-domain join), and GPOs apply after domain join. Since there are no Edge settings in GPOs, the script settings will remain.

**Status:** ✅ **Safe to use both**

