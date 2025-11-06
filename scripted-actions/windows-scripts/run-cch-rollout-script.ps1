#description: Runs the CCH Central RDS Roll-Out Update Script batch file
#tags: Nerdio, CCH Apps, Batch execution

<#
Notes:
This script runs the CCH Central RDS Roll-Out Update Script batch file located in C:\CCHAPPS\.
This script should be run AFTER the upload-cch-apps.ps1 script has completed successfully.

The batch file will be executed with administrative privileges and the script will wait for completion.
#>

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# Define the batch file path
$BatchFilePath = "C:\CCHAPPS\CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat"

# Verify the batch file exists
Write-Host "Checking for CCH Roll-Out Update Script..."
if (!(Test-Path -Path $BatchFilePath)) {
    Write-Error "Batch file not found at: $BatchFilePath"
    Write-Error "Ensure the upload-cch-apps.ps1 script has run successfully first."
    Write-Error "Expected location: C:\CCHAPPS\CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat"
    exit 1
}

Write-Host "Batch file found at: $BatchFilePath"
Write-Host ""

# Get batch file info
$BatchFileInfo = Get-Item -Path $BatchFilePath
Write-Host "File size: $($BatchFileInfo.Length) bytes"
Write-Host "Last modified: $($BatchFileInfo.LastWriteTime)"
Write-Host ""

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
        exit 0
    }
    else {
        Write-Warning "Batch file completed with exit code: $($process.ExitCode)"
        Write-Warning "This may indicate an error, but some batch files return non-zero codes even on success."
        Write-Warning "Please review the batch file output above for any errors."
        
        # Exit with the batch file's exit code
        exit $process.ExitCode
    }
}
catch {
    Write-Error "Failed to execute batch file: $_"
    Write-Error "Error details: $($_.Exception.Message)"
    exit 1
}

### End Script ###

