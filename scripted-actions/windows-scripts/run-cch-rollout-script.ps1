#description: Runs the CCH Central RDS Roll-Out Update Script batch file
#tags: Nerdio, CCH Apps, Batch execution

<#
Notes:
This script runs the CCH Central RDS Roll-Out Update Script batch file located in C:\CCHAPPS\.
This script should be run AFTER the upload-cch-apps.ps1 script has completed successfully.

The batch file will be executed with administrative privileges and the script will wait for completion.

IMPORTANT - Network Connectivity:
The CCH rollout batch script REQUIRES network access to the file server CAAZURAPP01 to:
- Copy files from \\CAAZURAPP01\CENTRALCLIENT\ shares
- Import registry files from network shares
- Copy shortcuts and configuration files

During CIT build, the device will NOT have access to this internal file server. This script includes options to:
1. Check for connectivity to CAAZURAPP01 before running
2. Skip execution during CIT build if file server is unavailable (set $SkipIfNoNetwork = $true)
3. Create a scheduled task to run the script on first boot when network/file server is available

By default, the script will attempt to run but will check for file server connectivity first.
#>

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# Configuration: Set to $true to skip execution if file server is unavailable (RECOMMENDED for CIT builds)
# Set to $false to attempt execution regardless of file server availability
# NOTE: For CIT builds, this should be $true since CAAZURAPP01 won't be accessible during build
$SkipIfNoNetwork = $true

# Configuration: Set to $true to create a scheduled task to run on first boot if file server is unavailable
# This ensures the script runs when the device is on the network after deployment
$CreateScheduledTaskIfNoNetwork = $true

# Configuration: Set to $true to run the rollout script on EVERY boot (continuous validation/sync)
# Set to $false to run only ONCE (runs once, then self-deletes scheduled task)
# 
# Run Every Boot Benefits:
# - Keeps all hosts in sync with CAAZURAPP01 source automatically
# - Picks up updates from file server on each boot
# - Validates deployment is correct on every boot
# - robocopy /MIR is efficient (only copies changed files)
# - Registry imports and DLL registration are idempotent (safe to run repeatedly)
#
# Run Once Benefits:
# - Faster boot times (no script execution after first run)
# - Preserves any user customizations after initial deployment
# - Lower network traffic after initial sync
#
# RECOMMENDATION: Set to $true if you want continuous validation and automatic updates from source
$RunOnEveryBoot = $false

# Define the required file server (from batch file analysis)
$RequiredFileServer = "CAAZURAPP01"

# Define the batch file path
$BatchFilePath = "C:\CCHAPPS\CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat"

# Function to test network connectivity to required file server
function Test-NetworkConnectivity {
    Write-Host "Testing connectivity to required file server: $RequiredFileServer"
    Write-Host "The CCH rollout script requires access to \\$RequiredFileServer\ shares"
    Write-Host ""
    
    $connected = $false
    
    # Test 1: Ping the file server
    Write-Host "Testing ping connectivity to $RequiredFileServer..."
    try {
        $pingResult = Test-Connection -ComputerName $RequiredFileServer -Count 2 -Quiet -ErrorAction SilentlyContinue
        if ($pingResult) {
            Write-Host "Ping test successful - $RequiredFileServer is reachable" -ForegroundColor Green
            $connected = $true
        }
        else {
            Write-Warning "Ping test failed - $RequiredFileServer is not reachable"
        }
    }
    catch {
        Write-Warning "Ping test failed: $_"
    }
    
    # Test 2: Check if we can access the file share (if ping succeeded)
    if ($connected) {
        Write-Host "Testing file share access to \\$RequiredFileServer\CENTRALCLIENT..."
        try {
            $sharePath = "\\$RequiredFileServer\CENTRALCLIENT"
            $shareAccessible = Test-Path -Path $sharePath -ErrorAction SilentlyContinue
            
            if ($shareAccessible) {
                Write-Host "File share access confirmed - \\$RequiredFileServer\CENTRALCLIENT is accessible" -ForegroundColor Green
            }
            else {
                Write-Warning "File share not accessible - \\$RequiredFileServer\CENTRALCLIENT may require authentication"
                Write-Warning "The batch script may still work if credentials are cached or provided during execution"
                # Don't set $connected = $false here, as ping succeeded and share might need auth
            }
        }
        catch {
            Write-Warning "File share access test failed: $_"
            Write-Warning "The batch script may still work if credentials are available"
        }
    }
    
    if (-not $connected) {
        Write-Warning "File server connectivity test failed - $RequiredFileServer is not reachable"
        Write-Warning "The CCH rollout script will fail without access to this file server"
    }
    
    return $connected
}

# Function to create scheduled task to run script on next boot
function New-ScheduledTaskForRollout {
    Write-Host "Creating scheduled task to run CCH rollout script on next boot..."
    
    $TaskName = "CCH-Rollout-Script-On-Boot"
    
    if ($RunOnEveryBoot) {
        $TaskDescription = "Runs CCH Central RDS Roll-Out Update Script on every system boot when network is available (continuous validation/sync)"
        Write-Host "Mode: Run on EVERY boot (continuous validation and sync with CAAZURAPP01)" -ForegroundColor Cyan
    }
    else {
        $TaskDescription = "Runs CCH Central RDS Roll-Out Update Script on system boot when network is available (runs once, then self-deletes)"
        Write-Host "Mode: Run ONCE, then self-delete (one-time deployment)" -ForegroundColor Cyan
    }
    
    $CompletionFlagFile = "C:\CCHAPPS\CCH_Rollout_Completed.flag"
    
    try {
        # Remove existing task if it exists
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "Removed existing scheduled task: $TaskName"
        }
        
        # Create a wrapper PowerShell script
        if ($RunOnEveryBoot) {
            # Wrapper for "run every boot" mode - validates and syncs on every boot
            $WrapperScript = @"
# Wrapper script for CCH Rollout - runs on every boot for continuous validation/sync
`$LogFile = "C:\CCHAPPS\CCH-Rollout-Wrapper.log"
`$TaskName = "$TaskName"
`$BatchFilePath = "$BatchFilePath"
`$RequiredFileServer = "$RequiredFileServer"

# Function to write log with timestamp
function Write-Log {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logMessage = "[`$timestamp] `$Message"
    Add-Content -Path `$LogFile -Value `$logMessage -ErrorAction SilentlyContinue
    Write-Host `$logMessage
}

# Start logging
Write-Log "=== CCH Rollout Wrapper Started (Every Boot Mode) ==="
Write-Log "Batch file path: `$BatchFilePath"
Write-Log "Required file server: `$RequiredFileServer"

# Ensure working directory exists
Set-Location "C:\CCHAPPS" -ErrorAction SilentlyContinue
Write-Log "Working directory: `$(Get-Location)"

# Check if batch file exists
if (-not (Test-Path `$BatchFilePath)) {
    Write-Log "ERROR: Batch file not found at `$BatchFilePath"
    exit 1
}

# Check file server connectivity
Write-Log "Checking connectivity to `$RequiredFileServer..."
`$pingResult = Test-Connection -ComputerName `$RequiredFileServer -Count 2 -Quiet -ErrorAction SilentlyContinue
if (-not `$pingResult) {
    Write-Log "WARNING: `$RequiredFileServer is not reachable. Task will retry on next boot."
    exit 1
}
Write-Log "Connectivity check passed - `$RequiredFileServer is reachable"

# Run the batch file (runs every boot to keep in sync with source)
Write-Log "Running CCH Rollout batch file (continuous validation/sync mode)..."
Write-Log "This ensures the host stays in sync with `$RequiredFileServer and validates deployment."
# Validate batch file path is not empty
if ([string]::IsNullOrWhiteSpace(`$BatchFilePath)) {
    Write-Log "ERROR: Batch file path is null or empty"
    exit 1
}

# Use full path to cmd.exe and ensure proper working directory
`$cmdPath = `$env:ComSpec
if (-not `$cmdPath) { `$cmdPath = "C:\Windows\System32\cmd.exe" }
Write-Log "Using cmd.exe: `$cmdPath"
Write-Log "Batch file: `$BatchFilePath"
Write-Log "Working directory: C:\CCHAPPS"

# Construct command line arguments - ensure proper quoting
`$batchFileQuoted = "`"`$BatchFilePath`""
`$arguments = @("/c", `$batchFileQuoted)

try {
    `$process = Start-Process -FilePath `$cmdPath -ArgumentList `$arguments -WorkingDirectory "C:\CCHAPPS" -Wait -NoNewWindow -PassThru -ErrorAction Stop
    Write-Log "Batch file process completed. Exit code: `$(`$process.ExitCode)"
} catch {
    Write-Log "ERROR: Failed to start batch file process: `$_"
    exit 1
}

if (`$process.ExitCode -eq 0) {
    Write-Log "SUCCESS: CCH Rollout completed successfully. Host is validated and in sync with source."
    exit 0
}
else {
    Write-Log "WARNING: CCH Rollout completed with exit code: `$(`$process.ExitCode)"
    Write-Log "Task will retry on next boot."
    exit `$process.ExitCode
}
"@
        }
        else {
            # Wrapper for "run once" mode - runs once then self-deletes
            $WrapperScript = @"
# Wrapper script for CCH Rollout - runs once then self-deletes scheduled task
`$LogFile = "C:\CCHAPPS\CCH-Rollout-Wrapper.log"
`$TaskName = "$TaskName"
`$BatchFilePath = "$BatchFilePath"
`$CompletionFlagFile = "$CompletionFlagFile"
`$RequiredFileServer = "$RequiredFileServer"

# Function to write log with timestamp
function Write-Log {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logMessage = "[`$timestamp] `$Message"
    Add-Content -Path `$LogFile -Value `$logMessage -ErrorAction SilentlyContinue
    Write-Host `$logMessage
}

# Start logging
Write-Log "=== CCH Rollout Wrapper Started (Run Once Mode) ==="
Write-Log "Batch file path: `$BatchFilePath"
Write-Log "Required file server: `$RequiredFileServer"
Write-Log "Completion flag file: `$CompletionFlagFile"

# Ensure working directory exists
Set-Location "C:\CCHAPPS" -ErrorAction SilentlyContinue
Write-Log "Working directory: `$(Get-Location)"

# Check if batch file exists
if (-not (Test-Path `$BatchFilePath)) {
    Write-Log "ERROR: Batch file not found at `$BatchFilePath"
    exit 1
}

# Check if already completed
if (Test-Path `$CompletionFlagFile) {
    Write-Log "CCH Rollout already completed. Removing scheduled task..."
    `$task = Get-ScheduledTask -TaskName `$TaskName -ErrorAction SilentlyContinue
    if (`$task) {
        Unregister-ScheduledTask -TaskName `$TaskName -Confirm:`$false -ErrorAction SilentlyContinue
        Write-Log "Scheduled task removed."
    }
    exit 0
}

# Check file server connectivity
Write-Log "Checking connectivity to `$RequiredFileServer..."
`$pingResult = Test-Connection -ComputerName `$RequiredFileServer -Count 2 -Quiet -ErrorAction SilentlyContinue
if (-not `$pingResult) {
    Write-Log "WARNING: `$RequiredFileServer is not reachable. Task will retry on next boot."
    exit 1
}
Write-Log "Connectivity check passed - `$RequiredFileServer is reachable"

# Run the batch file
Write-Log "Running CCH Rollout batch file..."
# Validate batch file path is not empty
if ([string]::IsNullOrWhiteSpace(`$BatchFilePath)) {
    Write-Log "ERROR: Batch file path is null or empty"
    exit 1
}

# Use full path to cmd.exe and ensure proper working directory
`$cmdPath = `$env:ComSpec
if (-not `$cmdPath) { `$cmdPath = "C:\Windows\System32\cmd.exe" }
Write-Log "Using cmd.exe: `$cmdPath"
Write-Log "Batch file: `$BatchFilePath"
Write-Log "Working directory: C:\CCHAPPS"

# Construct command line arguments - ensure proper quoting
`$batchFileQuoted = "`"`$BatchFilePath`""
`$arguments = @("/c", `$batchFileQuoted)

try {
    `$process = Start-Process -FilePath `$cmdPath -ArgumentList `$arguments -WorkingDirectory "C:\CCHAPPS" -Wait -NoNewWindow -PassThru -ErrorAction Stop
    Write-Log "Batch file process completed. Exit code: `$(`$process.ExitCode)"
} catch {
    Write-Log "ERROR: Failed to start batch file process: `$_"
    exit 1
}

if (`$process.ExitCode -eq 0) {
    # Success - create flag file and delete scheduled task
    Write-Log "SUCCESS: CCH Rollout completed successfully. Creating completion flag..."
    New-Item -Path `$CompletionFlagFile -ItemType File -Force | Out-Null
    Set-ItemProperty -Path `$CompletionFlagFile -Name LastWriteTime -Value (Get-Date) -ErrorAction SilentlyContinue
    
    Write-Log "Removing scheduled task (rollout completed)..."
    `$task = Get-ScheduledTask -TaskName `$TaskName -ErrorAction SilentlyContinue
    if (`$task) {
        Unregister-ScheduledTask -TaskName `$TaskName -Confirm:`$false -ErrorAction SilentlyContinue
        Write-Log "Scheduled task removed. Rollout will not run again."
    }
    exit 0
}
else {
    Write-Log "WARNING: CCH Rollout failed with exit code: `$(`$process.ExitCode)"
    Write-Log "Task will retry on next boot."
    exit `$process.ExitCode
}
"@
        }
        
        # Save wrapper script to C:\CCHAPPS (permanent location)
        $WrapperScriptPath = "C:\CCHAPPS\CCH-Rollout-Wrapper.ps1"
        $LogFilePath = "C:\CCHAPPS\CCH-Rollout-Wrapper.log"
        # Ensure CCHAPPS directory exists
        if (-not (Test-Path "C:\CCHAPPS")) {
            New-Item -Path "C:\CCHAPPS" -ItemType Directory -Force | Out-Null
        }
        $WrapperScript | Out-File -FilePath $WrapperScriptPath -Encoding UTF8 -Force
        
        # Create the action (run PowerShell wrapper script)
        # Use -File with full path - most reliable method for scheduled tasks
        # Output is logged within the wrapper script itself
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$WrapperScriptPath`"" `
            -WorkingDirectory "C:\CCHAPPS"
        
        # Create the trigger (on system startup, with delay)
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        $Trigger.Delay = "PT5M"  # Delay 5 minutes after boot to ensure network is ready
        
        # Create the principal (run as SYSTEM)
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        # Create the settings
        # RunOnlyIfNetworkAvailable ensures task only runs when network is available
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
        
        # Register the scheduled task
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
            -Principal $Principal -Settings $Settings -Description $TaskDescription -Force | Out-Null
        
        Write-Host "Scheduled task created successfully: $TaskName" -ForegroundColor Green
        Write-Host "The CCH rollout script will run automatically on next boot (5 minutes after startup)."
        Write-Host "Task will only run when network is available and can reach $RequiredFileServer."
        Write-Host "Log file location: $LogFilePath" -ForegroundColor Cyan
        Write-Host "Check the log file if the task does not run as expected." -ForegroundColor Cyan
        if ($RunOnEveryBoot) {
            Write-Host "IMPORTANT: The task will run on EVERY boot for continuous validation and sync with $RequiredFileServer." -ForegroundColor Cyan
            Write-Host "This ensures all hosts stay in sync and pick up updates automatically." -ForegroundColor Cyan
        }
        else {
            Write-Host "IMPORTANT: The task will run ONCE, then automatically delete itself after successful completion." -ForegroundColor Cyan
        }
        return $true
    }
    catch {
        Write-Warning "Failed to create scheduled task: $_"
        return $false
    }
}

# Verify the batch file exists
# IMPORTANT: This script must run AFTER upload-cch-apps.ps1 in the CIT script order
# The batch file is extracted by upload-cch-apps.ps1 from the CCHAPPS.zip file
Write-Host "Checking for CCH Roll-Out Update Script..."
if (!(Test-Path -Path $BatchFilePath)) {
    Write-Error "Batch file not found at: $BatchFilePath"
    Write-Error "Ensure the upload-cch-apps.ps1 script has run successfully first."
    Write-Error "Expected location: C:\CCHAPPS\CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat"
    Write-Error ""
    Write-Error "CIT Script Order Required:"
    Write-Error "  1. upload-cch-apps.ps1 (downloads and extracts CCHAPPS folder)"
    Write-Error "  2. run-cch-rollout-script.ps1 (this script)"
    exit 1
}

Write-Host "Batch file found at: $BatchFilePath"
Write-Host ""

# Get batch file info
$BatchFileInfo = Get-Item -Path $BatchFilePath
Write-Host "File size: $($BatchFileInfo.Length) bytes"
Write-Host "Last modified: $($BatchFileInfo.LastWriteTime)"
Write-Host ""

# Check network connectivity
$hasNetwork = Test-NetworkConnectivity

# Handle network availability
if (-not $hasNetwork) {
    Write-Host ""
    Write-Warning "File server connectivity is not available - $RequiredFileServer is not reachable."
    Write-Warning "The batch script requires access to \\$RequiredFileServer\ shares and will fail without it."
    
    if ($SkipIfNoNetwork) {
        Write-Host "Skipping CCH rollout script execution (SkipIfNoNetwork = true)." -ForegroundColor Yellow
        Write-Host "The script will not run during CIT build due to file server unavailability."
        Write-Host "This is expected during CIT build as the device is not on the internal network."
        
        if ($CreateScheduledTaskIfNoNetwork) {
            $taskCreated = New-ScheduledTaskForRollout
            if ($taskCreated) {
                Write-Host ""
                Write-Host "The rollout script will run automatically when the device boots and has access to $RequiredFileServer." -ForegroundColor Green
                Write-Host "Ensure the device is on the network/VPN that can reach $RequiredFileServer before first boot."
                exit 0
            }
        }
        
        Write-Host ""
        Write-Host "IMPORTANT: You will need to manually run the CCH rollout script when the device is on the network." -ForegroundColor Yellow
        Write-Host "Batch file location: $BatchFilePath"
        Write-Host "The device must have network access to: $RequiredFileServer"
        exit 0
    }
    else {
        Write-Warning "Continuing with execution despite file server unavailability (SkipIfNoNetwork = false)."
        Write-Warning "The CCH rollout script WILL FAIL as it cannot access \\$RequiredFileServer\ shares."
        Write-Warning "Consider setting SkipIfNoNetwork = `$true for CIT builds."
        Write-Host ""
    }
}

# Run the batch file
Write-Host "Executing CCH Central RDS Roll-Out Update Script..."
Write-Host "This may take several minutes. Please wait..."
Write-Host ""

try {
    # Execute the batch file and wait for completion
    # Use Start-Process with -Wait to ensure the script waits for the batch file to complete
    # -NoNewWindow keeps output visible, -PassThru allows us to check exit code
    $process = Start-Process -FilePath $BatchFilePath -WorkingDirectory "C:\CCHAPPS" -Wait -NoNewWindow -PassThru
    
    # Check exit code
    if ($process.ExitCode -eq 0) {
        Write-Host ""
        Write-Host "CCH Central RDS Roll-Out Update Script completed successfully." -ForegroundColor Green
        Write-Host "Exit code: $($process.ExitCode)"
        
        # If we're here and network wasn't available, suggest creating a scheduled task for verification
        if (-not $hasNetwork -and $CreateScheduledTaskIfNoNetwork) {
            Write-Host ""
            Write-Host "Note: Script completed but network was unavailable during execution." -ForegroundColor Yellow
            Write-Host "Consider verifying the rollout was successful when network is available."
        }
        
        exit 0
    }
    else {
        Write-Warning "Batch file completed with exit code: $($process.ExitCode)"
        Write-Warning "This may indicate an error, but some batch files return non-zero codes even on success."
        Write-Warning "Please review the batch file output above for any errors."
        
        # If network wasn't available and execution failed, offer to create scheduled task
        if (-not $hasNetwork -and $CreateScheduledTaskIfNoNetwork) {
            Write-Host ""
            Write-Host "Network was unavailable during execution. Creating scheduled task to retry on next boot..."
            $taskCreated = New-ScheduledTaskForRollout
            if ($taskCreated) {
                Write-Host "Scheduled task created. The script will retry automatically on next boot." -ForegroundColor Green
            }
        }
        
        # Exit with the batch file's exit code
        exit $process.ExitCode
    }
}
catch {
    Write-Error "Failed to execute batch file: $_"
    Write-Error "Error details: $($_.Exception.Message)"
    
    # If network wasn't available and execution failed, offer to create scheduled task
    if (-not $hasNetwork -and $CreateScheduledTaskIfNoNetwork) {
        Write-Host ""
        Write-Host "Network was unavailable during execution. Creating scheduled task to retry on next boot..."
        $taskCreated = New-ScheduledTaskForRollout
        if ($taskCreated) {
            Write-Host "Scheduled task created. The script will retry automatically on next boot." -ForegroundColor Green
        }
    }
    
    exit 1
}

### End Script ###

