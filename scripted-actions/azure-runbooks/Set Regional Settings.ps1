# description: Configure a VM with the defined regional settings.
# tags: Preview, Nerdio
<#
Notes:
This script is used to configure the Regional Settings on a VM. Keyboard layouts, Geo Id, MUI and User Locale are configured.

By default, this script sets English (United Kingdom) regional settings. The parameters can be overridden by:
- Defining $JsonParams variable in this script, or
- Defining a Nerdio Secure Variable called RegionSettings

New region settings will be applied for all users who log in after running this script.

Requires:
- Install the needed language packs first
- If a user has an existing profile, they will need to change their default region settings manually, or their profile will need to be recreated

To define the settings as a secure variable, in Nerdio manager, select Settings->Nerdio Environment, and create a 
new secure variable called RegionSettings. The value for this variable should be in the following format:

{"nation" : "242", "mui" : "en-GB", "muifallback" : "en-US", "locale" : "en-GB", "keyboardLayout" : "0809:00000809"}

Default settings (English United Kingdom):
- Nation (GeoID): 242 (United Kingdom)
- MUI: en-GB
- MUI Fallback: en-US
- Locale: en-GB
- Keyboard Layout: 0809:00000809 (UK English)

References for regional settings:
Nations:          https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations
Keyboard Layouts: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs

Based on a Nerdio Hackathon entry by:
Stefan Beckmann
stefan@beckmann.ch
@alphasteff
https://github.com/alphasteff
#>

<# Un-comment and modify the following variable definition to specify the region settings in this script
 
$JsonParams = '{
"nation" : "242",
"mui" : "en-GB",
"muifallback" : "en-US",
"locale" : "en-GB",
"keyboardLayout" : "0809:00000809"
}'

#>

# Default regional settings for English (United Kingdom)
$defaultRegionSettings = @{
    nation = "242"
    mui = "en-GB"
    muifallback = "en-US"
    locale = "en-GB"
    keyboardLayout = "0809:00000809"
}

# Set Error action
$errorActionPreference = "Stop"


# Get region settings from script, Nerdio Secure Variable, or use defaults (English United Kingdom)

if (!$JsonParams){
    if (!$SecureVars.RegionSettings) {
        # Use default English United Kingdom settings
        Write-Output "INFO: No region settings specified. Using default: English (United Kingdom)"
        $JsonParams = @{
            nation = $defaultRegionSettings.nation
            mui = $defaultRegionSettings.mui
            muifallback = $defaultRegionSettings.muifallback
            locale = $defaultRegionSettings.locale
            keyboardLayout = $defaultRegionSettings.keyboardLayout
        } | ConvertTo-Json -Compress
    } 
    else {
        $JsonParams = $SecureVars.RegionSettings
    }
}



# Ensure context is using correct subscription
$azureContext = Set-AzContext -SubscriptionId $AzureSubscriptionId -ErrorAction Stop

# Get the VM and reads out the tag
$azVM = Get-AzVM -Name $AzureVMName -ResourceGroupName $AzureResourceGroupName

$VMStatus = Get-AzVM -ResourceGroupName $AzureResourceGroupName -Name $AzureVMName -Status
if (!($VMStatus.Statuses.code -match 'running')) {
    Write-Output "Starting VM $AzureVMName"
    $azVM | Start-AzVM 
}

Try {
    # Convert JSON string to PSCustomObject (if it's a string) or use object directly
    if ($JsonParams -is [string]) {
        $regionalSettings = $JsonParams | ConvertFrom-Json
    } else {
        $regionalSettings = $JsonParams
    }

    # Create the hashtable for the parameters
    $parameters = @{
        nation = $regionalSettings.nation
        mui = $regionalSettings.mui
        muifallback = $regionalSettings.muifallback
        locale = $regionalSettings.locale
        keyboardLayout = $regionalSettings.keyboardLayout
    }
    
    Write-Output "INFO: Configuring regional settings:"
    Write-Output "  Nation (GeoID): $($parameters.nation)"
    Write-Output "  MUI: $($parameters.mui)"
    Write-Output "  MUI Fallback: $($parameters.muifallback)"
    Write-Output "  Locale: $($parameters.locale)"
    Write-Output "  Keyboard Layout: $($parameters.keyboardLayout)"

    Write-Output ('INFO: Parameters for RunCommand: ' + ($parameters | Out-String))

    # Define script block to run remote
    $scriptBlock ={
        param(
            [string] $nation,
            [string] $mui,
            [string] $muifallback,
            [string] $locale,
            [string] $keyboardLayout
        )

        [array]$keyboardLayouts = $keyboardLayout.Split(',')

        # Path to the xml file
        [string]$xmlFile = "$PSScriptRoot\RegionalSettings.xml"

        # Add fix for "The keyboard layout changes unexpectedly at logon"
        # https://dennisspan.com/solving-keyboard-layout-issues-in-an-ica-or-rdp-session/#IgnoreRemoteKeyboardLayout
        [string]$KeyboardLayoutPath = "HKLM:SYSTEM\CurrentControlSet\Control\Keyboard Layout\"
        $IgnoreRemoteKeyboardLayout = (Get-ItemProperty -Path $KeyboardLayoutPath -Name "IgnoreRemoteKeyboardLayout" -ErrorAction SilentlyContinue).IgnoreRemoteKeyboardLayout
        if($IgnoreRemoteKeyboardLayout -ne 1)
        {
            $null = New-ItemProperty -Path $KeyboardLayoutPath  -Name "IgnoreRemoteKeyboardLayout" -Value "1" -PropertyType DWORD -Force
        }

        # Boolean to define the first InputLanguageId as the default
        [bool]$firstrunKeyboardLayout = $true

        # Create XML
        $xmlWriter = New-Object System.XMl.XmlTextWriter($xmlFile,$Null)

        # Basic settings
        $xmlWriter.Formatting = 'Indented'
        $xmlWriter.Indentation = 1
        $XmlWriter.IndentChar = "`t"

        # Create content (https://docs.microsoft.com/en-us/troubleshoot/windows-client/deployment/automate-regional-language-settings)
        $xmlWriter.WriteStartDocument()

        $xmlWriter.WriteStartElement("gs:GlobalizationServices")
        $xmlWriter.WriteAttributeString("xmlns:gs","urn:longhornGlobalizationUnattend")

            # User list
            $xmlWriter.WriteStartElement("gs:UserList")
                $xmlWriter.WriteStartElement("gs:User")
                $xmlWriter.WriteAttributeString("UserID","Current")
                $xmlWriter.WriteAttributeString("CopySettingsToDefaultUserAcct","true")
                $xmlWriter.WriteAttributeString("CopySettingsToSystemAcct","true")
                $xmlWriter.WriteEndElement()
            $xmlWriter.WriteEndElement()

            # GeoID
            $xmlWriter.WriteStartElement("gs:LocationPreferences")
                $xmlWriter.WriteStartElement("gs:GeoID")
                $xmlWriter.WriteAttributeString("Value","$nation")
                $xmlWriter.WriteEndElement()
            $xmlWriter.WriteEndElement()

            # MUI Languages
            $xmlWriter.WriteStartElement("gs:MUILanguagePreferences")
                $xmlWriter.WriteStartElement("gs:MUILanguage")
                $xmlWriter.WriteAttributeString("Value","$mui")
                $xmlWriter.WriteEndElement()

                if (![string]::IsNullOrEmpty($muifallback)){
                    $xmlWriter.WriteStartElement("gs:MUIFallback")
                    $xmlWriter.WriteAttributeString("Value","$muifallback")
                    $xmlWriter.WriteEndElement()
                }
            $xmlWriter.WriteEndElement()

            # Input preferences
            $xmlWriter.WriteStartElement("gs:InputPreferences")
            foreach($kbLayout in $keyboardLayouts)
            {
                    $xmlWriter.WriteStartElement("gs:InputLanguageID")
                    $xmlWriter.WriteAttributeString("Action","add")
                    $xmlWriter.WriteAttributeString("ID","$($kbLayout.Trim())")
                if($firstrunKeyboardLayout)
                {
                    $firstrunKeyboardLayout = $false
                    $xmlWriter.WriteAttributeString("Default","true")
                }
                    $xmlWriter.WriteEndElement()
            }
            $xmlWriter.WriteEndElement()

            # User locale
            $xmlWriter.WriteStartElement("gs:UserLocale")
                $xmlWriter.WriteStartElement("gs:Locale")
                $xmlWriter.WriteAttributeString("SetAsCurrent","true")
                $xmlWriter.WriteAttributeString("Name","$locale")
                $xmlWriter.WriteEndElement()
            $xmlWriter.WriteEndElement()

        $xmlWriter.WriteEndElement()

        # Write and close document
        $xmlWriter.WriteEndDocument()
        $xmlWriter.Flush()
        $xmlWriter.Close()

        # Write-PSFMessage -Level Host -Message 'Configure Regional Settings'
        $null = control.exe "intl.cpl,,/f:`"$xmlFile`""
        $null = Start-Sleep -Seconds 5
        $null = Remove-Item -Path "$xmlFile" -Force

        # Create array with all keyboard ids
        $keyBoardIDs = [System.Collections.ArrayList]@()
        ForEach ($keyboardLayout in $keyboardLayouts){
            $keyboardLayoutId = $keyboardLayout.Split(":")[1]
            $null = $keyBoardIDs.Add($keyboardLayoutId)
        }

        # Remove all keyboard layouts that are not in the configuration and add the defined keyboard layouts
        For ($i=1; $i -le 20; $i++)
        {
            $keyboardId = (Get-ItemProperty -Path 'HKCU:\Keyboard Layout\Preload' -Name $i -ErrorAction SilentlyContinue).$i
            if($keyBoardIDs -notcontains $keyboardId)
            {
                #Write-PSFMessage -Level Host -Message "Remove Keyboard Layout $i"
                $null = Remove-ItemProperty -Path 'HKCU:\Keyboard Layout\Preload' -Name $i -ErrorAction SilentlyContinue
            }
        }
    }

    # Save the scriptblock to a file
    $null = Set-Content -Path .\RegionalSettings.ps1 -Value $scriptBlock

    # Run command on vm
    $result = Invoke-AzVMRunCommand -ResourceGroupName $AzureResourceGroupName -VMName $AzureVMName -CommandId 'RunPowerShellScript' -ScriptPath .\RegionalSettings.ps1 -Parameter $parameters

    Write-Output ('INFO: Result of RunCommand: ' + ($result | Out-String))

    # Remove temporary file
    $null = Remove-Item -Path .\RegionalSettings.ps1
}

catch{
    Throw $_
}

Finally{
    if (!($VMStatus.Statuses.code -match 'running'))  {
        write-output "stopping VM"
        $azVM | Stop-AzVM -Force
    }
}