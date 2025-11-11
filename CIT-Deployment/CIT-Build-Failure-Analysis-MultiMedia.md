# CIT Build Failure Analysis - MultiMedia Redirection

**Date:** 2025-11-10  
**Build ID:** 1351ba87-9ea5-47bc-bfd6-fb94ff7eefdc  
**Failure Time:** 20:34:12  
**Total Build Time:** ~54 minutes  

---

## Root Cause

**Script exited with non-zero exit status: 267014**

The build failed during the **AVD AIB Customization: MultiMedia Redirection** phase, NOT during the CCH Rollout script. The CCH Rollout script did not execute in this build.

---

## Failure Details from Log

### Line 1552: MultiMedia Redirection Script Started
```
Found command: C:\AVDImage\multiMediaRedirection.ps1 -VCRedistributableLink "https://aka.ms/vs/17/release/vc_redist.x64.exe" -EnableEdge "true" -EnableChrome "true"
```

### Line 1570-1601: Script Execution
The script started executing:
- Created temp directory `C:\temp\a10acd45-9388-476c-8c12-e09187f4c57a`
- Created `C:\mmr` directory
- Started installing Microsoft Visual C++ Redistributable
- Script was running for approximately 17 seconds (20:33:55 to 20:34:12)

### Line 1610: Failure Point
```
command 'powershell -executionpolicy bypass -file "C:/Windows/Temp/packer-elevated-shell-69124c30-bdef-5ed3-12ce-157e6b8588c2.ps1"' exited with code: 267014
```

### Line 1619: Script Exit Code
```
c:/Windows/Temp/script-69123f99-f909-e3f5-53a7-33b6ef5fb920.ps1 returned with exit code 267014
```

### Line 1620: Build Failure
```
Provisioning step had errors: Running the cleanup provisioner, if present...
```

---

## Exit Code 267014 Analysis

**Exit code 267014** is a Windows error code that typically indicates:
- **Process terminated unexpectedly**
- **Timeout during execution**
- **Communicator/RPC connection lost**
- **Process killed by system or timeout**

This is NOT a standard PowerShell exit code (which are typically 0-255). This suggests the process was terminated externally, possibly due to:
1. **Timeout** - The script took too long to execute
2. **System resource constraints** - Memory/CPU limits
3. **Network issues** - Download of Visual C++ Redistributable failed or timed out
4. **Process termination** - The process was killed by the system

---

## What Was Happening

The `multiMediaRedirection.ps1` script was:
1. ✅ Creating temporary directories
2. ✅ Setting up registry keys for MSRDC policies
3. ⏳ **Installing Microsoft Visual C++ Redistributable** from `https://aka.ms/vs/17/release/vc_redist.x64.exe`
4. ❌ **Failed during the Visual C++ installation** (likely download/install timeout)

---

## Why This Happened

Possible causes:
1. **Network timeout** - Download of Visual C++ Redistributable took too long or failed
2. **Installation timeout** - The installer itself timed out or hung
3. **Resource constraints** - VM ran out of memory/CPU during installation
4. **Process killed** - The system terminated the process due to resource limits

---

## Solution

### Option 1: Retry the Build (Recommended First Step)
Since this has never failed before, **retry the build first**. This is likely a transient network issue downloading the Visual C++ Redistributable from Microsoft's CDN. The failure occurred after only 17 seconds, which strongly suggests a temporary network timeout.

**Action:** Simply retry the CIT build. It will likely succeed on the second attempt.

### Option 2: Increase Timeout (If Retry Fails)
If the retry also fails, increase the timeout for the MultiMedia Redirection customization step in the CIT template. Note: Individual step timeouts may not be configurable in the Azure Portal for built-in scripts.

### Option 3: Pre-download Visual C++ Redistributable
Instead of downloading during build:
1. Pre-download the Visual C++ Redistributable to Azure Blob Storage
2. Modify the script to use the local copy
3. This eliminates network download issues

### Option 4: Skip MultiMedia Redirection (If Not Required)
If MultiMedia Redirection is not immediately required:
1. Remove it from the CIT template
2. Install it post-deployment via Intune or GPO

### Option 5: Check VM Resources
Ensure the build VM has sufficient:
- Memory (at least 4GB recommended)
- CPU (at least 2 cores)
- Network bandwidth

---

## Verification

**Important:** The CCH Rollout script (`run-cch-rollout-script.ps1`) was **NOT executed** in this build. The build failed before reaching that step.

To verify the CCH script would work:
1. The script is correctly configured on GitHub (verified)
2. The script will skip batch execution during CIT
3. The script will create the scheduled task
4. The script will exit with code 0

---

## Next Steps

1. **Check CIT Template Configuration:**
   - Verify timeout settings for MultiMedia Redirection
   - Check if there are resource constraints

2. **Retry the Build:**
   - This may have been a transient network issue
   - The Visual C++ Redistributable download may succeed on retry

3. **If Issue Persists:**
   - Consider pre-downloading Visual C++ Redistributable to Azure Blob Storage
   - Or skip MultiMedia Redirection and install post-deployment

---

## Summary

| Component | Status | Reason |
|-----------|--------|--------|
| **MultiMedia Redirection** | ❌ Failed | Exit code 267014 (likely timeout during Visual C++ install) |
| **CCH Rollout Script** | ⏸️ Not Executed | Build failed before reaching this step |
| **Build Result** | ❌ Failed | Script exited with non-zero exit status: 267014 |

**Fix:** Address the MultiMedia Redirection timeout/installation issue. The CCH Rollout script is not the problem.

---

