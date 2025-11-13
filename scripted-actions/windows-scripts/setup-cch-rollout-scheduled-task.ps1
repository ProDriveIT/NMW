#description: Creates scheduled task for CCH Rollout using domain account (runs after domain join)
#tags: Nerdio, CCH Apps, Scheduled Task, Domain Account

#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Creates a scheduled task to run CCH Rollout batch file using a domain account with network access.

.DESCRIPTION
    This script creates a scheduled task to run the CCH Central RDS Roll-Out Update Script batch file.
    The task runs as a domain account, which has network access to \\CAAZURAPP01\CENTRALCLIENT.
    
    During CIT build (pre-domain-join), the task is created but won't run until after domain join.
    After domain join, the scheduled task will run the batch file automatically on startup.
    
    This script should be run AFTER the upload-cch-apps.ps1 script has completed successfully.
    
    For CIT deployment, provide domain account and password as parameters or environment variables.

.PARAMETER DomainAccount
    Domain account to run the task (e.g., DOMAIN\username or username@domain.com)
    Can also be set via environment variable: CCH_DOMAIN_ACCOUNT

.PARAMETER DomainPassword
    Password for the domain account
    Can also be set via environment variable: CCH_DOMAIN_PASSWORD
    WARNING: For security, prefer using environment variables or secure credential storage

.EXAMPLE
    .\setup-cch-rollout-scheduled-task.ps1 -DomainAccount "DOMAIN\svc_cch" -DomainPassword "SecurePassword123"

.EXAMPLE
    # Using environment variables (recommended for CIT)
    $env:CCH_DOMAIN_ACCOUNT = "DOMAIN\svc_cch"
    $env:CCH_DOMAIN_PASSWORD = "SecurePassword123"
    .\setup-cch-rollout-scheduled-task.ps1

.NOTES
    Requires: Administrator privileges
    During CIT: Creates scheduled task with domain credentials (task won't run until after domain join)
    After domain join: Scheduled task runs batch file automatically on startup with network access
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DomainAccount = $env:CCH_DOMAIN_ACCOUNT,
    
    [Parameter(Mandatory = $false)]
    [string]$DomainPassword = $env:CCH_DOMAIN_PASSWORD
)

# Set error action to Continue so errors don't stop execution during CIT
$ErrorActionPreference = 'Continue'

# Wrap entire script in try-catch to ensure we ALWAYS exit with 0
try {
    Write-Output "=========================================="
    Write-Output "CCH Rollout Scheduled Task Setup"
    Write-Output "=========================================="
    Write-Output ""

    # Configuration
    $TaskName = "CCH-Central-Rollout"
    $BatchFilePath = "C:\CCHAPPS\CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat"
    $WorkingDirectory = "C:\CCHAPPS"

    # Get domain account credentials
    if ([string]::IsNullOrWhiteSpace($DomainAccount)) {
        # Try to prompt if running interactively (not during CIT)
        if ([Environment]::UserInteractive) {
            Write-Host "Enter domain account to run the task (e.g., DOMAIN\username or username@domain.com):" -ForegroundColor Yellow
            $DomainAccount = Read-Host "Domain Account"
        }
        
        if ([string]::IsNullOrWhiteSpace($DomainAccount)) {
            Write-Warning "Domain account not provided. Task will be created but may not have network access."
            Write-Warning "Provide domain account via -DomainAccount parameter or CCH_DOMAIN_ACCOUNT environment variable."
            # Continue anyway - task can be updated later
        }
    }

    if ([string]::IsNullOrWhiteSpace($DomainPassword)) {
        # Try to prompt if running interactively (not during CIT)
        if ([Environment]::UserInteractive -and -not [string]::IsNullOrWhiteSpace($DomainAccount)) {
            Write-Host "Enter password for $DomainAccount :" -ForegroundColor Yellow
            $SecurePassword = Read-Host "Password" -AsSecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
            $DomainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
        
        if ([string]::IsNullOrWhiteSpace($DomainPassword) -and -not [string]::IsNullOrWhiteSpace($DomainAccount)) {
            Write-Warning "Domain password not provided. Task will be created but may fail to run."
            Write-Warning "Provide domain password via -DomainPassword parameter or CCH_DOMAIN_PASSWORD environment variable."
            # Continue anyway - task can be updated later
        }
    }

    # Verify batch file exists
    if (-not (Test-Path $BatchFilePath)) {
        Write-Warning "Batch file not found: $BatchFilePath"
        Write-Host "The scheduled task will be created, but it will fail if the batch file is not present." -ForegroundColor Yellow
        Write-Host "This is expected during CIT build - batch file will be available after CCH Apps upload." -ForegroundColor Gray
    }

    # Create working directory if it doesn't exist
    if (-not (Test-Path $WorkingDirectory)) {
        New-Item -Path $WorkingDirectory -ItemType Directory -Force | Out-Null
        Write-Output "Created working directory: $WorkingDirectory"
    }

    # Remove existing task if it exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Output "Removing existing scheduled task..."
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Output "Existing task removed"
    }

    # Determine which account to use
    $UseDomainAccount = $false
    if (-not [string]::IsNullOrWhiteSpace($DomainAccount) -and -not [string]::IsNullOrWhiteSpace($DomainPassword)) {
        $UseDomainAccount = $true
        Write-Output "Using domain account: $DomainAccount" -ForegroundColor Green
    }
    else {
        Write-Warning "Domain credentials not provided - task will run as SYSTEM (may not have network access)"
        Write-Warning "For network access, provide domain account credentials via parameters or environment variables"
    }

    # Create action to run batch file with domain join check
    # The batch file will check if device is domain-joined before running
    # Also handles PAUSE command at end of batch file (line 57)
    $BatchScript = @"
@echo off
REM Check if device is domain-joined before running CCH rollout
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {
    `$dsreg = dsregcmd /status
    `$domainJoined = (`$dsreg | Select-String 'DomainJoined').ToString().Split(':')[1].Trim()
    if (`$domainJoined -eq 'YES') {
        Write-Output 'Device is domain-joined. Running CCH rollout...'
        cd /d '$WorkingDirectory'
        REM Pipe echo. to handle PAUSE command (line 57 of batch file)
        echo. | cmd.exe /c call `"$BatchFilePath`"
        Write-Output 'CCH rollout batch file execution completed.'
    } else {
        Write-Output 'Device is not domain-joined yet. Exiting. Will retry on next startup.'
    }
}"
"@

    # Save the wrapper script
    $WrapperScript = "$WorkingDirectory\RunCCHRolloutWithCheck.bat"
    $BatchScript | Out-File -FilePath $WrapperScript -Encoding ASCII -Force
    
    # Create action to run wrapper script
    $Action = New-ScheduledTaskAction -Execute "cmd.exe" `
        -Argument "/c `"$WrapperScript`"" `
        -WorkingDirectory $WorkingDirectory

    # Create trigger - run at startup with delay
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Trigger.Delay = New-TimeSpan -Minutes 5  # Delay 5 minutes after startup

    # Create settings
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)

    # Create principal
    if ($UseDomainAccount) {
        $Principal = New-ScheduledTaskPrincipal `
            -UserId $DomainAccount `
            -LogonType Password `
            -RunLevel Highest
    }
    else {
        # Fallback to SYSTEM account if domain credentials not provided
        $Principal = New-ScheduledTaskPrincipal `
            -UserId "SYSTEM" `
            -LogonType ServiceAccount `
            -RunLevel Highest
    }

    # Register the scheduled task
    Write-Output "Creating scheduled task..."
    $TaskCreated = $false
    
    try {
        if ($UseDomainAccount) {
            # Create credential object for domain account
            $SecurePassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($DomainAccount, $SecurePassword)
            
            Register-ScheduledTask `
                -TaskName $TaskName `
                -Action $Action `
                -Trigger $Trigger `
                -Settings $Settings `
                -Principal $Principal `
                -User $DomainAccount `
                -Password $DomainPassword `
                -Description "Runs CCH Central RDS Roll Out batch file using domain account with network access" `
                -ErrorAction Stop | Out-Null
            
            # Clear password from memory
            $DomainPassword = $null
            $SecurePassword = $null
            $Credential = $null
        }
        else {
            # Use SYSTEM account (fallback)
            Register-ScheduledTask `
                -TaskName $TaskName `
                -Action $Action `
                -Trigger $Trigger `
                -Settings $Settings `
                -Principal $Principal `
                -Description "Runs CCH Central RDS Roll Out batch file (SYSTEM account - may not have network access)" `
                -ErrorAction Stop | Out-Null
        }
        
        $TaskCreated = $true
        Write-Output "Scheduled task created successfully!" -ForegroundColor Green
        Write-Output ""
        Write-Output "Task Details:" -ForegroundColor Cyan
        Write-Output "  Name: $TaskName"
        Write-Output "  Account: $(if ($UseDomainAccount) { $DomainAccount } else { 'SYSTEM' })"
        Write-Output "  Trigger: At startup (5 minute delay)"
        Write-Output "  Batch File: $BatchFilePath"
        Write-Output "  Domain Join Check: Enabled (will only run after domain join)"
        Write-Output ""
        
        if ($UseDomainAccount) {
            Write-Output "The task will:" -ForegroundColor Green
            Write-Output "  1. Check if device is domain-joined" -ForegroundColor Gray
            Write-Output "  2. Run CCH rollout batch file (if domain-joined)" -ForegroundColor Gray
            Write-Output "  3. Retry on next startup if not domain-joined yet" -ForegroundColor Gray
            Write-Output "  4. Run with network access (domain account)" -ForegroundColor Gray
        }
        else {
            Write-Output "WARNING: Task created but may not have network access (running as SYSTEM)." -ForegroundColor Yellow
            Write-Output "Update task with domain credentials for network access." -ForegroundColor Yellow
            Write-Output ""
            Write-Output "The task will:" -ForegroundColor Yellow
            Write-Output "  1. Check if device is domain-joined" -ForegroundColor Gray
            Write-Output "  2. Run CCH rollout batch file (if domain-joined)" -ForegroundColor Gray
            Write-Output "  3. Retry on next startup if not domain-joined yet" -ForegroundColor Gray
        }
        
        Write-Output ""
        Write-Output "To run manually, use: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Failed to create scheduled task: $_"
        Write-Warning "Task creation failed, but build will continue."
        $TaskCreated = $false
    }

    Write-Output ""
    Write-Output "=========================================="
    Write-Output "Setup Complete"
    Write-Output "=========================================="
    
    if (-not $TaskCreated) {
        Write-Warning "Scheduled task was not created, but script completed successfully."
        Write-Warning "You can create the task manually after deployment if needed."
    }
}
catch {
    # Catch ANY error and log it, but don't fail
    Write-Warning "An error occurred: $_"
    Write-Warning "Script will exit with success code to prevent build failure."
}
finally {
    # ALWAYS exit with 0 - no matter what happened (CIT requirement)
    exit 0
}
