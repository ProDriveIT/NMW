<#
.SYNOPSIS
    This script enforces MDM enrollment for a device by creating necessary registry keys. It makes use of a scheduled tasks to run this script. The scheduled task is created during image builder process.
    It checks the device's join status (Entra Hybrid Join and Domain Join) and performs actions accordingly,
    including a forced reboot if required (once) which forces the MDM enrollment process to complete.

.DESCRIPTION
    - Creates registry keys required for MDM enrollment.
    - Configures scheduled tasks to run the script at startup.
    - Validates the device's Entra Hybrid Join and Domain Join status.
    - Forces a reboot if the device is not properly enrolled.
    - Logs all actions and progress to a log file for troubleshooting and auditing purposes.

.NOTES
    - Do not remove the registry key "HKLM:\Software\AVD Management\HybridRebootOccured" with the value "DONOTREMOVE".
      This key ensures that the script does not force another unnecessary reboot.
    - Verify the enrollment status in the Intune portal after the script completes.

.AUTHOR
    Joey Verlinden / Bastiaan Schumans
#>

# Required Tenant ID - MODIFY THE TENANT ID!
$tenantId = '5af8tsa3-****-****-****-**********'

# Required KeyPath - DO NOT MODIFY OR REMOVE!
$KeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\$tenantId"

# Reboot validation path - DO NOT MODIFY OR REMOVE!
$rebootPath = "HKLM:\Software\AVD Management\HybridRebootOccured"
$rebootValueName = "DONOTREMOVE"

# Function to log messages with timestamps
function Write-Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    Add-Content -Path "c:\windows\temp\Force_MDM_Erollment.log" -Value $logMessage
    }

# Create required registry keys
if (-not (Test-Path $KeyPath)) {
    New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo" -Name $tenantId -Force | Out-Null
    Write-Log "Registry key $KeyPath created."
} else {
    Write-Log "Registry key $KeyPath already exists. Skipping creation."
}


# These registry keys are being removed while running "dsregcmd /join". Therefore, they might be obsolete but kept in the script for ensurance
if ((Get-ItemProperty -Path $KeyPath -Name 'MdmEnrollmentUrl' -ErrorAction SilentlyContinue).MdmEnrollmentUrl -ne 'https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc') {
    New-ItemProperty -LiteralPath $KeyPath -Name 'MdmEnrollmentUrl' -Value 'https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc' -PropertyType String -Force -ErrorAction SilentlyContinue
    Write-Log "Updated or created 'MdmEnrollmentUrl' registry value."
} else {
    Write-Log "Registry setting 'MdmEnrollmentUrl' already exists and matches."
}

if ((Get-ItemProperty -Path $KeyPath -Name 'MdmTermsOfUseUrl' -ErrorAction SilentlyContinue).MdmTermsOfUseUrl -ne 'https://portal.manage.microsoft.com/TermsofUse.aspx') {
    New-ItemProperty -LiteralPath $KeyPath -Name 'MdmTermsOfUseUrl' -Value 'https://portal.manage.microsoft.com/TermsofUse.aspx' -PropertyType String -Force -ErrorAction SilentlyContinue
    Write-Log "Updated or created 'MdmTermsOfUseUrl' registry value."
} else {
    Write-Log "Registry setting 'MdmTermsOfUseUrl' already exists and matches."
}

if ((Get-ItemProperty -Path $KeyPath -Name 'MdmComplianceUrl' -ErrorAction SilentlyContinue).MdmComplianceUrl -ne 'https://portal.manage.microsoft.com/?portalAction=Compliance') {
    New-ItemProperty -LiteralPath $KeyPath -Name 'MdmComplianceUrl' -Value 'https://portal.manage.microsoft.com/?portalAction=Compliance' -PropertyType String -Force -ErrorAction SilentlyContinue
    Write-Log "Updated or created 'MdmComplianceUrl' registry value."
} else {
    Write-Log "Registry setting 'MdmComplianceUrl' already exists and matches."
}

# Check if device is domain joined
try {
    $dsregStatus = dsregcmd /status 2>&1
    $domainJoinedMatch = $dsregStatus | Select-String "DomainJoined"
    if ($domainJoinedMatch) {
        $domainJoined = $domainJoinedMatch.ToString().Split(':')[1].Trim()
    } else {
        # If we can't parse the output, assume not domain joined (build time)
        Write-Log "Could not determine domain join status. Assuming build time (not domain joined)."
        $domainJoined = "NO"
    }
} catch {
    # If dsregcmd fails, assume not domain joined (build time)
    Write-Log "Error checking domain join status: $_. Assuming build time (not domain joined)."
    $domainJoined = "NO"
}

# If NOT domain joined (during build), create scheduled task and exit
if ($domainJoined -eq "NO") {
    Write-Log "Device is not domain joined (build time). Creating scheduled task to run enrollment check after domain join..."
    
    $TaskName = "Force-MDM-Enrollment"
    $ScriptPath = $PSCommandPath
    
    # Remove existing task if it exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Log "Removing existing scheduled task..."
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    # Create scheduled task action
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    
    # Create trigger - run at startup with 5 minute delay
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Trigger.Delay = New-TimeSpan -Minutes 5
    
    # Create settings
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)
    
    # Create principal - run as SYSTEM
    $Principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest
    
    # Register the scheduled task
    try {
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $Action `
            -Trigger $Trigger `
            -Settings $Settings `
            -Principal $Principal `
            -Description "Force MDM Enrollment - Runs after domain join to check Entra Hybrid Join status" `
            -ErrorAction Stop
        
        Write-Log "Scheduled task '$TaskName' created successfully. Task will run 5 minutes after startup (post-domain-join)."
        Write-Log "Script exiting - enrollment check will run via scheduled task after domain join."
        exit 0
    }
    catch {
        Write-Log "WARNING: Failed to create scheduled task: $_"
        Write-Log "The enrollment check will not run automatically. Manual intervention may be required."
        exit 1
    }
}

# If domain joined, continue with enrollment check logic
Write-Log "Device is domain joined. Running enrollment check logic..."

# Check if the registry key and value exist
if ((Test-Path $rebootPath) -and (Get-ItemProperty -Path $rebootPath -Name $rebootValueName -ErrorAction SilentlyContinue)) {
    Write-Log "Reboot already performed. Skipping reboot logic."

    # Check for Event ID 72 in a loop (with max retry limit)
    Write-Log "Checking for Event ID 72 to verify enrollment..."
    $maxRetries = 120  # 120 attempts * 30 seconds = 60 minutes max
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        $retryCount++
        $eventlog = Get-WinEvent -LogName "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Enrollment" -FilterXPath "*[System[(EventID=72)]]" -MaxEvents 1 -ErrorAction SilentlyContinue

        if ($eventlog) {
            Write-Log "Event ID 72 detected in Event Viewer. Enrollment successful."
            break
        } else {
            Write-Log "Event ID 72 not found. Retrying... (Attempt $retryCount/$maxRetries)"
            Start-Sleep 30
        }
    }
    
    if ($retryCount -ge $maxRetries) {
        Write-Log "WARNING: Maximum retry limit reached. Event ID 72 not detected. Please verify enrollment manually in the Intune portal."
    } else {
        Write-Log "Script completed. Enrollment process completed. Verify in the Intune portal."
    }

} else {
    # Loop to check Entra Hybrid Join status (with max retry limit)
    $maxAttempts = 120  # 120 attempts * 30 seconds = 60 minutes max
    $attemptCount = 0
    while ($attemptCount -lt $maxAttempts) {
        $attemptCount++
        Write-Log "Checking Entra Hybrid Join status... Attempt $attemptCount/$maxAttempts"

        $dsreg = dsregcmd /status

        $EntraIDJoined = ($dsreg | Select-String "AzureAdJoined").ToString().Split(':')[1].Trim()
        $domainJoined = ($dsreg | Select-String "DomainJoined").ToString().Split(':')[1].Trim()

        if ($EntraIDJoined -eq "YES" -and $domainJoined -eq "YES") {
            Write-Log "Device is Entra Hybrid Joined. Rebooting the device in 2 minutes..."

            # Create the registry key and value to indicate the reboot has occurred
            if (-not (Test-Path $rebootPath)) {
                New-Item -Path $rebootPath -Force | Out-Null
            }
            Set-ItemProperty -Path $rebootPath -Name $rebootValueName -Value 1 -Type DWord -Force

            # Reboot the device
            Start-Sleep -Seconds 120
            Restart-Computer -Force
            break
        } elseif ($EntraIDJoined -eq "NO" -and $domainJoined -eq "YES") {
            Write-Log "Device is Domain Joined but not Entra ID Joined."

            # Execute Hybrid Join
            Write-Log "Executing dsregcmd /join command..."
            Start-Process -FilePath "$env:SystemRoot\System32\dsregcmd.exe" -ArgumentList "/join" -NoNewWindow -Wait

            # Wait for a short period to allow the join process to complete
            Start-Sleep 60
        } else {
            Write-Log "Device is NOT Entra Hybrid Joined."
            Write-Log "EntraIDJoined: $EntraIDJoined"
            Write-Log "DomainJoined: $domainJoined"
        }

        Start-Sleep 30
        Write-Log "Retrying Entra Hybrid Join status check..."
    }
    
    if ($attemptCount -ge $maxAttempts) {
        Write-Log "WARNING: Maximum retry limit reached ($maxAttempts attempts). Entra Hybrid Join check stopped."
        Write-Log "Please verify domain join and Entra Hybrid Join status manually."
    }
}