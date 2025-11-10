#description: Exports and compares settings from all GPOs with "AVD" in the name
#tags: Group Policy, GPO, AVD, Comparison

<#
.SYNOPSIS
    Exports and compares settings from all GPOs with "AVD" in the name.

.DESCRIPTION
    This script exports all Group Policy Objects (GPOs) with "AVD" in the name to HTML and XML reports,
    and optionally creates a comparison document showing all settings across GPOs.

.PARAMETER OutputPath
    Directory where reports will be saved. Defaults to current directory.

.PARAMETER Format
    Export format: 'HTML', 'XML', or 'Both'. Default is 'Both'.

.PARAMETER CreateComparison
    If specified, creates a comparison document showing all settings across GPOs.

.EXAMPLE
    .\compare-avd-gpos.ps1
    
.EXAMPLE
    .\compare-avd-gpos.ps1 -OutputPath "C:\GPOReports" -CreateComparison
    
.NOTES
    Requires:
    - Group Policy Management Console (GPMC) PowerShell module
    - Run on Domain Controller or management machine with RSAT installed
    - Import-Module GroupPolicy
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Get-Location).Path,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('HTML', 'XML', 'Both')]
    [string]$Format = 'Both',
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateComparison = $false
)

$ErrorActionPreference = 'Stop'

# Import Group Policy module
try {
    Import-Module GroupPolicy -ErrorAction Stop
    Write-Host "Group Policy module loaded" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import GroupPolicy module. Ensure RSAT is installed and GPMC is available."
    exit 1
}

# Get all GPOs with "AVD" in the name
Write-Host "`nFinding GPOs with 'AVD' in the name..." -ForegroundColor Cyan
$allGPOs = Get-GPO -All | Where-Object { $_.DisplayName -like "*AVD*" }

if ($allGPOs.Count -eq 0) {
    Write-Warning "No GPOs found with 'AVD' in the name."
    exit 0
}

Write-Host "Found $($allGPOs.Count) GPO(s):" -ForegroundColor Green
foreach ($gpo in $allGPOs) {
    Write-Host "  - $($gpo.DisplayName)" -ForegroundColor Gray
}

# Create output directory
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportDir = Join-Path $OutputPath "AVD-GPO-Reports-$timestamp"
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
Write-Host "`nReports will be saved to: $reportDir" -ForegroundColor Yellow

# Export each GPO
$gpoReports = @()

foreach ($gpo in $allGPOs) {
    $gpoName = $gpo.DisplayName
    $safeName = $gpoName -replace '[<>:"/\\|?*]', '_'
    
    Write-Host "`nExporting: $gpoName..." -ForegroundColor Cyan
    
    $reportInfo = @{
        Name = $gpoName
        Id = $gpo.Id
        SafeName = $safeName
    }
    
    # Export HTML report
    if ($Format -eq 'HTML' -or $Format -eq 'Both') {
        $htmlPath = Join-Path $reportDir "$safeName.html"
        try {
            Get-GPOReport -Name $gpoName -ReportType Html -Path $htmlPath -ErrorAction Stop
            Write-Host "  HTML report: $htmlPath" -ForegroundColor Green
            $reportInfo.HtmlPath = $htmlPath
        }
        catch {
            Write-Warning "  Failed to export HTML: $_"
        }
    }
    
    # Export XML report
    if ($Format -eq 'XML' -or $Format -eq 'Both') {
        $xmlPath = Join-Path $reportDir "$safeName.xml"
        try {
            Get-GPOReport -Name $gpoName -ReportType Xml -Path $xmlPath -ErrorAction Stop
            Write-Host "  XML report: $xmlPath" -ForegroundColor Green
            $reportInfo.XmlPath = $xmlPath
        }
        catch {
            Write-Warning "  Failed to export XML: $_"
        }
    }
    
    $gpoReports += $reportInfo
}

# Create comparison document if requested
if ($CreateComparison) {
    Write-Host "`nCreating comparison document..." -ForegroundColor Cyan
    
    $comparisonPath = Join-Path $reportDir "AVD-GPO-Comparison.txt"
    $comparison = @()
    $comparison += "=" * 80
    $comparison += "AVD GPO Settings Comparison"
    $comparison += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $comparison += "=" * 80
    $comparison += ""
    
    foreach ($gpoReport in $gpoReports) {
        if ($gpoReport.XmlPath -and (Test-Path $gpoReport.XmlPath)) {
            $comparison += "-" * 80
            $comparison += "GPO: $($gpoReport.Name)"
            $comparison += "-" * 80
            $comparison += ""
            
            try {
                [xml]$xml = Get-Content $gpoReport.XmlPath
                
                # Extract Computer Configuration settings
                $computerSettings = $xml.GPO.Computer.ExtensionData.Extension
                if ($computerSettings) {
                    $comparison += "Computer Configuration Settings:"
                    $comparison += ""
                    
                    foreach ($extension in $computerSettings) {
                        $extName = $extension.Name
                        if ($extName) {
                            $comparison += "  Extension: $extName"
                            
                            # Registry settings
                            if ($extension.RegistrySettings) {
                                $comparison += "    Registry Settings:"
                                foreach ($setting in $extension.RegistrySettings.Registry) {
                                    $comparison += "      Key: $($setting.Key)"
                                    $comparison += "      Value: $($setting.ValueName) = $($setting.Value)"
                                    $comparison += ""
                                }
                            }
                            
                            # Policy settings
                            if ($extension.Policy) {
                                $comparison += "    Policy Settings:"
                                foreach ($policy in $extension.Policy) {
                                    $comparison += "      $($policy.Name): $($policy.State)"
                                    $comparison += ""
                                }
                            }
                        }
                    }
                }
                
                # Extract User Configuration settings
                $userSettings = $xml.GPO.User.ExtensionData.Extension
                if ($userSettings) {
                    $comparison += "User Configuration Settings:"
                    $comparison += ""
                    
                    foreach ($extension in $userSettings) {
                        $extName = $extension.Name
                        if ($extName) {
                            $comparison += "  Extension: $extName"
                            
                            if ($extension.RegistrySettings) {
                                $comparison += "    Registry Settings:"
                                foreach ($setting in $extension.RegistrySettings.Registry) {
                                    $comparison += "      Key: $($setting.Key)"
                                    $comparison += "      Value: $($setting.ValueName) = $($setting.Value)"
                                    $comparison += ""
                                }
                            }
                            
                            if ($extension.Policy) {
                                $comparison += "    Policy Settings:"
                                foreach ($policy in $extension.Policy) {
                                    $comparison += "      $($policy.Name): $($policy.State)"
                                    $comparison += ""
                                }
                            }
                        }
                    }
                }
                
                $comparison += ""
            }
            catch {
                $comparison += "  Error parsing XML: $_"
                $comparison += ""
            }
        }
    }
    
    $comparison | Out-File -FilePath $comparisonPath -Encoding UTF8
    Write-Host "Comparison document: $comparisonPath" -ForegroundColor Green
}

# Summary
Write-Host "`n" + "=" * 80 -ForegroundColor Cyan
Write-Host "Export Complete!" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Reports saved to: $reportDir" -ForegroundColor Yellow
Write-Host "`nTo view HTML reports, open them in a web browser." -ForegroundColor Gray
Write-Host "To compare XML reports, use a diff tool or XML editor." -ForegroundColor Gray

# Open reports folder
if (Test-Path $reportDir) {
    Write-Host "`nOpening reports folder..." -ForegroundColor Cyan
    Start-Process explorer.exe -ArgumentList $reportDir
}

