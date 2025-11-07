
# Set parameters
$StorageAccountName = "scstfslavdproduks001"
$ShareName = "avd-profiles"
$DaysOld = 90
$StorageKeySecureVar = "vgIB77llF0JT3EkGdiDku4rgIZDFzb52GHtfplztouB+HNiK9++bKaUzsF5qFzetT1nuH+Cm+Ik1+AStqgPtRA=="
$WhatIf = "false"  # Use "true" to test, "false" to actually delete

# Run the script
cd "C:\Dev\NMW\scripted-actions\azure-runbooks"

.\DeleteOldFSLogixProfiles.ps1