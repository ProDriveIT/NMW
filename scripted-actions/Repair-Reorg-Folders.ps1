param(
    [string]$Root = "C:\Dev\NMW"
)

$ErrorActionPreference = 'Stop'

$extras = Join-Path $Root "scripted-actions\extras"
$ws = Join-Path $Root "scripted-actions\windows-scripts"
$cis = Join-Path $Root "scripted-actions\custom-image-template-scripts"

$extrasWs = Join-Path $extras "windows-scripts"
$extrasAr = Join-Path $extras "azure-runbooks"
$extrasCis = Join-Path $extras "custom-image-template-scripts"

$null = New-Item -ItemType Directory -Path $extrasWs -Force
$null = New-Item -ItemType Directory -Path $extrasAr -Force
$null = New-Item -ItemType Directory -Path $extrasCis -Force

# 1) Flatten mistakenly nested extras\scripted-actions\...
$nested = Join-Path $extras "scripted-actions"
if (Test-Path $nested) {
    $nestedWs = Join-Path $nested "windows-scripts"
    if (Test-Path $nestedWs) { Get-ChildItem -LiteralPath $nestedWs -File | Move-Item -Destination $extrasWs -Force }
    $nestedAr = Join-Path $nested "azure-runbooks"
    if (Test-Path $nestedAr) { Get-ChildItem -LiteralPath $nestedAr -File | Move-Item -Destination $extrasAr -Force }
    Remove-Item -LiteralPath $nested -Recurse -Force
}

# 2) Move duplicate Screen Capture Protection from CIT to extras
$cisSCP = Join-Path $cis "Enable Screen capture protection.ps1"
if (Test-Path $cisSCP) {
    Move-Item -LiteralPath $cisSCP -Destination (Join-Path $extrasCis (Split-Path $cisSCP -Leaf)) -Force
}

# 3) Move legacy 'Install FSLogix.ps1' (duplicate) to extras
$legacyFslogix = Join-Path $ws "Install FSLogix.ps1"
if (Test-Path $legacyFslogix) {
    Move-Item -LiteralPath $legacyFslogix -Destination (Join-Path $extrasWs (Split-Path $legacyFslogix -Leaf)) -Force
}

Write-Host "Repair complete. Extras normalized under: $extras"


