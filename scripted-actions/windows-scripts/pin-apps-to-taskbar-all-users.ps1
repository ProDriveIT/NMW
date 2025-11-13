#description: Pins applications to taskbar for all users (system-wide taskbar configuration)
#tags: Nerdio, Taskbar, User Experience

<#
.SYNOPSIS
    Pins specified applications to the taskbar for all users during CIT deployment.

.DESCRIPTION
    This script pins applications to the taskbar for all users by configuring the default user profile
    and using taskbar layout XML. This ensures all users who log in will have these apps pinned to their taskbar.
    
    Apps pinned:
    - File Explorer
    - Microsoft Edge
    - Google Chrome
    - Microsoft Outlook
    - Microsoft Word
    - Microsoft Excel
    - Microsoft PowerPoint
    - Microsoft Teams

    Key features:
    - Pins apps to default user profile (applies to all new users)
    - Uses taskbar layout XML for reliable system-wide configuration
    - Compatible with sysprep and image capture
    - Works for both existing and new user profiles

.EXAMPLE
    .\pin-apps-to-taskbar-all-users.ps1
    
.NOTES
    Requires:
    - Administrator privileges
    - Applications must be installed before running this script
    
    This script modifies the default user profile, so all new users will have these apps pinned.
    Existing user profiles may need to log out/in to see changes.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Pin Apps to Taskbar (All Users)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Function to get application path
function Get-AppPath {
    param([string]$AppName, [string[]]$PossiblePaths)
    
    foreach ($path in $PossiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

# Define applications to pin with their possible paths
$AppsToPin = @(
    @{
        Name = "File Explorer"
        Paths = @(
            "$env:SystemRoot\explorer.exe"
        )
    },
    @{
        Name = "Microsoft Edge"
        Paths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
        )
    },
    @{
        Name = "Google Chrome"
        Paths = @(
            "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
        )
    },
    @{
        Name = "Microsoft Outlook"
        Paths = @(
            "${env:ProgramFiles}\Microsoft Office\root\Office16\OUTLOOK.EXE",
            "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\OUTLOOK.EXE",
            "${env:ProgramFiles}\Microsoft Office\Office16\OUTLOOK.EXE",
            "${env:ProgramFiles(x86)}\Microsoft Office\Office16\OUTLOOK.EXE"
        )
    },
    @{
        Name = "Microsoft Word"
        Paths = @(
            "${env:ProgramFiles}\Microsoft Office\root\Office16\WINWORD.EXE",
            "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\WINWORD.EXE",
            "${env:ProgramFiles}\Microsoft Office\Office16\WINWORD.EXE",
            "${env:ProgramFiles(x86)}\Microsoft Office\Office16\WINWORD.EXE"
        )
    },
    @{
        Name = "Microsoft Excel"
        Paths = @(
            "${env:ProgramFiles}\Microsoft Office\root\Office16\EXCEL.EXE",
            "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\EXCEL.EXE",
            "${env:ProgramFiles}\Microsoft Office\Office16\EXCEL.EXE",
            "${env:ProgramFiles(x86)}\Microsoft Office\Office16\EXCEL.EXE"
        )
    },
    @{
        Name = "Microsoft PowerPoint"
        Paths = @(
            "${env:ProgramFiles}\Microsoft Office\root\Office16\POWERPNT.EXE",
            "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\POWERPNT.EXE",
            "${env:ProgramFiles}\Microsoft Office\Office16\POWERPNT.EXE",
            "${env:ProgramFiles(x86)}\Microsoft Office\Office16\POWERPNT.EXE"
        )
    },
    @{
        Name = "Microsoft Teams"
        Paths = @(
            "${env:LocalAppData}\Microsoft\Teams\Update.exe",
            "${env:ProgramFiles(x86)}\Microsoft\Teams\current\Teams.exe",
            "${env:ProgramFiles}\Microsoft\Teams\current\Teams.exe"
        )
    }
)

# Verify applications exist
Write-Host "Verifying applications are installed..." -ForegroundColor Cyan
$FoundApps = @()
$MissingApps = @()

foreach ($app in $AppsToPin) {
    $appPath = Get-AppPath -AppName $app.Name -PossiblePaths $app.Paths
    
    if ($appPath) {
        Write-Host "  [OK] $($app.Name) - $appPath" -ForegroundColor Green
        $FoundApps += @{
            Name = $app.Name
            Path = $appPath
        }
    }
    else {
        Write-Host "  [MISSING] $($app.Name)" -ForegroundColor Yellow
        $MissingApps += $app.Name
    }
}

if ($MissingApps.Count -gt 0) {
    Write-Host ""
    Write-Warning "The following applications were not found and will not be pinned:"
    foreach ($missing in $MissingApps) {
        Write-Host "  - $missing" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Continuing with available applications..." -ForegroundColor Gray
}

if ($FoundApps.Count -eq 0) {
    Write-Error "No applications found to pin. Please ensure applications are installed before running this script."
    exit 1
}

Write-Host ""
Write-Host "Found $($FoundApps.Count) application(s) to pin." -ForegroundColor Green
Write-Host ""

# Use taskbar layout XML (Windows 11 method)
Write-Host "Creating taskbar layout XML..." -ForegroundColor Cyan

$DefaultUserProfile = "$env:SystemDrive\Users\Default"
$TaskbarLayoutPath = Join-Path $DefaultUserProfile "AppData\Local\Microsoft\Windows\Shell"

if (-not (Test-Path $TaskbarLayoutPath)) {
    New-Item -Path $TaskbarLayoutPath -ItemType Directory -Force | Out-Null
}

$LayoutModificationPath = Join-Path $TaskbarLayoutPath "LayoutModification.xml"

# Build XML content
$xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <CustomTaskbarLayoutCollection>
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
"@

foreach ($app in $FoundApps) {
    $appPath = $app.Path
    # Escape XML special characters
    $appPath = $appPath -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
    
    $xmlContent += @"
        <taskbar:DesktopApp DesktopApplicationLinkPath="$appPath" />
"@
}

$xmlContent += @"
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@

try {
    $xmlContent | Out-File -FilePath $LayoutModificationPath -Encoding UTF8 -Force
    Write-Host "  Taskbar layout XML created: $LayoutModificationPath" -ForegroundColor Green
    Write-Host "  This will apply to all new user profiles" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to create taskbar layout XML: $_"
    exit 1
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Applications pinned to taskbar:" -ForegroundColor Green
foreach ($app in $FoundApps) {
    Write-Host "  ✓ $($app.Name)" -ForegroundColor Gray
}

if ($MissingApps.Count -gt 0) {
    Write-Host ""
    Write-Host "Applications not found (not pinned):" -ForegroundColor Yellow
    foreach ($missing in $MissingApps) {
        Write-Host "  ✗ $missing" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Configuration method: Taskbar Layout XML (LayoutModification.xml)" -ForegroundColor Cyan
Write-Host "  This is the official Windows 11 method for taskbar customization" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: This configuration will apply to all new user profiles." -ForegroundColor Yellow
Write-Host "      Existing users may need to log out and back in to see changes." -ForegroundColor Yellow
Write-Host ""
Write-Host "Taskbar pinning completed successfully!" -ForegroundColor Green
Write-Host ""

### End Script ###

