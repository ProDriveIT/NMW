# CIT Build Failure Analysis - Customization(2)

**Date:** 2025-11-10  
**Build ID:** e280cd94-2364-42b5-ba0e-dc92dcf56685  
**Failure Time:** 15:58:10  
**Total Build Time:** 1 hour 29 minutes  

---

## Root Cause

**ERROR 53 (0x00000035): The network path was not found**

The CCH Rollout script (`CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat`) is trying to access network shares during the CIT build, but the VM is **not domain-joined** at this stage, so it cannot access `\\CAAZURAPP01\CENTRALCLIENT\...`

---

## Failure Details

### Error Location
**Line 11858:** `Script exited with non-zero exit status: 1. Allowed exit codes are: [0]`

### Specific Failures

1. **Registry File Access (Line 3242):**
   ```
   regedit /s "\\CAAZURAPP01\CENTRALCLIENT\ADDINS\vconnect32.reg"
   ```
   - **Error:** Cannot access network share
   - **Reason:** VM not domain-joined

2. **Registry File Access (Line 3246):**
   ```
   regedit /s "\\CAAZURAPP01\CENTRALCLIENT\ADDINS\vconnect64.reg"
   ```
   - **Error:** Cannot access network share
   - **Reason:** VM not domain-joined

3. **Robocopy Network Share (Line 3256):**
   ```
   robocopy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\CCHCENTRAL" "c:\programdata\cchcentral" /E /MIR /COPY:DAT /R:2 /W:2
   ```
   - **Error:** `ERROR 53 (0x00000035) Getting File System Type of Source`
   - **Error:** `The network path was not found`
   - **Retry Limit Exceeded:** Script retried 2 times, then failed
   - **Reason:** VM not domain-joined, cannot authenticate to network share

### Log Excerpt
```
2025/11/10 15:58:06 ERROR 53 (0x00000035) Getting File System Type of Source \\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\CCHCENTRAL\
The network path was not found.

ERROR: RETRY LIMIT EXCEEDED.

Provisioning step had errors: Running the cleanup provisioner, if present...
Script exited with non-zero exit status: 1. Allowed exit codes are: [0]
```

---

## Why This Happened

The CCH Rollout batch file (`CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat`) contains commands that require:
1. **Domain join** - To authenticate to `\\CAAZURAPP01`
2. **Network connectivity** - To access the file share
3. **Domain credentials** - To access the share

During CIT build:
- ✅ VM has internet access (for downloading scripts)
- ❌ VM is **NOT domain-joined**
- ❌ VM **CANNOT** access domain file shares
- ❌ VM **CANNOT** authenticate to `\\CAAZURAPP01`

---

## Solution

### Option 1: Remove CCH Rollout Script from CIT (Recommended)

**The CCH Rollout script should NOT run during CIT build.** It should only run:
- After domain join
- Via scheduled task (on first boot after domain join)
- Or manually after deployment

**Action:**
1. Remove `run-cch-rollout-script.ps1` from the CIT template
2. The script is already designed to handle this - it can be run post-deployment

### Option 2: Make CCH Rollout Script Non-Fatal

If you want to keep the script in CIT (for some reason), modify it to handle network failures gracefully:

**Modify `run-cch-rollout-script.ps1`:**
```powershell
# Add network check before running batch file
$networkShare = "\\CAAZURAPP01\CENTRALCLIENT"
if (-not (Test-Path $networkShare)) {
    Write-Warning "Network share not accessible (VM not domain-joined). Skipping CCH Rollout."
    Write-Warning "This script should run after domain join. Exiting gracefully."
    exit 0  # Exit with success code
}
```

**However, this is NOT recommended** because:
- The batch file itself tries to access network shares
- The batch file will still fail even if the PowerShell wrapper checks first
- The script is designed to run post-domain-join anyway

### Option 3: Pre-download Required Files

If the CCH rollout requires specific files from the network share:
1. Download those files during CIT (if possible via Azure Blob Storage)
2. Modify the batch file to use local paths instead of network paths
3. This is complex and not recommended

---

## Recommended Fix

### Immediate Action

1. **Remove from CIT Template:**
   - Remove `run-cch-rollout-script.ps1` from the Customizations tab
   - This script should NOT be in CIT

2. **Deploy Post-Domain-Join:**
   - Use the scheduled task option: `run-cch-rollout-script.ps1 -CreateScheduledTask`
   - Run this after domain join via:
     - Azure Automation Runbook
     - Manual execution
     - Group Policy startup script (after domain join)

3. **Alternative: Use Scheduled Task During CIT**
   - Keep the script in CIT but modify it to create a scheduled task
   - The scheduled task will run on first boot (after domain join)
   - The script will fail during CIT (expected), but the scheduled task will be created
   - On first boot after domain join, the scheduled task will run successfully

---

## What Worked

✅ **CCH Apps Upload Script** - Successfully downloaded and extracted `CCHAPPS.zip` from Azure Blob Storage
- Line 3083: `CCH Apps upload completed successfully.`
- Line 3084: `CCHAPPS folder verified at: C:\CCHAPPS`

The upload script worked because it uses Azure Blob Storage (internet-accessible), not domain file shares.

---

## Summary

| Component | Status | Reason |
|-----------|--------|--------|
| **CCH Apps Upload** | ✅ Success | Uses Azure Blob Storage (internet-accessible) |
| **CCH Rollout Script** | ❌ Failed | Tries to access domain file share (VM not domain-joined) |
| **Build Result** | ❌ Failed | Script exited with code 1 (non-zero) |

**Fix:** Remove `run-cch-rollout-script.ps1` from CIT template. Run it post-domain-join instead.

---

## Verification

After removing the script from CIT, verify:
1. CIT build completes successfully
2. CCHAPPS folder is present at `C:\CCHAPPS`
3. After domain join, run `run-cch-rollout-script.ps1` manually or via scheduled task
4. CCH Rollout completes successfully after domain join

