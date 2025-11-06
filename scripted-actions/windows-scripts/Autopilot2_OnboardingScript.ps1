#description: Configures Windows OOBE settings for Autopilot onboarding (sysprep-compatible)
#tags: Nerdio, Autopilot, OOBE, Registry

<#
Notes:
This script configures Windows Out-of-Box Experience (OOBE) registry settings to optimize the Autopilot onboarding process.
These settings are applied system-wide and are compatible with sysprep for AVD image templates.

Registry keys configured:
- DisablePrivacyExperience: Disables privacy experience prompts
- DisableVoice: Disables voice recognition setup
- PrivacyConsentStatus: Sets privacy consent status
- Protectyourpc: Configures Windows security settings
- HideEULAPage: Hides End User License Agreement page
- EnableFirstLogonAnimation: Disables first logon animation

These settings help streamline the user experience during Autopilot deployment.
#>

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# Define registry paths
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE"
$registryPath2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

# Ensure registry paths exist
Write-Host "Ensuring registry paths exist..."
if (!(Test-Path -Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
    Write-Host "Created registry path: $registryPath"
}

if (!(Test-Path -Path $registryPath2)) {
    New-Item -Path $registryPath2 -Force | Out-Null
    Write-Host "Created registry path: $registryPath2"
}

# Define registry values to set
$registrySettings = @(
    @{
        Path = $registryPath
        Name = "DisablePrivacyExperience"
        Value = 1
        Description = "Disable privacy experience prompts"
    },
    @{
        Path = $registryPath
        Name = "DisableVoice"
        Value = 1
        Description = "Disable voice recognition setup"
    },
    @{
        Path = $registryPath
        Name = "PrivacyConsentStatus"
        Value = 1
        Description = "Set privacy consent status"
    },
    @{
        Path = $registryPath
        Name = "Protectyourpc"
        Value = 3
        Description = "Configure Windows security settings"
    },
    @{
        Path = $registryPath
        Name = "HideEULAPage"
        Value = 1
        Description = "Hide End User License Agreement page"
    },
    @{
        Path = $registryPath2
        Name = "EnableFirstLogonAnimation"
        Value = 1
        Description = "Disable first logon animation"
    }
)

# Apply registry settings
Write-Host "Configuring Autopilot OOBE settings..."
$errorCount = 0

foreach ($setting in $registrySettings) {
    try {
        Write-Host "Setting $($setting.Name): $($setting.Description)..."
        New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        
        # Verify the setting was applied
        $verifyValue = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
        if ($verifyValue -and $verifyValue.$($setting.Name) -eq $setting.Value) {
            Write-Host "  Successfully set $($setting.Name) = $($setting.Value)"
        }
        else {
            Write-Warning "  Warning: Could not verify $($setting.Name) was set correctly"
            $errorCount++
        }
    }
    catch {
        Write-Error "  Failed to set $($setting.Name): $_"
        $errorCount++
    }
}

# Summary
if ($errorCount -eq 0) {
    Write-Host "All Autopilot OOBE settings configured successfully."
    Write-Host "These settings are sysprep-compatible and will persist through image capture."
    exit 0
}
else {
    Write-Error "Failed to configure $errorCount registry setting(s). Please review errors above."
    exit 1
}

### End Script ###
