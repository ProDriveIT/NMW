#description: User logoff script to gracefully close OneDrive before FSLogix profile unload
#tags: OneDrive, FSLogix, User Logoff, GPO

<#
.SYNOPSIS
    User logoff script to ensure OneDrive closes gracefully before FSLogix profile unload.

.DESCRIPTION
    This script runs at user logoff (before FSLogix profile unload) and:
    1. Stops OneDrive sync to prevent file handle locks
    2. Closes OneDrive process gracefully
    3. Waits briefly for file handles to release
    4. Ensures FSLogix can unmount the profile without hanging
    
    This should be deployed as a GPO User Logoff Script (not Startup Script).

.NOTES
    - Runs in user context (not admin)
    - Deploy via GPO: User Configuration > Policies > Windows Settings > Scripts > Logoff
    - This runs BEFORE FSLogix profile unload, preventing logout hangs
#>

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "Preparing OneDrive for logoff..." -ForegroundColor Cyan

# Stop OneDrive sync to release file handles
try {
    $onedriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    
    if ($onedriveProcess) {
        Write-Host "  Stopping OneDrive sync..." -ForegroundColor Yellow
        
        # Try graceful shutdown first (sends WM_CLOSE)
        $onedriveProcess.CloseMainWindow() | Out-Null
        
        # Wait up to 5 seconds for graceful shutdown
        $onedriveProcess.WaitForExit(5000)
        
        # If still running, force kill
        if (-not $onedriveProcess.HasExited) {
            Write-Host "  Force closing OneDrive..." -ForegroundColor Yellow
            Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "  OneDrive closed" -ForegroundColor Green
    } else {
        Write-Host "  OneDrive not running" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Error closing OneDrive: $_"
    # Try force kill as fallback
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
}

# Wait a moment for file handles to release
Start-Sleep -Milliseconds 500

# Check for any remaining OneDrive processes
$remainingProcesses = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
if ($remainingProcesses) {
    Write-Host "  Warning: OneDrive processes still running, forcing closure..." -ForegroundColor Yellow
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

Write-Host "OneDrive logoff preparation complete." -ForegroundColor Green

### End Script ###

