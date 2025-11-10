# GPO vs Script Analysis for Windows Scripts

This document analyzes which scripts in the `scripted-actions/windows-scripts` folder would be better deployed as Group Policy Objects (GPOs) versus running as scripts during CIT image creation.

## Scripts Better Deployed as GPOs

These scripts configure policy settings that GPOs are designed to manage. GPOs provide:
- **Automatic reapplication** if settings are changed
- **Centralized management** from Active Directory
- **Better enforcement** and compliance
- **Standard Windows policy management** approach

### 1. **configure-outlook-cached-mode.ps1** ⭐ **HIGH PRIORITY**

**Why GPO is Better:**
- Sets Office/Outlook Administrative Template policies
- GPOs automatically reapply if users/admins change settings
- Standard GPO location: `Computer Configuration > Administrative Templates > Microsoft Office 2016 > Outlook > Account Settings > Exchange`

**GPO Path:**
```
Computer Configuration
└── Administrative Templates
    └── Microsoft Office 2016
        └── Outlook
            └── Account Settings
                └── Exchange
                    ├── Use Cached Exchange Mode
                    ├── Download shared non-mail folders
                    ├── Download public folder favorites
                    └── Cached Exchange Mode sync settings
```

**Registry Keys Set:**
- `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\Cached Mode`
- `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Outlook\RPC`

**Recommendation:** Convert to GPO. These are standard Office policies that should be managed centrally.

---

### 2. **disable-power-options.ps1** ⭐ **HIGH PRIORITY**

**Why GPO is Better:**
- These are standard Windows security/user restriction policies
- GPOs enforce these settings and prevent users from bypassing them
- Critical for AVD session hosts - should be enforced, not just set once

**GPO Paths:**
```
Computer Configuration
└── Administrative Templates
    └── Start Menu and Taskbar
        ├── Remove and prevent access to the Shut Down, Restart, Sleep, and Hibernate commands
        └── Remove the Power Button from the Start Menu

Computer Configuration
└── Administrative Templates
    └── System
        └── Power Management
            ├── Sleep Settings
            └── Hibernate Settings
```

**Registry Keys Set:**
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer` (NoClose)
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer` (NoStartMenuPowerButton)
- `HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\...`

**Recommendation:** Convert to GPO. These are security-critical settings that must be enforced.

---

### 3. **configure-windows-installer-rds-compatibility.ps1** ⭐ **HIGH PRIORITY**

**Why GPO is Better:**
- This is literally a Group Policy setting
- The script even documents the GPO path in its comments
- Standard RDS/AVD policy that should be managed centrally

**GPO Path:**
```
Computer Configuration
└── Administrative Templates
    └── Windows Components
        └── Remote Desktop Services
            └── Remote Desktop Session Host
                └── Application Compatibility
                    └── Turn off Windows Installer RDS Compatibility
```

**Registry Key:**
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\Application Compatibility\DisableMsi`

**Recommendation:** **Definitely convert to GPO.** This is a standard GPO setting that should be managed as such.

---

### 4. **optimize-microsoft-edge.ps1** ⭐ **MEDIUM PRIORITY**

**Why GPO is Better:**
- Sets Microsoft Edge Administrative Template policies
- GPOs provide centralized management and enforcement
- Standard GPO location for Edge policies

**GPO Path:**
```
Computer Configuration
└── Administrative Templates
    └── Microsoft Edge
        ├── Sleeping Tabs Enabled
        ├── Startup Boost Enabled
        ├── Background Mode Enabled
        ├── Efficiency Mode
        ├── Hide First Run Experience
        ├── Show Recommendations Enabled
        └── Web Widget Allowed
```

**Registry Keys Set:**
- `HKLM:\SOFTWARE\Policies\Microsoft\Edge`

**Recommendation:** Convert to GPO. Edge policies are better managed through GPOs for centralized control.

---

### 5. **enable-screen-capture-protection.ps1** ⭐ **MEDIUM PRIORITY**

**Why GPO is Better:**
- This is a policy setting for AVD security
- GPOs ensure the setting is enforced and reapplied if changed
- Security settings should be managed centrally

**GPO Path:**
```
Computer Configuration
└── Administrative Templates
    └── Windows Components
        └── Remote Desktop Services
            └── Remote Desktop Session Host
                └── Security
                    └── Enable screen capture protection
```

**Registry Key:**
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\fEnableScreenCaptureProtect`

**Recommendation:** Convert to GPO if you want centralized enforcement. Can stay as script if it's a one-time security hardening during image creation.

---

### 6. **enable-mdm-enrollment.ps1** ⚠️ **CONDITIONAL**

**Why GPO Could Be Better:**
- This is a policy setting for MDM enrollment
- GPOs can ensure it stays enabled

**Why Script Might Be Better:**
- Typically set once during device provisioning
- May need to run before domain join completes
- Can be part of Azure AD join process

**GPO Path:**
```
Computer Configuration
└── Administrative Templates
    └── Windows Components
        └── MDM
            └── Enable automatic MDM enrollment using default Azure AD credentials
```

**Registry Key:**
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM`

**Recommendation:** **Keep as script** for initial setup, but consider GPO to ensure it stays enabled. This is often set during provisioning before GPOs apply.

---

## Scripts That Should Stay as Scripts

These scripts perform one-time operations, installations, or complex logic that are better suited for script execution during image creation.

### Installation Scripts (Keep as Scripts)
- `install-m365-apps.ps1` - Software installation
- `install-onedrive-per-machine.ps1` - Software installation
- `install-chrome-per-machine.ps1` - Software installation
- `install-adobe-reader-per-machine.ps1` - Software installation
- `install-microsoft-teams-new.ps1` - Software installation
- `install-winget.ps1` - Software installation
- `install-datto-rmm-*.ps1` - Software installation

**Why:** These are one-time installations during image creation. GPOs can deploy software, but scripts provide more flexibility and are better for CIT workflows.

---

### Application-Specific Scripts (Keep as Scripts)
- `run-cch-rollout-script.ps1` - Application-specific configuration
- `upload-cch-apps.ps1` - File operations
- `upload-folder-to-c-drive.ps1` - File operations

**Why:** These are application-specific or perform file operations that are better handled by scripts.

---

### Domain Join (Keep as Script)
- `join-domain.ps1` - One-time domain join operation

**Why:** This is a one-time operation that happens during provisioning, before GPOs can apply.

---

### Conditional/Alternative Scripts

#### **configure-onedrive-auto-signin.ps1** ⚠️ **CONSIDER INTUNE INSTEAD**

**Current Approach:** Script sets registry keys for OneDrive auto-signin

**Better Approach:** Use **Intune Configuration Profile** instead of GPO or script
- Intune provides better management for Azure AD joined devices
- OneDrive policies are well-supported in Intune
- Works better with hybrid/Azure AD joined scenarios

**GPO Alternative:**
```
Computer Configuration
└── Administrative Templates
    └── OneDrive
        └── Silently sign in users to the OneDrive sync app with their Windows credentials
```

**Recommendation:** Use **Intune Configuration Profile** for OneDrive settings. If not using Intune, GPO is better than script for enforcement.

---

#### **configure-fslogix-tray-startup.ps1** ⚠️ **EITHER WORKS**

**Current Approach:** Script adds FSLogix tray to startup registry

**GPO Alternative:** Can be set via GPO startup script or registry preference

**Recommendation:** **Keep as script** - This is a simple startup configuration that works well as a script. GPO startup script would also work, but script is simpler for CIT.

---

## Summary Recommendations

### Convert to GPO (High Priority):
1. ✅ **configure-outlook-cached-mode.ps1**
2. ✅ **disable-power-options.ps1**
3. ✅ **configure-windows-installer-rds-compatibility.ps1**

### Convert to GPO (Medium Priority):
4. ✅ **optimize-microsoft-edge.ps1**
5. ⚠️ **enable-screen-capture-protection.ps1** (optional, depends on security requirements)

### Use Intune Instead:
6. 🔄 **configure-onedrive-auto-signin.ps1** → Use Intune Configuration Profile

### Keep as Scripts:
- All installation scripts
- Domain join script
- Application-specific scripts
- File operation scripts
- FSLogix tray startup (simple enough as script)

---

## Migration Strategy

### Step 1: Create GPOs for High Priority Items
1. Create a new GPO: `AVD Session Host - Outlook Cached Mode`
2. Create a new GPO: `AVD Session Host - Power Options Restrictions`
3. Create a new GPO: `AVD Session Host - RDS Compatibility`

### Step 2: Link GPOs to AVD Session Host OU
- Link GPOs to the OU containing AVD session host computer objects
- Ensure GPOs apply to session hosts (not users)

### Step 3: Remove Scripts from CIT
- Remove the converted scripts from the CIT template
- Keep scripts as reference/backup if needed

### Step 4: Test
- Deploy a new session host
- Verify GPOs apply correctly
- Verify settings are enforced

### Step 5: Update Documentation
- Update CIT Quick Start Guide to reflect GPO usage
- Document GPO names and settings for future reference

---

## Benefits of Using GPOs

1. **Centralized Management:** All policy settings in one place (Group Policy Management Console)
2. **Automatic Enforcement:** Settings reapplied automatically if changed
3. **Better Compliance:** Easier to audit and verify settings
4. **Standard Approach:** Uses Windows' built-in policy management
5. **Easier Updates:** Change GPO once, applies to all session hosts
6. **No Script Maintenance:** Less code to maintain and update

---

## Hybrid Approach (Recommended)

**Best Practice:** Use a combination:
- **GPOs** for policy settings (Outlook, Power Options, RDS Compatibility, Edge)
- **Scripts** for installations and one-time configurations during image creation
- **Intune** for OneDrive and modern device management (if using Azure AD)

This provides the best of both worlds: centralized policy management via GPOs, and flexible installation/configuration via scripts during image creation.

