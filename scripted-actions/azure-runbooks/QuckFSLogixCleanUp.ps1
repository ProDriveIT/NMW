
# Set parameters
$StorageAccountName = "scstfslavdproduks001"
$ShareName = "avd-profiles"
$DaysOld = 90
$StorageKeySecureVar = "ENTER KEY HERE"
$WhatIf = "false"  # Use "true" to test, "false" to actually delete

# Run the script
cd "C:\Dev\NMW\scripted-actions\azure-runbooks"

.\DeleteOldFSLogixProfiles.ps1