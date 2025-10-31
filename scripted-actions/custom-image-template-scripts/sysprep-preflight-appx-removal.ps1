#description: Preflight checks for Sysprep - Disables BitLocker and removes problematic AppX packages
#execution mode: Individual
#tags: Microsoft, Sysprep, Custom Image Template Scripts, AppX, BitLocker
<#
.SYNOPSIS
Preflight checks for Sysprep - Disables BitLocker and removes problematic AppX packages.

.DESCRIPTION
This script performs preflight checks before running Sysprep:
1. Disables BitLocker on all volumes (if enabled)
2. Parses Sysprep's setupact.log to identify AppX packages that were installed
   for a user but not provisioned system-wide and removes them

This is a preflight check script that should be run before running Sysprep to prevent failures.
#>

# Configure powershell logging
$SaveVerbosePreference = $VerbosePreference
$VerbosePreference = 'continue'
$VMTime = Get-Date
$LogTime = $VMTime.ToUniversalTime()
mkdir "$env:windir\Temp\NMWLogs\ScriptedActions\sysprep_preflight" -Force
Start-Transcript -Path "$env:windir\Temp\NMWLogs\ScriptedActions\sysprep_preflight\ps_log.txt" -Append -IncludeInvocationHeader
Write-Host "################# New Script Run #################"
Write-host "Current time (UTC-0): $LogTime"

# ============================================================================
# Step 1: Disable BitLocker
# ============================================================================
Write-Host ""
Write-Host "==================== BitLocker Check ====================" -ForegroundColor Cyan
Write-Host "Checking and disabling BitLocker on all volumes..." -ForegroundColor Cyan

try {
    # Check if BitLocker module is available
    if (Get-Command -Name "Get-BitLockerVolume" -ErrorAction SilentlyContinue) {
        $bitlockerVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
        
        if ($bitlockerVolumes) {
            $encryptedVolumes = $bitlockerVolumes | Where-Object { $_.VolumeStatus -eq "FullyEncrypted" -or $_.VolumeStatus -eq "EncryptionInProgress" }
            
            if ($encryptedVolumes) {
                Write-Host "Found $($encryptedVolumes.Count) encrypted volume(s):" -ForegroundColor Yellow
                
                foreach ($volume in $encryptedVolumes) {
                    Write-Host "  - $($volume.MountPoint) - Status: $($volume.VolumeStatus)" -ForegroundColor Yellow
                    
                    try {
                        Write-Host "    Starting BitLocker decryption..." -ForegroundColor Cyan
                        Disable-BitLocker -MountPoint $volume.MountPoint -ErrorAction Stop
                        
                        # Wait for decryption to complete
                        Write-Host "    Waiting for decryption to complete (this may take a while)..." -ForegroundColor Cyan
                        $maxWaitTime = 3600  # Maximum wait time in seconds (1 hour)
                        $startTime = Get-Date
                        $checkInterval = 10  # Check every 10 seconds
                        $lastPercentage = -1
                        
                        do {
                            Start-Sleep -Seconds $checkInterval
                            $currentVolume = Get-BitLockerVolume -MountPoint $volume.MountPoint -ErrorAction SilentlyContinue
                            
                            if ($currentVolume) {
                                $currentStatus = $currentVolume.VolumeStatus
                                $currentPercentage = $currentVolume.EncryptionPercentage
                                
                                # Show progress if percentage changed
                                # EncryptionPercentage shows how much is still encrypted
                                if ($currentPercentage -ne $lastPercentage) {
                                    $decryptedPercent = 100 - $currentPercentage
                                    $remainingPercent = $currentPercentage
                                    
                                    if ($currentStatus -eq "DecryptionInProgress") {
                                        Write-Host "    Progress: $decryptedPercent`% decrypted, $remainingPercent`% remaining... (Status: $currentStatus)" -ForegroundColor Cyan
                                        $lastPercentage = $currentPercentage
                                    } elseif ($currentStatus -ne "DecryptionInProgress" -and $currentPercentage -gt 0) {
                                        Write-Host "    Status changed to: $currentStatus, but still $remainingPercent`% encrypted..." -ForegroundColor Yellow
                                        Write-Host "    Continuing to wait for decryption to complete..." -ForegroundColor Cyan
                                        $lastPercentage = $currentPercentage
                                    }
                                }
                                
                                # Check if decryption is complete - must verify BOTH status AND percentage
                                # Status can sometimes report "FullyDecrypted" before percentage reaches 0
                                if ($currentPercentage -eq 0 -or $currentPercentage -lt 0.1) {
                                    # Double-check the status to ensure it's truly decrypted
                                    if ($currentStatus -eq "FullyDecrypted" -or $currentStatus -eq "DecryptionComplete" -or $currentStatus -eq "VolumeUnprotected") {
                                        Write-Host "    [OK] BitLocker decryption completed successfully (0`% encrypted)" -ForegroundColor Green
                                        break
                                    } else {
                                        # Percentage is 0 but status hasn't updated yet - wait a bit more
                                        Write-Host "    EncryptionPercentage is 0`%, waiting for status to update..." -ForegroundColor Cyan
                                        Start-Sleep -Seconds 5
                                        $verifyVolume = Get-BitLockerVolume -MountPoint $volume.MountPoint -ErrorAction SilentlyContinue
                                        if ($verifyVolume -and ($verifyVolume.EncryptionPercentage -eq 0 -or $verifyVolume.EncryptionPercentage -lt 0.1)) {
                                            Write-Host "    [OK] BitLocker decryption completed successfully (verified 0`% encrypted)" -ForegroundColor Green
                                            break
                                        }
                                    }
                                } elseif ($currentStatus -eq "FullyDecrypted" -or $currentStatus -eq "DecryptionComplete") {
                                    # Status says decrypted but percentage isn't 0 yet - keep waiting
                                    Write-Host "    Status reports '$currentStatus' but $remainingPercent`% still encrypted. Continuing to wait..." -ForegroundColor Yellow
                                }
                                
                                # Check for errors
                                if ($currentStatus -eq "EncryptionInProgress" -and $currentPercentage -gt 50) {
                                    Write-Host "    [WARN] Warning: Volume status shows encryption may have restarted: $currentStatus" -ForegroundColor Yellow
                                }
                            }
                            
                            # Check for timeout
                            $elapsed = (Get-Date) - $startTime
                            if ($elapsed.TotalSeconds -gt $maxWaitTime) {
                                Write-Host "    [WARN] Timeout waiting for decryption to complete (waited $($maxWaitTime) seconds)" -ForegroundColor Yellow
                                Write-Host "    Decryption may still be in progress. Check status manually." -ForegroundColor Yellow
                                break
                            }
                        } while ($true)
                    }
                    catch {
                        Write-Host "    [WARN] Failed to disable BitLocker: $_" -ForegroundColor Yellow
                        Write-Host "    Attempting alternative method..." -ForegroundColor Cyan
                        
                        # Fallback to manage-bde command
                        try {
                            $result = & manage-bde.exe -off $volume.MountPoint 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "    Decryption started. Waiting for completion..." -ForegroundColor Cyan
                                
                                # Wait for decryption using manage-bde status
                                $maxWaitTime = 3600
                                $startTime = Get-Date
                                $checkInterval = 10
                                $lastEncPercent = -1
                                
                                do {
                                    Start-Sleep -Seconds $checkInterval
                                    $status = & manage-bde.exe -status $volume.MountPoint 2>&1
                                    
                                    # Extract percentage - this is the key metric
                                    $encPercent = 0
                                    if ($status -match "Percentage Encrypted:\s*(\d+(?:\.\d+)?)%") {
                                        $encPercent = [double]$matches[1]
                                    }
                                    
                                    # Show progress if percentage changed
                                    if ($encPercent -ne $lastEncPercent) {
                                        $decPercent = 100 - $encPercent
                                        if ($status -match "Conversion Status:\s*Decryption in progress") {
                                            Write-Host "    Progress: $decPercent`% decrypted, $encPercent`% remaining..." -ForegroundColor Cyan
                                        } else {
                                            Write-Host "    Progress: $decPercent`% decrypted, $encPercent`% remaining... (Status may show otherwise)" -ForegroundColor Yellow
                                        }
                                        $lastEncPercent = $encPercent
                                    }
                                    
                                    # Completion check - verify BOTH status AND percentage
                                    if ($encPercent -eq 0 -or $encPercent -lt 0.1) {
                                        # Percentage is 0, verify status
                                        if ($status -match "Conversion Status:\s*Fully Decrypted" -or $status -match "Conversion Status:\s*None") {
                                            Write-Host "    ✓ BitLocker decryption completed successfully (0`% encrypted verified)" -ForegroundColor Green
                                            break
                                        } else {
                                            # Percentage is 0 but status hasn't updated - wait a bit more
                                            Write-Host "    Percentage is 0`%, waiting for status to update..." -ForegroundColor Cyan
                                            Start-Sleep -Seconds 5
                                            $verifyStatus = & manage-bde.exe -status $volume.MountPoint 2>&1
                                            if ($verifyStatus -match "Percentage Encrypted:\s*0%") {
                                                Write-Host "    [OK] BitLocker decryption completed successfully (verified 0`% encrypted)" -ForegroundColor Green
                                                break
                                            }
                                        }
                                    } elseif ($status -match "Conversion Status:\s*Fully Decrypted") {
                                        # Status says decrypted but percentage isn't 0 - keep waiting
                                        Write-Host "    Status reports 'Fully Decrypted' but $encPercent`% still encrypted. Continuing to wait..." -ForegroundColor Yellow
                                    }
                                    
                                    $elapsed = (Get-Date) - $startTime
                                    if ($elapsed.TotalSeconds -gt $maxWaitTime) {
                                        Write-Host "    ⚠ Timeout waiting for decryption (waited $($maxWaitTime) seconds)" -ForegroundColor Yellow
                                        Write-Host "    Current status: $encPercent`% still encrypted. Decryption may still be in progress." -ForegroundColor Yellow
                                        break
                                    }
                                } while ($true)
                            } else {
                                Write-Host "    [ERROR] Could not disable BitLocker: $result" -ForegroundColor Red
                            }
                        }
                        catch {
                            Write-Host "    [ERROR] Alternative method also failed: $_" -ForegroundColor Red
                        }
                    }
                }
            } else {
                Write-Host "[OK] No encrypted volumes found. BitLocker is already disabled or not configured." -ForegroundColor Green
            }
        } else {
            Write-Host "[OK] BitLocker is not available or no volumes detected." -ForegroundColor Green
        }
    } else {
        # Try using manage-bde command line tool
        Write-Host "BitLocker PowerShell module not available. Trying manage-bde..." -ForegroundColor Cyan
        $volumes = (Get-WmiObject -Class Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 }).DeviceID
        
        $foundEncrypted = $false
        foreach ($vol in $volumes) {
            $status = & manage-bde.exe -status $vol 2>&1
            if ($status -match "Encryption Method|Conversion Status" -and $status -notmatch "Fully Decrypted") {
                $foundEncrypted = $true
                Write-Host "  - Found encrypted volume: $vol" -ForegroundColor Yellow
                Write-Host "    Starting BitLocker decryption..." -ForegroundColor Cyan
                $result = & manage-bde.exe -off $vol 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    Decryption started. Waiting for completion..." -ForegroundColor Cyan
                    
                    # Wait for decryption to complete
                    $maxWaitTime = 3600  # Maximum wait time in seconds (1 hour)
                    $startTime = Get-Date
                    $checkInterval = 10  # Check every 10 seconds
                    $lastEncPercent = -1
                    
                    do {
                        Start-Sleep -Seconds $checkInterval
                        $status = & manage-bde.exe -status $vol 2>&1
                        
                        # Extract percentage - this is the key metric
                        $encPercent = 0
                        if ($status -match "Percentage Encrypted:\s*(\d+(?:\.\d+)?)%") {
                            $encPercent = [double]$matches[1]
                        }
                        
                        # Show progress if percentage changed
                        if ($encPercent -ne $lastEncPercent) {
                            $decPercent = 100 - $encPercent
                            if ($status -match "Conversion Status:\s*Decryption in progress") {
                                Write-Host "    Progress: $decPercent`% decrypted, $encPercent`% remaining..." -ForegroundColor Cyan
                            } else {
                                Write-Host "    Progress: $decPercent`% decrypted, $encPercent`% remaining... (Status may show otherwise)" -ForegroundColor Yellow
                            }
                            $lastEncPercent = $encPercent
                        }
                        
                        # Completion check - verify BOTH status AND percentage
                        if ($encPercent -eq 0 -or $encPercent -lt 0.1) {
                            # Percentage is 0, verify status
                            if ($status -match "Conversion Status:\s*Fully Decrypted" -or $status -match "Conversion Status:\s*None") {
                                Write-Host "    ✓ BitLocker decryption completed successfully (0`% encrypted verified)" -ForegroundColor Green
                                break
                            } else {
                                # Percentage is 0 but status hasn't updated - wait a bit more
                                Write-Host "    Percentage is 0`%, waiting for status to update..." -ForegroundColor Cyan
                                Start-Sleep -Seconds 5
                                $verifyStatus = & manage-bde.exe -status $vol 2>&1
                                if ($verifyStatus -match "Percentage Encrypted:\s*0%") {
                                    Write-Host "    ✓ BitLocker decryption completed successfully (verified 0`% encrypted)" -ForegroundColor Green
                                    break
                                }
                            }
                        } elseif ($status -match "Conversion Status:\s*Fully Decrypted") {
                            # Status says decrypted but percentage isn't 0 - keep waiting
                            Write-Host "    Status reports 'Fully Decrypted' but $encPercent`% still encrypted. Continuing to wait..." -ForegroundColor Yellow
                        }
                        
                        # Check for timeout
                        $elapsed = (Get-Date) - $startTime
                        if ($elapsed.TotalSeconds -gt $maxWaitTime) {
                            Write-Host "    ⚠ Timeout waiting for decryption (waited $($maxWaitTime) seconds)" -ForegroundColor Yellow
                            Write-Host "    Current status: $encPercent`% still encrypted. Decryption may still be in progress." -ForegroundColor Yellow
                            break
                        }
                    } while ($true)
                } else {
                    Write-Host "    [WARN] Could not disable BitLocker: $result" -ForegroundColor Yellow
                }
            }
        }
        
        if (-not $foundEncrypted) {
            Write-Host "✓ No encrypted volumes found. BitLocker is already disabled or not configured." -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "[WARN] Error checking BitLocker status: $_" -ForegroundColor Yellow
    Write-Host "Continuing with other preflight checks..." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "==================== AppX Package Check ====================" -ForegroundColor Cyan

# Path to Sysprep's setupact.log
$logPath = "C:\Windows\System32\Sysprep\Panther\setupact.log"

# Check if log file exists
if (-not (Test-Path -Path $logPath)) {
    Write-Warning "Sysprep log file not found at: $logPath"
    Write-Host "This script should be run after an initial Sysprep attempt that failed."
    Write-Host "No AppX packages to remove."
    Stop-Transcript
    $VerbosePreference = $SaveVerbosePreference
    exit 0
}

# Pattern to detect problematic AppX packages
$pattern = "SYSPRP Package (.*?) was installed for a user"

# Extract and shorten AppX package names
$detectedApps = @()
$logMatches = Select-String -Path $logPath -Pattern $pattern

foreach ($logMatch in $logMatches) {
    if ($logMatch.Line -match $pattern) {
        $fullName = $matches[1]
        if ($fullName) {
            $shortName = $fullName.Split('_')[0]
            $detectedApps += $shortName
        }
    }
}

# Remove duplicates
$badApps = $detectedApps | Sort-Object -Unique

# Display detected AppX packages
Write-Host ""
Write-Host "Detected problematic AppX packages:" -ForegroundColor Yellow
if ($badApps.Count -eq 0) {
    Write-Host " - No problematic AppX packages detected." -ForegroundColor Green
} else {
    foreach ($app in $badApps) {
        Write-Host " - $app" -ForegroundColor Yellow
    }
}

# Remove AppX packages for all users and from the system
if ($badApps.Count -gt 0) {
    Write-Host ""
    Write-Host "Removing problematic AppX packages..." -ForegroundColor Cyan
    
    foreach ($app in $badApps) {
        Write-Host ""
        Write-Host "Removing: $app" -ForegroundColor Cyan
        
        try {
            # Remove from all users
            Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Write-Host "  [OK] Removed AppX package for all users" -ForegroundColor Green
        }
        catch {
            Write-Host "  [WARN] Could not remove AppX package for all users: $_" -ForegroundColor Yellow
        }
        
        try {
            # Remove provisioned package
            Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $app -or $_.PackageName -like "$app*"} | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            Write-Host "  [OK] Removed provisioned AppX package" -ForegroundColor Green
        }
        catch {
            Write-Host "  [WARN] Could not remove provisioned AppX package: $_" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "AppX cleanup completed." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "No problematic AppX packages found." -ForegroundColor Green
}

# Final summary
Write-Host ""
Write-Host "==================== Preflight Check Summary ====================" -ForegroundColor Cyan
Write-Host "[OK] BitLocker check completed" -ForegroundColor Green
Write-Host "[OK] AppX package check completed" -ForegroundColor Green
Write-Host ""
Write-Host "Preflight checks completed. You can now re-run Sysprep." -ForegroundColor Green

# End Logging
Stop-Transcript
$VerbosePreference = $SaveVerbosePreference

