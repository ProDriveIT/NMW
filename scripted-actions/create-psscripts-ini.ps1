# Quick script to create psscripts.ini for existing GPO

$gpoId = "8B0367A9-4D4B-416D-8F9D-4CA97922D3A5"
$domain = "CA.LOCAL"
$gpoPath = "\\$domain\SYSVOL\$domain\Policies\{$gpoId}\Machine\Scripts\Startup"
$psscriptsIni = Join-Path $gpoPath "psscripts.ini"

Write-Host "Creating psscripts.ini at: $psscriptsIni" -ForegroundColor Cyan

# Create the psscripts.ini content
$content = @"
[0]
0Scripts=configure-onedrive-gpo-settings.ps1
0Parameters=
ExecutionPolicy=Bypass
"@

# Write the file
$content | Set-Content -Path $psscriptsIni -Encoding ASCII -Force

Write-Host "`npsscripts.ini created successfully!" -ForegroundColor Green
Write-Host "`nContent:" -ForegroundColor Cyan
Get-Content $psscriptsIni | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

Write-Host "`nNext: Refresh GPO Editor (F5) and check PowerShell Scripts tab" -ForegroundColor Yellow

