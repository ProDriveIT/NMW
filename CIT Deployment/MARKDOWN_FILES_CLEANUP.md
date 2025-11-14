# Markdown Files Cleanup Analysis

This document identifies which .md files can be safely deleted as they were used for testing, analysis, or one-time reference purposes.

## Files to KEEP (Active/Production Guides)

### ✅ Keep - Actively Used Guides

1. **`CIT Deployment/AVD_CIT_QUICK_START.md`**
   - **Status**: ✅ KEEP
   - **Reason**: Main CIT deployment guide - actively used for all CIT builds
   - **Usage**: Primary reference for creating custom image templates

2. **`CIT Deployment/AVD_CIT_UAT_GUIDE.md`**
   - **Status**: ✅ KEEP
   - **Reason**: User Acceptance Testing guide - actively used for UAT process
   - **Usage**: Guides testers through UAT process

3. **`scripted-actions/OneDrive-GPO-Deployment-Guide.md`**
   - **Status**: ✅ KEEP
   - **Reason**: Active deployment guide for OneDrive GPO setup
   - **Usage**: Reference for deploying OneDrive settings via GPO

4. **`CIT Deployment/SCRIPT_COMPARISON.md`**
   - **Status**: ✅ KEEP
   - **Reason**: Useful reference comparing scripts in guide vs available scripts
   - **Usage**: Helps identify which scripts should be added to CIT template

---

## Files to DELETE (Testing/Analysis/Reference)

### ❌ Delete - Analysis/Testing Documents

1. **`scripted-actions/AVD-All-GPOs-Conflict-Analysis.md`**
   - **Status**: ❌ DELETE
   - **Reason**: One-time conflict analysis document (dated 2025-11-10)
   - **Content**: Analyzed Edge optimization script vs GPOs - no conflicts found
   - **Replacement**: Information already incorporated into other guides

2. **`scripted-actions/AVD-GPO-Analysis.md`**
   - **Status**: ❌ DELETE
   - **Reason**: One-time GPO analysis document (dated 2025-11-10)
   - **Content**: Analyzed 7 GPOs - reference document only
   - **Replacement**: GPO information documented in deployment guides

3. **`scripted-actions/AVD-Optimization-Conflict-Analysis.md`**
   - **Status**: ❌ DELETE
   - **Reason**: One-time conflict analysis (dated 2025-11-10)
   - **Content**: Edge script vs GPO conflict analysis - no conflicts found
   - **Replacement**: Information already incorporated

4. **`scripted-actions/AVD-System-Optimizations-GPO-Export.md`**
   - **Status**: ❌ DELETE
   - **Reason**: GPO export reference document (dated 2024-07-31)
   - **Content**: Complete export of "AVD: System Optimizations" GPO settings
   - **Replacement**: GPO settings documented in deployment guides

### ❌ Delete - Reference Guides (One-Time Use)

5. **`CIT Deployment/AVD_GPO_DEPLOYMENT_GUIDE.md`**
   - **Status**: ❌ DELETE
   - **Reason**: Reference guide for GPO deployment - information now in other guides
   - **Content**: Documents GPOs that should be deployed (now handled via scripts)
   - **Replacement**: Information incorporated into CIT guide and script documentation

6. **`CIT Deployment/GPO_VS_SCRIPT_ANALYSIS.md`**
   - **Status**: ❌ DELETE
   - **Reason**: Analysis document comparing GPO vs Script approach
   - **Content**: Analyzed which scripts should be GPOs vs scripts
   - **Replacement**: Decisions already made and implemented

7. **`CIT Deployment/REGISTRY_VERIFICATION_GUIDE.md`**
   - **Status**: ❌ DELETE
   - **Reason**: Testing/verification guide for registry settings
   - **Content**: Lists registry paths to verify CIT script settings
   - **Replacement**: Verification can be done via scripts or ad-hoc

8. **`CIT Deployment/STORAGE_ACCOUNT_ACCESS_FOR_CIT.md`**
   - **Status**: ❌ DELETE
   - **Reason**: One-time setup guide for storage account access
   - **Content**: How to configure storage account for CIT builds
   - **Replacement**: One-time setup - information can be found in Azure docs if needed

9. **`CIT Deployment/UPLOAD_FOLDER_TO_C_DRIVE.md`**
   - **Status**: ❌ DELETE
   - **Reason**: One-time reference guide for uploading folders during build
   - **Content**: How to upload folders to C:\ during CIT build
   - **Replacement**: Rare use case - can reference script directly if needed

10. **`AVD_DEPLOYMENT_CHECKLIST.md`**
    - **Status**: ❌ DELETE
    - **Reason**: One-time deployment checklist
    - **Content**: Complete AVD deployment checklist
    - **Replacement**: Information covered in CIT guide and UAT guide

11. **`scripted-actions/AVD-GPO-Comparison.txt`**
    - **Status**: ❌ DELETE
    - **Reason**: GPO comparison text file (dated 2025-11-10)
    - **Content**: Text export comparing AVD GPO settings
    - **Replacement**: Analysis documents already cover this

---

## Summary

**Total .md Files**: 14  
**Total .txt Files**: 1 (analysis file)  
**Keep**: 4 files  
**Delete**: 11 files (10 .md + 1 .txt)

### Files to Delete:

```
scripted-actions/AVD-All-GPOs-Conflict-Analysis.md
scripted-actions/AVD-GPO-Analysis.md
scripted-actions/AVD-Optimization-Conflict-Analysis.md
scripted-actions/AVD-System-Optimizations-GPO-Export.md
scripted-actions/AVD-GPO-Comparison.txt
CIT Deployment/AVD_GPO_DEPLOYMENT_GUIDE.md
CIT Deployment/GPO_VS_SCRIPT_ANALYSIS.md
CIT Deployment/REGISTRY_VERIFICATION_GUIDE.md
CIT Deployment/STORAGE_ACCOUNT_ACCESS_FOR_CIT.md
CIT Deployment/UPLOAD_FOLDER_TO_C_DRIVE.md
AVD_DEPLOYMENT_CHECKLIST.md
```

### Files to Keep:

```
CIT Deployment/AVD_CIT_QUICK_START.md
CIT Deployment/AVD_CIT_UAT_GUIDE.md
CIT Deployment/SCRIPT_COMPARISON.md
scripted-actions/OneDrive-GPO-Deployment-Guide.md
```

---

## Recommendation

Delete all 11 files marked for deletion. They were:
- One-time analysis documents (conflict analysis, GPO analysis)
- Reference documents that have been superseded
- Testing/verification guides that are no longer needed
- One-time setup guides that are rarely referenced

The 4 files to keep are actively used production guides that are referenced regularly.

