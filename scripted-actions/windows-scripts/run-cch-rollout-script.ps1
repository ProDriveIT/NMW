#description: Runs the CCH Central RDS Roll-Out Update Script batch file
#tags: Nerdio, CCH Apps, Batch execution

<#
.SYNOPSIS
    Runs the CCH Central RDS Roll-Out Update Script batch file.

.DESCRIPTION
    This script runs the CCH Central RDS Roll-Out Update Script batch file located in C:\CCHAPPS\.
    This script should be run AFTER the upload-cch-apps.ps1 script has completed successfully.

.PARAMETER CreateScheduledTask
    If specified, creates a scheduled task to run this script on system startup.

.EXAMPLE
    .\run-cch-rollout-script.ps1
    
.EXAMPLE
    .\run-cch-rollout-script.ps1 -CreateScheduledTask
    
.NOTES
    Requires: Administrator privileges and network access to \\CAAZURAPP01
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$CreateScheduledTask = $false
)

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

$BatchFilePath = "C:\CCHAPPS\CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat"

if (-not (Test-Path $BatchFilePath)) {
    Write-Error "Batch file not found: $BatchFilePath"
    exit 1
}

Write-Host "Running CCH Rollout script..." -ForegroundColor Cyan

# Run batch file - echo. pipes Enter to handle pause
$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "cd /d C:\CCHAPPS && echo. | call `"$BatchFilePath`"" -WorkingDirectory "C:\CCHAPPS" -Wait -NoNewWindow -PassThru

if ($process.ExitCode -ne 0) {
    Write-Warning "Batch file exited with code: $($process.ExitCode)"
    exit $process.ExitCode
}

Write-Host "CCH Rollout completed successfully!" -ForegroundColor Green

# Create scheduled task if requested
if ($CreateScheduledTask) {
    $TaskName = "CCH-Rollout-Script"
    $ScriptPath = "C:\CCHAPPS\run-cch-rollout-script.ps1"
    
    # Save script locally
    if ($MyInvocation.MyCommand.Path -and (Test-Path $MyInvocation.MyCommand.Path)) {
        Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $ScriptPath -Force -ErrorAction SilentlyContinue
    }
    else {
        $ScriptUrl = "https://raw.githubusercontent.com/ProDriveIT/NMW/main/scripted-actions/windows-scripts/run-cch-rollout-script.ps1"
        Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptPath -UseBasicParsing -ErrorAction SilentlyContinue
    }
    
    # Remove existing task
    Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    
    # Create task
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`"" -WorkingDirectory "C:\CCHAPPS"
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Trigger.Delay = "PT5M"
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Runs CCH Rollout on startup" -Force | Out-Null
    
    Write-Host "Scheduled task created: $TaskName" -ForegroundColor Green
}
