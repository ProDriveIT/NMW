# AVD: System Optimizations - Complete GPO Settings Export

**GPO Name:** AVD: System Optimizations  
**GPO ID:** {ABBF2DFB-C146-4833-98BE-462A371110EF}  
**Domain:** justinvers.nl  
**Created:** 2024-07-31  
**Last Modified:** 2024-07-31  

---

## Computer Configuration

### Registry Preferences (Windows Registry Extension)

#### 1. AllowStorageSenseGlobal
- **Hive:** `HKEY_LOCAL_MACHINE`
- **Key:** `SOFTWARE\Policies\Microsoft\Windows\StorageSense`
- **Value Name:** `AllowStorageSenseGlobal`
- **Type:** `REG_DWORD`
- **Value:** `0` (Disabled)
- **Action:** Update

#### 2. ShowTaskViewButton
- **Hive:** `HKEY_CURRENT_USER`
- **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **Value Name:** `ShowTaskViewButton`
- **Type:** `REG_DWORD`
- **Value:** `0` (Disabled)
- **Action:** Update

#### 3. TaskbarAL (Taskbar Alignment)
- **Hive:** `HKEY_CURRENT_USER`
- **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **Value Name:** `TaskbarAL`
- **Type:** `REG_DWORD`
- **Value:** `0` (Disabled)
- **Action:** Update

#### 4. ICEControl (Immediate Connect Experience Control)
- **Hive:** `HKEY_LOCAL_MACHINE`
- **Key:** `SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations`
- **Value Name:** `ICEControl`
- **Type:** `REG_DWORD`
- **Value:** `2`
- **Action:** Update
- **Bypass Errors:** Yes

#### 5. VerboseStatus
- **Hive:** `HKEY_LOCAL_MACHINE`
- **Key:** `SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`
- **Value Name:** `VerboseStatus`
- **Type:** `REG_DWORD`
- **Value:** `1` (Enabled)
- **Action:** Update
- **Description:** "Deze registersleutel zorgt ervoor dat Windows laat zien waar deze precies mee bezig is tijdens het toevoegen van printers." (Shows what Windows is doing when adding printers)
- **Bypass Errors:** Yes

#### 6. TurnOffWindowsCopilot
- **Hive:** `HKEY_LOCAL_MACHINE`
- **Key:** `SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot`
- **Value Name:** `TurnOffWindowsCopilot`
- **Type:** `REG_DWORD`
- **Value:** `1` (Enabled - Copilot disabled)
- **Action:** Update

#### 7. BackgroundModeEnabled (Chrome)
- **Hive:** `HKEY_LOCAL_MACHINE`
- **Key:** `Software\Policies\Google\Chrome`
- **Value Name:** `BackgroundModeEnabled`
- **Type:** `REG_DWORD`
- **Value:** `0` (Disabled)
- **Action:** Update
- **Description:** "Uitschakelen van achtergrondprocessen in Google Chrome" (Disable background processes in Google Chrome)
- **Bypass Errors:** Yes

#### 8. HardwareAccelerationModeEnabled (Chrome)
- **Hive:** `HKEY_LOCAL_MACHINE`
- **Key:** `Software\Policies\Google\Chrome\HardwareAccelerationModeEnabled`
- **Value Name:** `HardwareAccelerationModeEnabled`
- **Type:** `REG_DWORD`
- **Value:** `0` (Disabled)
- **Action:** Update

---

### Administrative Template Policies (Computer Configuration)

#### Remote Desktop Services

1. **Allow time zone redirection**
   - **State:** Enabled
   - **Path:** `Windows Components/Remote Desktop Services/Remote Desktop Session Host/Device and Resource Redirection`
   - **Description:** Allows client time zone to be redirected to RDS session

2. **Do not set default client printer to be default printer in a session**
   - **State:** Enabled
   - **Path:** `Windows Components/Remote Desktop Services/Remote Desktop Session Host/Printer Redirection`
   - **Description:** Prevents client default printer from being set as session default

#### Search

3. **Allow Cloud Search**
   - **State:** Enabled
   - **Path:** `Windows Components/Search`
   - **Description:** Allow search and Cortana to search cloud sources like OneDrive and SharePoint
   - **Cloud Search Setting:** Not Configured

4. **Allow Cortana**
   - **State:** Disabled
   - **Path:** `Windows Components/Search`
   - **Description:** Disables Cortana on the device

5. **Allow Cortana above lock screen**
   - **State:** Disabled
   - **Path:** `Windows Components/Search`
   - **Description:** Prevents Cortana interaction while system is locked

6. **Allow search and Cortana to use location**
   - **State:** Disabled
   - **Path:** `Windows Components/Search`
   - **Description:** Prevents search and Cortana from accessing location information

7. **Default excluded paths**
   - **State:** Disabled
   - **Path:** `Windows Components/Search`
   - **Description:** Not configured

8. **Default indexed paths**
   - **State:** Disabled
   - **Path:** `Windows Components/Search`
   - **Description:** Not configured

9. **Do not allow web search**
   - **State:** Enabled
   - **Path:** `Windows Components/Search`
   - **Description:** Removes web search option from Windows Desktop Search

10. **Don't search the web or display web results in Search**
    - **State:** Enabled
    - **Path:** `Windows Components/Search`
    - **Description:** Prevents web queries and web results in Search

11. **Don't search the web or display web results in Search over metered connections**
    - **State:** Enabled
    - **Path:** `Windows Components/Search`
    - **Description:** Prevents web queries over metered connections
    - **Note:** Not supported on Windows 10 or later

#### Windows Ink Workspace

12. **Allow Windows Ink Workspace**
    - **State:** Disabled
    - **Path:** `Windows Components/Windows Ink Workspace`
    - **Description:** Disables Windows Ink Workspace

---

## User Configuration

### Registry Preferences (Windows Registry Extension)

#### Explorer & Taskbar Settings

1. **ShowTaskViewButton**
   - **Hive:** `HKEY_CURRENT_USER`
   - **Key:** `SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
   - **Value Name:** `ShowTaskViewButton`
   - **Type:** `REG_DWORD`
   - **Value:** `0` (Disabled)
   - **Action:** Update

2. **TaskbarAL (Taskbar Alignment)**
   - **Hive:** `HKEY_CURRENT_USER`
   - **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
   - **Value Name:** `TaskbarAL`
   - **Type:** `REG_DWORD`
   - **Value:** `0` (Disabled)
   - **Action:** Update

#### Visual Effects & Desktop Settings

3. **VisualEffects (Default)**
   - **Hive:** `HKEY_CURRENT_USER`
   - **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`
   - **Value Name:** (Default)
   - **Type:** `REG_DWORD`
   - **Value:** `3`
   - **Action:** Update

4. **ListviewAlphaSelect**
   - **Hive:** `HKEY_CURRENT_USER`
   - **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
   - **Value Name:** `ListviewAlphaSelect`
   - **Type:** `REG_DWORD`
   - **Value:** `0` (Disabled)
   - **Action:** Update

5. **ListviewShadow**
   - **Hive:** `HKEY_CURRENT_USER`
   - **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
   - **Value Name:** `ListviewShadow`
   - **Type:** `REG_DWORD`
   - **Value:** `0` (Disabled)
   - **Action:** Update

6. **TaskbarAnimations**
   - **Hive:** `HKEY_CURRENT_USER`
   - **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
   - **Value Name:** `TaskbarAnimations`
   - **Type:** `REG_DWORD`
   - **Value:** `0` (Disabled)
   - **Action:** Update

#### Desktop Window Manager (DWM) Settings

7. **EnableAeroPeek**
   - **Hive:** `HKEY_CURRENT_USER`
   - **Key:** `Software\Microsoft\Windows\DWM`
   - **Value Name:** `EnableAeroPeek`
   - **Type:** `REG_DWORD`
   - **Value:** `0` (Disabled)
   - **Action:** Update

8. **CompositionPolicy**
   - **Hive:** `HKEY_CURRENT_USER`
   - **Key:** `Software\Microsoft\Windows\DWM`
   - **Value Name:** `CompositionPolicy`
   - **Type:** `REG_DWORD`
   - **Value:** `1` (Enabled)
   - **Action:** Update

9. **AlwaysHibernateThumbnails**
   - **Hive:** `HKEY_CURRENT_USER`
   - **Key:** `Software\Microsoft\Windows\DWM`
   - **Value Name:** `AlwaysHibernateThumbnails`
   - **Type:** `REG_DWORD`
   - **Value:** `0` (Disabled)
   - **Action:** Update

10. **Composition**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\DWM`
    - **Value Name:** `Composition`
    - **Type:** `REG_DWORD`
    - **Value:** `1` (Enabled)
    - **Action:** Update

11. **ColorizationOpaqueBlend**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\DWM`
    - **Value Name:** `ColorizationOpaqueBlend`
    - **Type:** `REG_DWORD`
    - **Value:** `0` (Disabled)
    - **Action:** Update

#### Desktop Appearance Settings

12. **DragFullWindows**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Control Panel\Desktop`
    - **Value Name:** `DragFullWindows`
    - **Type:** `REG_SZ`
    - **Value:** `0`
    - **Action:** Update

13. **FontSmoothing**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Control Panel\Desktop`
    - **Value Name:** `FontSmoothing`
    - **Type:** `REG_SZ`
    - **Value:** `2`
    - **Action:** Update

14. **FontSmoothingGamma**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Control Panel\Desktop`
    - **Value Name:** `FontSmoothingGamma`
    - **Type:** `REG_DWORD`
    - **Value:** `0`
    - **Action:** Update

15. **FontSmoothingOrientation**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Control Panel\Desktop`
    - **Value Name:** `FontSmoothingOrientation`
    - **Type:** `REG_DWORD`
    - **Value:** `1`
    - **Action:** Update

16. **FontSmoothingType**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Control Panel\Desktop`
    - **Value Name:** `FontSmoothingType`
    - **Type:** `REG_DWORD`
    - **Value:** `2`
    - **Action:** Update

17. **UserPreferencesMask**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Control Panel\Desktop`
    - **Value Name:** `UserPreferencesMask`
    - **Type:** `REG_BINARY`
    - **Value:** `9012078010000000`
    - **Action:** Update

18. **MinAnimate**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Control Panel\Desktop\WindowMetrics`
    - **Value Name:** `MinAnimate`
    - **Type:** `REG_SZ`
    - **Value:** `0` (Disabled - no animation)
    - **Action:** Update

19. **ShellState**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer`
    - **Value Name:** `ShellState`
    - **Type:** `REG_BINARY`
    - **Value:** `24,00,00,00,38,28,00,00,00,00,00,00,00,00,00,00,00,00,00,00,01,00,00,00,12,00,00,00,00,00,00,00,32,00,00,00`
    - **Action:** Update

20. **IconsOnly**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
    - **Value Name:** `IconsOnly`
    - **Type:** `REG_DWORD`
    - **Value:** `0` (Disabled)
    - **Action:** Update

#### Theme Settings

21. **ThemeActive**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\CurrentVersion\ThemeManager`
    - **Value Name:** `ThemeActive`
    - **Type:** `REG_SZ`
    - **Value:** `1` (Active)
    - **Action:** Update

22. **LMVersion**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\CurrentVersion\ThemeManager`
    - **Value Name:** `LMVersion`
    - **Type:** `REG_SZ`
    - **Value:** `105`
    - **Action:** Update

23. **DllName**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\CurrentVersion\ThemeManager`
    - **Value Name:** `DllName`
    - **Type:** `REG_BINARY`
    - **Value:** `%SystemRoot%\resources\themes\Aero\Aero.msstyles`
    - **Action:** Update

24. **ColorName**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\CurrentVersion\ThemeManager`
    - **Value Name:** `ColorName`
    - **Type:** `REG_SZ`
    - **Value:** `NormalColor`
    - **Action:** Update

25. **SizeName**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\CurrentVersion\ThemeManager`
    - **Value Name:** `SizeName`
    - **Type:** `REG_SZ`
    - **Value:** `NormalSize`
    - **Action:** Update

26. **EnableTransparency**
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize`
    - **Value Name:** `EnableTransparency`
    - **Type:** `REG_DWORD`
    - **Value:** `0` (Disabled)
    - **Action:** Update

#### Application Startup Settings

27. **com.squirrel.Teams.Teams** (Microsoft Teams Auto-Start)
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `SOFTWARE\Microsoft\Windows\CurrentVersion\Run`
    - **Value Name:** `com.squirrel.Teams.Teams`
    - **Type:** `REG_SZ`
    - **Value:** (Empty)
    - **Action:** Delete
    - **Description:** "Dit item zorgt ervoor dat Teams niet automatisch opstart bij het inloggen." (Prevents Teams from auto-starting on login)
    - **Bypass Errors:** Yes

#### Additional Explorer Settings

28. **TaskbarDa** (Taskbar Daemon)
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
    - **Value Name:** `TaskbarDa`
    - **Type:** `REG_DWORD`
    - **Value:** `0` (Disabled)
    - **Action:** Update

#### Office/Outlook Logging Settings

29. **TCOTrace** (Office TCO Trace)
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Office\16.0\Common\Debug`
    - **Value Name:** `TCOTrace`
    - **Type:** `REG_DWORD`
    - **Value:** `0` (Disabled)
    - **Action:** Update

30. **EnableLogging** (Outlook Mail Logging)
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Office\16.0\Outlook\Options\Mail`
    - **Value Name:** `EnableLogging`
    - **Type:** `REG_DWORD`
    - **Value:** `0` (Disabled)
    - **Action:** Update

31. **EnableETWLogging** (Outlook ETW Logging)
    - **Hive:** `HKEY_CURRENT_USER`
    - **Key:** `Software\Microsoft\Office\16.0\Outlook\Options\Mail`
    - **Value Name:** `EnableETWLogging`
    - **Type:** `REG_DWORD`
    - **Value:** `0` (Disabled)
    - **Action:** Update

---

### Administrative Template Policies (User Configuration)

#### Internet Explorer Security

1. **Intranet Sites: Include all network paths (UNCs)**
   - **State:** Enabled
   - **Path:** `Windows Components/Internet Explorer/Internet Control Panel/Security Page`
   - **Description:** Maps all network paths (UNCs) into the Intranet security zone

2. **Site to Zone Assignment List**
   - **State:** Disabled
   - **Path:** `Windows Components/Internet Explorer/Internet Control Panel/Security Page`
   - **Description:** Not configured

3. **Show security warning for potentially unsafe files**
   - **State:** Enabled
   - **Path:** `Windows Components/Internet Explorer/Internet Control Panel/Security Page/Intranet Zone`
   - **Description:** Controls "Open File - Security Warning" message
   - **Sub-setting:** Launching programs and unsafe files = **Enabled**

---

### Additional Registry Settings (User Configuration)

#### Google Chrome Policies

1. **HardwareAccelerationModeEnabled**
   - **Key:** `software\policies\Google\Chrome`
   - **Value:** `0` (Disabled)

2. **SearchSuggestEnabled**
   - **Key:** `software\policies\Google\Chrome`
   - **Value:** `0` (Disabled)

3. **AllowDinosaurEasterEgg**
   - **Key:** `software\policies\Google\Chrome`
   - **Value:** `0` (Disabled)

4. **HighEfficiencyModeEnabled**
   - **Key:** `software\policies\Google\Chrome`
   - **Value:** `1` (Enabled)

#### Microsoft Office/Outlook Policies

5. **enablelogging** (Outlook)
   - **Key:** `software\policies\microsoft\office\16.0\outlook\options\mail`
   - **Value:** `0` (Disabled)

#### Windows Copilot

6. **TurnOffWindowsCopilot**
   - **Key:** `software\policies\microsoft\Windows\WindowsCopilot`
   - **Value:** `1` (Enabled - Copilot disabled)

---

## Summary

### Total Settings Count
- **Computer Configuration:** 8 Registry Preferences + 12 Administrative Template Policies = **20 settings**
- **User Configuration:** 31 Registry Preferences + 3 Administrative Template Policies + 6 Additional Registry Settings = **40 settings**
- **Total:** **60 settings**

### Key Optimization Areas

1. **Visual Effects Disabled:**
   - Task View button, animations, Aero Peek, transparency, shadows
   - Reduces GPU/CPU usage in AVD sessions

2. **Search Optimizations:**
   - Cortana disabled
   - Web search disabled
   - Cloud search enabled (for OneDrive/SharePoint)

3. **Chrome Optimizations:**
   - Background mode disabled
   - Hardware acceleration disabled
   - High efficiency mode enabled

4. **RDS Optimizations:**
   - Time zone redirection enabled
   - Client printer not set as default
   - Verbose status for printer operations

5. **Application Optimizations:**
   - Teams auto-start disabled
   - Outlook logging disabled
   - Windows Copilot disabled

6. **Performance Settings:**
   - Font smoothing configured
   - Window animations disabled
   - Visual effects optimized for remote sessions

---

## Notes

- **FSLogix Profile Location:** Correctly disabled in GPO (set via CIT during image creation)
- **Registry Preferences:** Most settings use "Update" action, ensuring they're applied even if manually changed
- **Bypass Errors:** Some settings have `bypassErrors="1"` to prevent GPO application failures if registry keys don't exist
- **Theme Settings:** Configured to use Aero theme with normal color/size, transparency disabled

