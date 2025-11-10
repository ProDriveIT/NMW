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

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
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

# Create task to run batch file directly (echo. pipes Enter to handle pause)
try {
    # Use cmd.exe to run batch file with echo. to handle pause commands
    $Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c", "cd /d C:\CCHAPPS && echo. | call `"$BatchFilePath`"" -WorkingDirectory "C:\CCHAPPS"
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Trigger.Delay = "PT5M"
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Runs CCH Rollout batch file on startup (after domain join)" -Force | Out-Null
    
    Write-Host "  Scheduled task created: $TaskName" -ForegroundColor Green
    Write-Host "  Task will run 5 minutes after system startup" -ForegroundColor Gray
    Write-Host "  Task will only run when network is available" -ForegroundColor Gray
}
catch {
    Write-Warning "Failed to create scheduled task: $_"
    exit 1
}

# Always exit with success (0) so CIT build doesn't fail
Write-Host ""
Write-Host "Script completed successfully!" -ForegroundColor Green
Write-Host "Note: Batch file will run automatically via scheduled task after domain join." -ForegroundColor Yellow
exit 0
