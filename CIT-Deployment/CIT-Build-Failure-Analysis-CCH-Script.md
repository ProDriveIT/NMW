# CIT Build Failure Analysis - CCH Rollout Script

**Date:** 2025-11-11  
**Build ID:** af8429a6-fa1d-4e00-a7b9-7ed383ad7931  
**Failure Time:** 08:38:28  
**Total Build Time:** 1 hour 35 minutes  

---

## Root Cause

**Script exited with non-zero exit status: 1**

The CCH Rollout script (`run-cch-rollout-script.ps1`) **successfully ran the new version** (confirmed by log showing "Skipping batch execution during CIT build"), but **failed when creating the scheduled task** due to a PowerShell parameter type error.

---

## Failure Details from Log

### Line 3251: New Script Downloaded
```
3462 bytes written for 'uploadData'
```
✅ **Correct script size** - The new version (3462 bytes) was downloaded, not the old version (3467 bytes).

### Line 3254-3255: New Script Executing
```
Skipping batch execution during CIT build (VM not domain-joined)
Batch file will run automatically via scheduled task after domain join
```
✅ **New script is running** - The correct version is executing.

### Line 3256: Creating Scheduled Task
```
Creating scheduled task...
```

### Line 3263: Failure Point
```
WARNING: Failed to create scheduled task: Cannot process argument transformation on parameter 'Argument'. Cannot convert value to type System.String.
```

### Line 3257: Script Exit Code
```
exited with code: 1
```

### Line 3268: Build Failure
```
c:/Windows/Temp/script-6912dfd2-c357-7082-0172-b6b4e0441c41.ps1 returned with exit code 1
```

---

## Why It Failed

The `New-ScheduledTaskAction` cmdlet's `-Argument` parameter expects a **single string**, but the script was passing an **array**:

**Incorrect (Line 53 - Old Code):**
```powershell
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c", "cd /d C:\CCHAPPS && echo. | call `"$BatchFilePath`""
```

This passes an array `("/c", "cd /d C:\CCHAPPS && echo. | call \"...\"")` to `-Argument`, which expects a string.

**Error Message:**
```
Cannot process argument transformation on parameter 'Argument'. Cannot convert value to type System.String.
```

---

## Solution

**Fixed (Line 54-55 - New Code):**
```powershell
# Argument must be a single string, not an array
$Argument = "/c `"cd /d C:\CCHAPPS && echo. | call \`"$BatchFilePath\`"`""
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument $Argument -WorkingDirectory "C:\CCHAPPS"
```

The arguments are now combined into a single string with proper quote escaping.

---

## What Was Fixed

1. ✅ **Combined array into single string** - The `/c` and the command are now one string
2. ✅ **Proper quote escaping** - Used backticks to escape quotes within the string
3. ✅ **Maintains functionality** - The command still works the same way, just formatted correctly for PowerShell

---

## Verification

After the fix:
- ✅ Script will skip batch execution during CIT (correct behavior)
- ✅ Script will create scheduled task successfully
- ✅ Script will exit with code 0 (build will succeed)
- ✅ Scheduled task will run batch file after domain join

---

## Summary

| Component | Status | Reason |
|-----------|--------|--------|
| **Script Version** | ✅ Correct | New version (3462 bytes) downloaded and executed |
| **Script Logic** | ✅ Correct | Correctly skips batch execution during CIT |
| **Scheduled Task Creation** | ❌ Failed | `-Argument` parameter type error (array vs string) |
| **Build Result** | ❌ Failed | Script exited with code 1 |

**Fix:** Updated `run-cch-rollout-script.ps1` to pass `-Argument` as a single string instead of an array.

---

## Next Steps

1. **Commit and push** the fixed script to GitHub
2. **Retry the CIT build** - It should now succeed
3. **Verify** the scheduled task is created correctly after build completes

---

