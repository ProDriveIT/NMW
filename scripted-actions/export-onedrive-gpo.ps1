#description: Exports OneDrive GPO to backup file for import
#tags: GPO, Export, Backup, OneDrive

<#
.SYNOPSIS
    Exports a GPO to a backup file that can be imported on another domain/DC.

.DESCRIPTION
    Exports the "AVD - OneDrive & SharePoint Settings" GPO to a backup file.
    The backup can be imported using Import-GPO cmdlet or Group Policy Management Console.

.PARAMETER GPOName
    Name of the GPO to export. Default: "AVD - OneDrive & SharePoint Settings"

.PARAMETER BackupPath
    Path to save the backup. Default: Current directory\GPO-Backup

.NOTES
    - Requires Group Policy Management Console (GPMC) cmdlets
    - Must be run on a Domain Controller or machine with RSAT installed
    - Requires Domain Admin or GPO backup permissions

.EXAMPLE
    .\export-onedrive-gpo.ps1
    
.EXAMPLE
    .\export-onedrive-gpo.ps1 -BackupPath "C:\GPO-Backups"
#>

[CmdletBinding()]
param(
    [string]$GPOName = "AVD - OneDrive & SharePoint Settings",
    [string]$BackupPath = (Join-Path $PSScriptRoot "GPO-Backup")
)

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# Check if Group Policy module is available
try {
    Import-Module GroupPolicy -ErrorAction Stop
} catch {
    Write-Error "Group Policy module not found. Please install RSAT (Remote Server Administration Tools) or run this on a Domain Controller."
    exit 1
}

# Check if GPO exists
$gpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if (-not $gpo) {
    Write-Error "GPO '$GPOName' not found. Please create it first using create-onedrive-gpo.ps1"
    exit 1
}

# Create backup directory
if (-not (Test-Path $BackupPath)) {
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    Write-Host "Created backup directory: $BackupPath" -ForegroundColor Gray
}

Write-Host "Exporting GPO: $GPOName" -ForegroundColor Cyan
Write-Host "Backup Path: $BackupPath" -ForegroundColor Gray
Write-Host "=" * 60

try {
    # Export the GPO
    Backup-GPO -Name $GPOName -Path $BackupPath -ErrorAction Stop
    Write-Host "`nGPO exported successfully!" -ForegroundColor Green
    
    # Get backup details
    $backupInfo = Get-GPOBackup -Path $BackupPath | Where-Object { $_.DisplayName -eq $GPOName } | Sort-Object BackupTime -Descending | Select-Object -First 1
    
    Write-Host "`nBackup Details:" -ForegroundColor Cyan
    Write-Host "  GPO Name: $($backupInfo.DisplayName)"
    Write-Host "  Backup Time: $($backupInfo.BackupTime)"
    Write-Host "  Backup ID: $($backupInfo.Id)"
    Write-Host "  Backup Path: $BackupPath"
    
    Write-Host "`nTo import this GPO on another DC:" -ForegroundColor Yellow
    Write-Host "  Import-GPO -BackupId $($backupInfo.Id) -Path '$BackupPath' -TargetName '$GPOName' -CreateIfNeeded" -ForegroundColor Gray
    
} catch {
    Write-Error "Failed to export GPO: $_"
    exit 1
}

### End Script ###

