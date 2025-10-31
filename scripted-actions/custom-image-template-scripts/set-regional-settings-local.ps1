#description: Configure regional settings on local Windows machine
#execution mode: Individual
#tags: Windows, Configuration, Regional Settings

<#
.SYNOPSIS
    Configures regional settings (locale, keyboard, GeoID) on a local Windows machine.

.DESCRIPTION
    This script configures regional settings including keyboard layouts, GeoID, MUI and User Locale.
    By default, sets English (United Kingdom) settings. Can be customized via parameters.
    
    New region settings will be applied for all users who log in after running this script.

.PARAMETER Nation
    GeoID value (numeric). Default: 242 (United Kingdom)
    See: https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations

.PARAMETER MUI
    Multilingual User Interface language tag. Default: "en-GB"

.PARAMETER MUIFallback
    Fallback MUI language tag. Default: "en-US"

.PARAMETER Locale
    User locale tag. Default: "en-GB"

.PARAMETER KeyboardLayout
    Keyboard layout ID(s) in format "ID:LayoutID" (comma-separated for multiple).
    Default: "0809:00000809" (UK English)
    See: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs

.EXAMPLE
    .\set-regional-settings-local.ps1
    Sets English (United Kingdom) settings using defaults.

.EXAMPLE
    .\set-regional-settings-local.ps1 -Nation "242" -MUI "en-GB" -Locale "en-GB" -KeyboardLayout "0809:00000809"
    Explicitly sets English (United Kingdom) settings.

.EXAMPLE
    .\set-regional-settings-local.ps1 -Nation "223" -MUI "de-DE" -Locale "de-CH" -KeyboardLayout "0807:00000807"
    Sets German (Switzerland) settings.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Nation = "242",
    
    [Parameter(Mandatory=$false)]
    [string]$MUI = "en-GB",
    
    [Parameter(Mandatory=$false)]
    [string]$MUIFallback = "en-US",
    
    [Parameter(Mandatory=$false)]
    [string]$Locale = "en-GB",
    
    [Parameter(Mandatory=$false)]
    [string]$KeyboardLayout = "0809:00000809"
)

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Configure Regional Settings" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "INFO: Configuring regional settings:" -ForegroundColor Yellow
Write-Host "  Nation (GeoID): $Nation" -ForegroundColor Gray
Write-Host "  MUI: $MUI" -ForegroundColor Gray
Write-Host "  MUI Fallback: $MUIFallback" -ForegroundColor Gray
Write-Host "  Locale: $Locale" -ForegroundColor Gray
Write-Host "  Keyboard Layout: $KeyboardLayout" -ForegroundColor Gray
Write-Host ""

try {
    [array]$keyboardLayouts = $KeyboardLayout.Split(',')

    # Path to the xml file (use temp directory)
    [string]$xmlFile = Join-Path $env:TEMP "RegionalSettings.xml"

    # Add fix for "The keyboard layout changes unexpectedly at logon"
    # https://dennisspan.com/solving-keyboard-layout-issues-in-an-ica-or-rdp-session/#IgnoreRemoteKeyboardLayout
    Write-Host "INFO: Configuring keyboard layout registry fix..." -ForegroundColor Yellow
    [string]$KeyboardLayoutPath = "HKLM:SYSTEM\CurrentControlSet\Control\Keyboard Layout"
    if (!(Test-Path $KeyboardLayoutPath)) {
        New-Item -Path $KeyboardLayoutPath -Force | Out-Null
    }
    
    $IgnoreRemoteKeyboardLayout = (Get-ItemProperty -Path $KeyboardLayoutPath -Name "IgnoreRemoteKeyboardLayout" -ErrorAction SilentlyContinue).IgnoreRemoteKeyboardLayout
    if ($IgnoreRemoteKeyboardLayout -ne 1) {
        New-ItemProperty -Path $KeyboardLayoutPath -Name "IgnoreRemoteKeyboardLayout" -Value "1" -PropertyType DWORD -Force | Out-Null
        Write-Host "INFO: Set IgnoreRemoteKeyboardLayout registry key" -ForegroundColor Green
    } else {
        Write-Host "INFO: IgnoreRemoteKeyboardLayout registry key already set" -ForegroundColor Gray
    }

    # Boolean to define the first InputLanguageId as the default
    [bool]$firstrunKeyboardLayout = $true

    Write-Host "INFO: Creating regional settings XML file..." -ForegroundColor Yellow
    
    # Create XML
    $xmlWriter = New-Object System.XMl.XmlTextWriter($xmlFile, $Null)

    # Basic settings
    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 1
    $XmlWriter.IndentChar = "`t"

    # Create content (https://docs.microsoft.com/en-us/troubleshoot/windows-client/deployment/automate-regional-language-settings)
    $xmlWriter.WriteStartDocument()

    $xmlWriter.WriteStartElement("gs:GlobalizationServices")
    $xmlWriter.WriteAttributeString("xmlns:gs", "urn:longhornGlobalizationUnattend")

        # User list
        $xmlWriter.WriteStartElement("gs:UserList")
            $xmlWriter.WriteStartElement("gs:User")
            $xmlWriter.WriteAttributeString("UserID", "Current")
            $xmlWriter.WriteAttributeString("CopySettingsToDefaultUserAcct", "true")
            $xmlWriter.WriteAttributeString("CopySettingsToSystemAcct", "true")
            $xmlWriter.WriteEndElement()
        $xmlWriter.WriteEndElement()

        # GeoID
        $xmlWriter.WriteStartElement("gs:LocationPreferences")
            $xmlWriter.WriteStartElement("gs:GeoID")
            $xmlWriter.WriteAttributeString("Value", $Nation)
            $xmlWriter.WriteEndElement()
        $xmlWriter.WriteEndElement()

        # MUI Languages
        $xmlWriter.WriteStartElement("gs:MUILanguagePreferences")
            $xmlWriter.WriteStartElement("gs:MUILanguage")
            $xmlWriter.WriteAttributeString("Value", $MUI)
            $xmlWriter.WriteEndElement()

            if (![string]::IsNullOrEmpty($MUIFallback)) {
                $xmlWriter.WriteStartElement("gs:MUIFallback")
                $xmlWriter.WriteAttributeString("Value", $MUIFallback)
                $xmlWriter.WriteEndElement()
            }
        $xmlWriter.WriteEndElement()

        # Input preferences
        $xmlWriter.WriteStartElement("gs:InputPreferences")
        foreach ($kbLayout in $keyboardLayouts) {
            $xmlWriter.WriteStartElement("gs:InputLanguageID")
            $xmlWriter.WriteAttributeString("Action", "add")
            $xmlWriter.WriteAttributeString("ID", $kbLayout.Trim())
            if ($firstrunKeyboardLayout) {
                $firstrunKeyboardLayout = $false
                $xmlWriter.WriteAttributeString("Default", "true")
            }
            $xmlWriter.WriteEndElement()
        }
        $xmlWriter.WriteEndElement()

        # User locale
        $xmlWriter.WriteStartElement("gs:UserLocale")
            $xmlWriter.WriteStartElement("gs:Locale")
            $xmlWriter.WriteAttributeString("SetAsCurrent", "true")
            $xmlWriter.WriteAttributeString("Name", $Locale)
            $xmlWriter.WriteEndElement()
        $xmlWriter.WriteEndElement()

    $xmlWriter.WriteEndElement()

    # Write and close document
    $xmlWriter.WriteEndDocument()
    $xmlWriter.Flush()
    $xmlWriter.Close()

    Write-Host "INFO: Applying regional settings..." -ForegroundColor Yellow
    
    # Apply the regional settings using control.exe
    $result = Start-Process -FilePath "control.exe" -ArgumentList "intl.cpl,,/f:`"$xmlFile`"" -Wait -PassThru -NoNewWindow
    
    if ($result.ExitCode -eq 0) {
        Write-Host "INFO: Regional settings XML applied successfully" -ForegroundColor Green
    } else {
        Write-Warning "Control.exe returned exit code: $($result.ExitCode)"
    }
    
    Start-Sleep -Seconds 3
    
    # Clean up XML file
    if (Test-Path $xmlFile) {
        Remove-Item -Path $xmlFile -Force -ErrorAction SilentlyContinue
        Write-Host "INFO: Cleaned up temporary XML file" -ForegroundColor Gray
    }

    # Configure keyboard layouts in registry
    Write-Host "INFO: Configuring keyboard layouts..." -ForegroundColor Yellow
    
    # Create array with all keyboard ids
    $keyBoardIDs = [System.Collections.ArrayList]@()
    foreach ($keyboardLayout in $keyboardLayouts) {
        $keyboardLayoutId = $keyboardLayout.Split(":")[1]
        $null = $keyBoardIDs.Add($keyboardLayoutId)
    }

    # Remove all keyboard layouts that are not in the configuration and add the defined keyboard layouts
    # Note: This modifies HKCU, which affects the current user. For system-wide changes, additional configuration may be needed.
    $hklmKeyboardPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout\Preload"
    if (!(Test-Path $hklmKeyboardPath)) {
        New-Item -Path $hklmKeyboardPath -Force | Out-Null
    }
    
    For ($i = 1; $i -le 20; $i++) {
        $keyboardId = (Get-ItemProperty -Path $hklmKeyboardPath -Name $i -ErrorAction SilentlyContinue).$i
        if ($keyBoardIDs -notcontains $keyboardId -and $keyboardId) {
            Remove-ItemProperty -Path $hklmKeyboardPath -Name $i -ErrorAction SilentlyContinue
        }
    }
    
    # Set the default keyboard layout
    $firstLayoutId = $keyboardLayouts[0].Split(":")[1]
    Set-ItemProperty -Path $hklmKeyboardPath -Name "1" -Value $firstLayoutId -Force
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Regional settings configured successfully!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Note: New region settings will be applied for all users who log in after this." -ForegroundColor Yellow
    Write-Host "If a user has an existing profile, they may need to change their default region" -ForegroundColor Yellow
    Write-Host "settings manually, or their profile may need to be recreated." -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Error "Failed to configure regional settings: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    
    # Clean up on error
    if (Test-Path $xmlFile) {
        Remove-Item -Path $xmlFile -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}

