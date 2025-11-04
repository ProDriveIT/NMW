#description: (PREVIEW) Configures policy settings for Microsoft Edge meant to optimize performance in AVD
#tags: Nerdio, Preview
<#
Notes:
This script configures policy settings for Microsoft Edge meant to optimize performance in AVD environments.
Policies Set: 
    - Enable Sleeping Tabs ("sleep" inactive browser tabs) - Reduces memory usage for inactive tabs
    - Disable Startup Boost - Prevents Edge from preloading at login, reducing resource usage
    - Disable Background Mode - Prevents Edge from running in background when closed
    - Enable Efficiency Mode - Reduces resource consumption in VDI environments
    - Hide First Run Experience - Improves login performance by skipping initial setup
    - Disable Recommendations - Reduces background activity and resource usage
    - Disable Web Widget - Reduces background activity
#>

# Set registry settings for AVD optimization
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge /v "SleepingTabsEnabled" /t REG_DWORD /d 1 /f
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge /v "StartupBoostEnabled" /t REG_DWORD /d 0 /f
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge /v "BackgroundModeEnabled" /t REG_DWORD /d 0 /f
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge /v "EfficiencyMode" /t REG_DWORD /d 1 /f
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge /v "HideFirstRunExperience" /t REG_DWORD /d 1 /f
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge /v "ShowRecommendationsEnabled" /t REG_DWORD /d 0 /f
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge /v "WebWidgetAllowed" /t REG_DWORD /d 0 /f
