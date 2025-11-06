#description: Downloads and extracts CCH Apps folder to C:\ drive during image build
#tags: Nerdio, File deployment, CCH Apps

<#
Notes:
This script downloads the CCHAPPS.zip file from Azure Blob Storage and extracts it to C:\ drive.
This is a wrapper script with hardcoded values for the CCH Apps deployment.

If the ZIP file contains a root CCHAPPS folder (which it should if you zipped the CCHAPPS folder),
extracting to C:\ will create C:\CCHAPPS with all files inside it.
#>

# CCH Apps configuration
$BlobStorageUrl = "https://stavdcitscripts6009.blob.core.windows.net/cch-apps/CCHAPPS.zip"
$SASToken = "sp=r&st=2025-11-06T08:54:30Z&se=2028-11-06T17:09:30Z&spr=https&sv=2024-11-04&sr=b&sig=wsfyObMgWJtOkh61PDH0BERi%2Fx27%2FICMsJ%2FM%2BSYDA2c%3D"
# Extract to C:\ root - if ZIP contains CCHAPPS folder, it will create C:\CCHAPPS correctly
$DestinationPath = "C:\"
$ZipFileName = "CCHAPPS.zip"

# Download and execute the main upload script
$ScriptUrl = "https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/upload-folder-to-c-drive.ps1"
$ScriptPath = "$env:TEMP\upload-folder-script.ps1"

try {
    Write-Host "Downloading upload script..."
    Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptPath -UseBasicParsing -ErrorAction Stop
    
    Write-Host "Executing upload script for CCH Apps..."
    & $ScriptPath -BlobStorageUrl $BlobStorageUrl -SASToken $SASToken -DestinationPath $DestinationPath -ZipFileName $ZipFileName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "CCH Apps upload completed successfully."
    }
    else {
        Write-Error "CCH Apps upload failed with exit code: $LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-Error "Failed to download or execute upload script: $_"
    exit 1
}
finally {
    # Clean up
    if (Test-Path $ScriptPath) {
        Remove-Item -Path $ScriptPath -Force -ErrorAction SilentlyContinue
    }
}

### End Script ###

