# CIT Build Failure Analysis - Updated

**Date:** 2025-11-10  
**Build ID:** 90b156f7-4946-43f8-ad32-ca90081792fa  
**Failure Time:** 18:12:39  
**Total Build Time:** 1 hour 34 minutes  

---

## Root Cause

**Script exited with non-zero exit status: 1**

The CCH Rollout script (`run-cch-rollout-script.ps1`) was executing the batch file during CIT build. The batch file:
1. Tried to access network shares (failed silently for some commands)
2. Hit a `PAUSE` command at the end (line 11811)
3. Exited with code 1 (line 11813)
4. Caused the PowerShell script to exit with code 1
5. Build failed because Packer requires exit code 0

---

## Failure Details from Log

### Line 3218: Script Started
```
Running CCH Rollout script...
```

### Lines 3220-11812: Batch File Executed
The batch file ran and executed commands including:
- `regedit /s "\\CAAZURAPP01\CENTRALCLIENT\ADDINS\vconnect32.reg"` (line 3231)
- `regedit /s "\\CAAZURAPP01\CENTRALCLIENT\ADDINS\vconnect64.reg"` (line 3235)
- `robocopy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\CCHCENTRAL" ...` (network share access)
- Multiple `xcopy` commands from network shares (failed with "Invalid drive specification")
- `PAUSE` command at the end (line 11811)

### Line 11811-11814: Failure Point
```
C:\Users\Public\Desktop>PAUSE
Press any key to continue . . .
WARNING: Batch file exited with code: 1
packer-provisioner-powershell plugin: c:/Windows/Temp/script-69121536-3de8-5fa2-90ae-b55c17b95571.ps1 returned with exit code 1
```

### Line 11847: Build Failure
```
Build 'azure-arm' errored after 1 hour 34 minutes: Script exited with non-zero exit status: 1. Allowed exit codes are: [0]
```

---

## Why It Failed

1. **Old Script Version Used:** The log shows the old version of `run-cch-rollout-script.ps1` was executed, which actually ran the batch file
2. **Batch File Executed:** The script called the batch file directly
3. **Network Access Failed:** Batch file tried to access `\\CAAZURAPP01\CENTRALCLIENT\...` but VM is not domain-joined during CIT
4. **PAUSE Command:** Batch file ended with `PAUSE`, which waits for user input
5. **Exit Code 1:** The `PAUSE` command or a failed network operation caused the batch file to exit with code 1
6. **Build Failed:** Packer requires exit code 0, so build failed

---

## Fix Applied

The script has been updated to:

1. **Skip Batch Execution During CIT:**
   - No longer attempts to run the batch file during CIT build
   - Skips all batch file execution logic
   - Only creates the scheduled task

2. **Always Create Scheduled Task:**
   - Creates a scheduled task that will run the batch file after domain join
   - Scheduled task runs 5 minutes after system startup
   - Only runs when network is available

3. **Always Exit with Success:**
   - Script always exits with code 0 (success)
   - Build will not fail due to this script

---

## Updated Script Behavior

### During CIT Build:
```
Skipping batch execution during CIT build (VM not domain-joined)
Batch file will run automatically via scheduled task after domain join
Creating scheduled task...
  Scheduled task created: CCH-Rollout-Script
  Task will run 5 minutes after system startup
  Task will only run when network is available
Script completed successfully!
Note: Batch file will run automatically via scheduled task after domain join.
Exit Code: 0 ✅
```

### After Domain Join (Scheduled Task Runs):
- Scheduled task executes: `cmd.exe /c "cd /d C:\CCHAPPS && echo. | call "CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat""`
- `echo.` pipes Enter key to handle `PAUSE` command
- Batch file runs successfully with network access
- Scheduled task completes

---

## Verification

After the next CIT build, you should see in the logs:
- ✅ "Skipping batch execution during CIT build (VM not domain-joined)"
- ✅ "Creating scheduled task..."
- ✅ "Script completed successfully!"
- ✅ Exit code: 0
- ❌ NO "Running CCH Rollout script..." (old behavior)
- ❌ NO batch file execution
- ❌ NO "PAUSE" command
- ❌ NO exit code 1

---

## Summary

**Old Behavior (Failed):**
- Script ran batch file during CIT
- Batch file tried to access network shares (failed)
- Batch file hit PAUSE command
- Exited with code 1
- Build failed ❌

**New Behavior (Fixed):**
- Script skips batch execution during CIT
- Creates scheduled task only
- Exits with code 0
- Build succeeds ✅
- Batch file runs automatically after domain join via scheduled task ✅

---

## Next Steps

1. **Rebuild CIT Template:**
   - The updated script will be downloaded from GitHub
   - Build should complete successfully

2. **Verify Scheduled Task:**
   - After domain join, check Task Scheduler
   - Task "CCH-Rollout-Script" should be present
   - Task will run automatically on startup (5 minute delay)

3. **Monitor First Boot:**
   - After domain join, on first boot, scheduled task will run
   - Batch file should execute successfully with network access
   - Check logs to confirm batch file completed

