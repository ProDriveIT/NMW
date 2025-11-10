#description: Analyzes FSLogix profile to identify what's consuming disk space
#tags: Nerdio, FSLogix, Diagnostics, Storage

<#
.SYNOPSIS
    Analyzes FSLogix profile to identify large files and folders consuming disk space.

.DESCRIPTION
    This script helps diagnose why a FSLogix profile is large by:
    - Checking total profile size
    - Finding largest folders and files
    - Checking common culprits (OST files, temp files, downloads, etc.)
    - Showing breakdown by user profile folders
    - Checking FSLogix size limits and settings

.PARAMETER UserName
    Username to analyze (default: current user)

.PARAMETER ProfilePath
    Direct path to profile VHD/VHDX (optional, will auto-detect if not provided)

.PARAMETER TopFolders
    Number of top folders to show (default: 20)

.PARAMETER MinSizeMB
    Minimum file size to report in MB (default: 100)

.EXAMPLE
    .\analyze-fslogix-profile-size.ps1
    
.EXAMPLE
    .\analyze-fslogix-profile-size.ps1 -UserName "jdoe" -TopFolders 30
    
.NOTES
    Requires: Administrator privileges (for analyzing other users)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$UserName = $env:USERNAME,
    
    [Parameter(Mandatory = $false)]
    [string]$ProfilePath = "",
    
    [Parameter(Mandatory = $false)]
    [int]$TopFolders = 20,
    
    [Parameter(Mandatory = $false)]
    [int]$MinSizeMB = 100
)

$ErrorActionPreference = 'Continue'

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "FSLogix Profile Size Analysis" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Analyzing profile for: $UserName" -ForegroundColor Yellow
Write-Host ""

# Check if running as administrator (needed for other users)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($UserName -ne $env:USERNAME -and -not $isAdmin) {
    Write-Warning "Administrator privileges required to analyze other users' profiles."
    Write-Host "Switching to current user: $env:USERNAME" -ForegroundColor Yellow
    $UserName = $env:USERNAME
}

# Get user profile path
if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
    if ($UserName -eq $env:USERNAME) {
        $ProfilePath = $env:USERPROFILE
    }
    else {
        $ProfilePath = "C:\Users\$UserName"
    }
}

Write-Host "Profile Path: $ProfilePath" -ForegroundColor Gray
Write-Host ""

# Check if profile path exists
if (-not (Test-Path $ProfilePath)) {
    Write-Error "Profile path not found: $ProfilePath"
    exit 1
}

# Get total profile size
Write-Host "Calculating total profile size..." -ForegroundColor Yellow
$totalSize = (Get-ChildItem -Path $ProfilePath -Recurse -ErrorAction SilentlyContinue | 
    Measure-Object -Property Length -Sum).Sum
$totalSizeGB = [math]::Round($totalSize / 1GB, 2)
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "  Total Profile Size: $totalSizeGB GB ($totalSizeMB MB)" -ForegroundColor $(if ($totalSizeGB -gt 30) { "Red" } elseif ($totalSizeGB -gt 20) { "Yellow" } else { "Green" })
Write-Host ""

# Check FSLogix registry settings
Write-Host "FSLogix Configuration:" -ForegroundColor Cyan
$fsLogixPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
if (Test-Path $fsLogixPath) {
    $sizeInMBs = Get-ItemProperty -Path $fsLogixPath -Name "SizeInMBs" -ErrorAction SilentlyContinue
    if ($sizeInMBs) {
        $maxSizeGB = [math]::Round($sizeInMBs.SizeInMBs / 1024, 2)
        Write-Host "  Max Profile Size: $maxSizeGB GB ($($sizeInMBs.SizeInMBs) MB)" -ForegroundColor Gray
        $percentUsed = [math]::Round(($totalSizeMB / $sizeInMBs.SizeInMBs) * 100, 1)
        Write-Host "  Space Used: $percentUsed%" -ForegroundColor $(if ($percentUsed -gt 90) { "Red" } elseif ($percentUsed -gt 70) { "Yellow" } else { "Green" })
    }
    else {
        Write-Host "  Max Profile Size: Not configured (using default)" -ForegroundColor Gray
    }
}
else {
    Write-Host "  FSLogix registry path not found" -ForegroundColor Yellow
}
Write-Host ""

# Analyze by top-level folders
Write-Host "Top-Level Folder Sizes:" -ForegroundColor Cyan
$topLevelFolders = Get-ChildItem -Path $ProfilePath -Directory -ErrorAction SilentlyContinue | 
    ForEach-Object {
        $folderSize = (Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{
            Name = $_.Name
            SizeGB = [math]::Round($folderSize / 1GB, 2)
            SizeMB = [math]::Round($folderSize / 1MB, 2)
            Path = $_.FullName
        }
    } | Sort-Object -Property SizeMB -Descending

$topLevelFolders | Format-Table -Property Name, SizeGB, SizeMB -AutoSize
Write-Host ""

# Find largest files
Write-Host "Largest Files (over $MinSizeMB MB):" -ForegroundColor Cyan
$largeFiles = Get-ChildItem -Path $ProfilePath -Recurse -File -ErrorAction SilentlyContinue | 
    Where-Object { $_.Length -gt ($MinSizeMB * 1MB) } |
    Select-Object FullName, @{Name="SizeGB";Expression={[math]::Round($_.Length / 1GB, 2)}}, @{Name="SizeMB";Expression={[math]::Round($_.Length / 1MB, 2)}} |
    Sort-Object -Property SizeMB -Descending | 
    Select-Object -First $TopFolders

if ($largeFiles) {
    $largeFiles | Format-Table -Property @{Label="File";Expression={$_.FullName.Replace($ProfilePath, "...")}}, SizeGB, SizeMB -AutoSize
    Write-Host ""
}
else {
    Write-Host "  No files found over $MinSizeMB MB" -ForegroundColor Gray
    Write-Host ""
}

# Check common culprits
Write-Host "Common Large Items:" -ForegroundColor Cyan

# Outlook OST files
$ostFiles = Get-ChildItem -Path $ProfilePath -Recurse -Filter "*.ost" -ErrorAction SilentlyContinue
if ($ostFiles) {
    $ostTotal = ($ostFiles | Measure-Object -Property Length -Sum).Sum
    $ostTotalGB = [math]::Round($ostTotal / 1GB, 2)
    Write-Host "  Outlook OST files: $ostTotalGB GB ($($ostFiles.Count) file(s))" -ForegroundColor $(if ($ostTotalGB -gt 10) { "Red" } else { "Yellow" })
    foreach ($ost in $ostFiles | Sort-Object Length -Descending | Select-Object -First 5) {
        $ostSizeGB = [math]::Round($ost.Length / 1GB, 2)
        Write-Host "    - $($ost.Name): $ostSizeGB GB" -ForegroundColor Gray
    }
}
else {
    Write-Host "  Outlook OST files: Not found" -ForegroundColor Gray
}

# Temp files
$tempPaths = @(
    "$ProfilePath\AppData\Local\Temp",
    "$ProfilePath\AppData\Local\Microsoft\Windows\INetCache",
    "$ProfilePath\AppData\Local\Microsoft\Windows\WebCache"
)

foreach ($tempPath in $tempPaths) {
    if (Test-Path $tempPath) {
        $tempSize = (Get-ChildItem -Path $tempPath -Recurse -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
        if ($tempSize -gt 0) {
            $tempSizeGB = [math]::Round($tempSize / 1GB, 2)
            $folderName = Split-Path $tempPath -Leaf
            Write-Host "  $folderName: $tempSizeGB GB" -ForegroundColor $(if ($tempSizeGB -gt 5) { "Red" } else { "Yellow" })
        }
    }
}

# Downloads folder
$downloadsPath = "$ProfilePath\Downloads"
if (Test-Path $downloadsPath) {
    $downloadsSize = (Get-ChildItem -Path $downloadsPath -Recurse -ErrorAction SilentlyContinue | 
        Measure-Object -Property Length -Sum).Sum
    if ($downloadsSize -gt 0) {
        $downloadsSizeGB = [math]::Round($downloadsSize / 1GB, 2)
        Write-Host "  Downloads: $downloadsSizeGB GB" -ForegroundColor $(if ($downloadsSizeGB -gt 5) { "Red" } else { "Yellow" })
    }
}

# OneDrive cache
$oneDrivePath = "$ProfilePath\AppData\Local\Microsoft\OneDrive"
if (Test-Path $oneDrivePath) {
    $oneDriveSize = (Get-ChildItem -Path $oneDrivePath -Recurse -ErrorAction SilentlyContinue | 
        Measure-Object -Property Length -Sum).Sum
    if ($oneDriveSize -gt 0) {
        $oneDriveSizeGB = [math]::Round($oneDriveSize / 1GB, 2)
        Write-Host "  OneDrive Cache: $oneDriveSizeGB GB" -ForegroundColor $(if ($oneDriveSizeGB -gt 5) { "Red" } else { "Yellow" })
    }
}

# Chrome cache
$chromePath = "$ProfilePath\AppData\Local\Google\Chrome\User Data\Default\Cache"
if (Test-Path $chromePath) {
    $chromeSize = (Get-ChildItem -Path $chromePath -Recurse -ErrorAction SilentlyContinue | 
        Measure-Object -Property Length -Sum).Sum
    if ($chromeSize -gt 0) {
        $chromeSizeGB = [math]::Round($chromeSize / 1GB, 2)
        Write-Host "  Chrome Cache: $chromeSizeGB GB" -ForegroundColor $(if ($chromeSizeGB -gt 5) { "Red" } else { "Yellow" })
    }
}

# Edge cache
$edgePath = "$ProfilePath\AppData\Local\Microsoft\Edge\User Data\Default\Cache"
if (Test-Path $edgePath) {
    $edgeSize = (Get-ChildItem -Path $edgePath -Recurse -ErrorAction SilentlyContinue | 
        Measure-Object -Property Length -Sum).Sum
    if ($edgeSize -gt 0) {
        $edgeSizeGB = [math]::Round($edgeSize / 1GB, 2)
        Write-Host "  Edge Cache: $edgeSizeGB GB" -ForegroundColor $(if ($edgeSizeGB -gt 5) { "Red" } else { "Yellow" })
    }
}

Write-Host ""

# Detailed folder breakdown
Write-Host "Detailed Folder Breakdown (Top $TopFolders):" -ForegroundColor Cyan
$allFolders = Get-ChildItem -Path $ProfilePath -Recurse -Directory -ErrorAction SilentlyContinue | 
    ForEach-Object {
        $folderSize = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
        if ($folderSize -gt ($MinSizeMB * 1MB)) {
            [PSCustomObject]@{
                Path = $_.FullName.Replace($ProfilePath, "...")
                SizeGB = [math]::Round($folderSize / 1GB, 2)
                SizeMB = [math]::Round($folderSize / 1MB, 2)
            }
        }
    } | Sort-Object -Property SizeMB -Descending | Select-Object -First $TopFolders

if ($allFolders) {
    $allFolders | Format-Table -Property Path, SizeGB, SizeMB -AutoSize
}
Write-Host ""

# Recommendations
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Recommendations" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if ($totalSizeGB -gt 30) {
    Write-Host "WARNING: Profile is extremely large ($totalSizeGB GB)!" -ForegroundColor Red
    Write-Host ""
}

if ($ostFiles -and ($ostFiles | Measure-Object -Property Length -Sum).Sum / 1GB -gt 10) {
    Write-Host "1. Outlook OST files are large. Consider:" -ForegroundColor Yellow
    Write-Host "   - Reducing cached mail period (currently set via GPO)" -ForegroundColor Gray
    Write-Host "   - Archive old emails" -ForegroundColor Gray
    Write-Host "   - Check Outlook cached mode settings" -ForegroundColor Gray
    Write-Host ""
}

$tempTotal = 0
foreach ($tempPath in $tempPaths) {
    if (Test-Path $tempPath) {
        $tempTotal += (Get-ChildItem -Path $tempPath -Recurse -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
    }
}
if ($tempTotal / 1GB -gt 5) {
    Write-Host "2. Temporary files are large. Consider:" -ForegroundColor Yellow
    Write-Host "   - Running Disk Cleanup" -ForegroundColor Gray
    Write-Host "   - Clearing browser caches" -ForegroundColor Gray
    Write-Host "   - Setting up automated temp file cleanup" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "3. Check FSLogix size limits:" -ForegroundColor Yellow
Write-Host "   - Current max: Check registry HKLM:\SOFTWARE\FSLogix\Profiles\SizeInMBs" -ForegroundColor Gray
Write-Host "   - Consider setting a quota if not already set" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Use FSLogix Profile Status script for ongoing monitoring:" -ForegroundColor Yellow
Write-Host "   pwsh -File `"C:\Program Files\FSLogixStatus\FSLogix-Status.ps1`"" -ForegroundColor Gray
Write-Host ""

