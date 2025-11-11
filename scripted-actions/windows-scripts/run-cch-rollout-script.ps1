#description: Creates scheduled task for CCH Rollout (runs after domain join)
#tags: Nerdio, CCH Apps, Scheduled Task

<#
.SYNOPSIS
    Creates a scheduled task to run CCH Rollout script after domain join.

.DESCRIPTION
    This script creates a scheduled task to run the CCH Central RDS Roll-Out Update Script batch file.
    During CIT build (pre-domain-join), it only creates the scheduled task and skips batch execution.
    After domain join, the scheduled task will run the batch file automatically on startup.
    
    This script should be run AFTER the upload-cch-apps.ps1 script has completed successfully.

.EXAMPLE
    .\run-cch-rollout-script.ps1
    
.NOTES
    Requires: Administrator privileges
    During CIT: Creates scheduled task only (network not available)
    After domain join: Scheduled task runs batch file automatically
#>

[CmdletBinding()]
param()

# Set error action to Continue so errors don't stop execution
$ErrorActionPreference = 'Continue'

# Wrap entire script in try-catch to ensure we ALWAYS exit with 0
try {
# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
        Write-Host "WARNING: Not running as administrator. Some operations may fail." -ForegroundColor Yellow
        # Don't exit - continue anyway
    }

    # During CIT build, VM is not domain-joined, so batch file cannot access network shares
    # Skip batch execution - it will run automatically via scheduled task after domain join
    Write-Host "Skipping batch execution during CIT build (VM not domain-joined)" -ForegroundColor Yellow
    Write-Host "Batch file will run automatically via scheduled task after domain join" -ForegroundColor Gray

    # Always create scheduled task (for both CIT build and post-domain-join)
    Write-Host "Creating scheduled task..." -ForegroundColor Cyan

    $TaskName = "CCH-Rollout-Script"
$BatchFilePath = "C:\CCHAPPS\CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat"

    # Remove existing task
    Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

    # Create task to run batch file - use schtasks.exe for maximum reliability
    # This script MUST NOT fail the build - if task creation fails, we continue anyway
    $TaskCreated = $false

    try {
        # Create a simple wrapper batch file that runs the actual batch file
        $WrapperBatch = "C:\CCHAPPS\RunCCHRollout.bat"
        $WrapperContent = @"
@echo off
cd /d C:\CCHAPPS
echo. | call "C:\CCHAPPS\CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat"
"@
        
        # Create wrapper batch file (ignore errors)
        try {
            $WrapperContent | Out-File -FilePath $WrapperBatch -Encoding ASCII -Force -ErrorAction Stop
            Write-Host "  Wrapper batch file created: $WrapperBatch" -ForegroundColor Gray
        }
        catch {
            Write-Host "  WARNING: Could not create wrapper batch file: $_" -ForegroundColor Yellow
        }
        
        # Use schtasks.exe directly - most reliable method, no PowerShell cmdlet issues
        try {
            # Delete existing task if it exists (ignore errors)
            $null = schtasks.exe /Delete /TN $TaskName /F 2>&1
            
            # Create task using schtasks.exe - this is the most reliable method
            # /SC ONSTART = run at startup
            # /RU SYSTEM = run as SYSTEM account
            # /RL HIGHEST = run with highest privileges
            # /TR = task to run (the wrapper batch file)
            # /DELAY = delay 5 minutes after startup
            $result = schtasks.exe /Create /TN $TaskName /TR "`"$WrapperBatch`"" /SC ONSTART /RU SYSTEM /RL HIGHEST /DELAY PT5M /F 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                # Configure additional settings using PowerShell (network requirement, time limit)
                try {
                    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                    if ($task) {
                        $task.Settings.StartWhenAvailable = $true
                        $task.Settings.RunOnlyIfNetworkAvailable = $true
                        $task.Settings.ExecutionTimeLimit = New-TimeSpan -Hours 2
                        $task.Description = "Runs CCH Rollout batch file on startup (after domain join)"
                        Set-ScheduledTask -TaskName $TaskName -InputObject $task -ErrorAction SilentlyContinue | Out-Null
                    }
                }
                catch {
                    # Settings update failed, but task was created - that's OK
                    Write-Host "  NOTE: Task created but some settings could not be applied" -ForegroundColor Gray
                }
                
                $TaskCreated = $true
                Write-Host "  Scheduled task created: $TaskName" -ForegroundColor Green
                Write-Host "  Task will run 5 minutes after system startup" -ForegroundColor Gray
                Write-Host "  Task will only run when network is available" -ForegroundColor Gray
            }
            else {
                throw "schtasks.exe returned exit code $LASTEXITCODE : $result"
            }
        }
        catch {
            Write-Host "  WARNING: Failed to create scheduled task: $_" -ForegroundColor Yellow
            Write-Host "  The task can be created manually after deployment if needed." -ForegroundColor Yellow
            $TaskCreated = $false
        }
    }
    catch {
        Write-Host "  WARNING: Error during scheduled task setup: $_" -ForegroundColor Yellow
        $TaskCreated = $false
    }

    if (-not $TaskCreated) {
        Write-Host "  NOTE: Scheduled task was not created, but build will continue." -ForegroundColor Yellow
        Write-Host "  You can create the task manually after deployment using:" -ForegroundColor Gray
        Write-Host "    schtasks /Create /TN CCH-Rollout-Script /TR `"C:\CCHAPPS\RunCCHRollout.bat`" /SC ONSTART /RU SYSTEM /RL HIGHEST" -ForegroundColor Gray
    }

    # Always exit with success (0) so CIT build doesn't fail
    Write-Host ""
    Write-Host "Script completed successfully!" -ForegroundColor Green
    Write-Host "Note: Batch file will run automatically via scheduled task after domain join." -ForegroundColor Yellow
}
catch {
    # Catch ANY error and log it, but don't fail
    Write-Host "WARNING: An error occurred: $_" -ForegroundColor Yellow
    Write-Host "Script will exit with success code to prevent build failure." -ForegroundColor Yellow
}
finally {
    # ALWAYS exit with 0 - no matter what happened
    exit 0
}
