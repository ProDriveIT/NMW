<#
.SYNOPSIS
    Downloads and executes PowerShell scripts from the NMW GitHub repository.

.DESCRIPTION
    This helper script allows you to call any script from your NMW GitHub repository
    from anywhere without needing to clone the entire repo. It downloads the script
    to a temporary location and executes it with the provided parameters.

.PARAMETER ScriptPath
    The relative path to the script within the repository.
    Examples: 
    - "windows-scripts/install-m365-apps.ps1"
    - "custom-image-template-scripts/admin-sysprep.ps1"
    - "azure-runbooks/Update AVD Agent.ps1"

.PARAMETER GitHubUser
    Your GitHub username or organization name.
    Default: Will attempt to detect from git remote or prompt if not found.

.PARAMETER Repository
    The repository name. Default: "NMW"

.PARAMETER Branch
    The branch to use. Default: "main"

.PARAMETER Arguments
    Arguments to pass to the script. Use hashtable for named parameters.

.EXAMPLE
    # Simple execution
    .\Invoke-NMWScript.ps1 -ScriptPath "windows-scripts/install-m365-apps.ps1"

.EXAMPLE
    # With GitHub details
    .\Invoke-NMWScript.ps1 -ScriptPath "windows-scripts/install-m365-apps.ps1" -GitHubUser "yourusername" -Branch "main"

.EXAMPLE
    # Direct URL usage (if you know the exact raw URL)
    Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yourusername/NMW/main/scripted-actions/windows-scripts/install-m365-apps.ps1" -UseBasicParsing).Content

.NOTES
    This script requires internet connectivity to download scripts from GitHub.
    The downloaded script will be executed with ExecutionPolicy Bypass.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false)]
    [string]$GitHubUser = "",

    [Parameter(Mandatory = $false)]
    [string]$Repository = "NMW",

    [Parameter(Mandatory = $false)]
    [string]$Branch = "main",

    [Parameter(Mandatory = $false)]
    [hashtable]$Arguments = @{},

    [Parameter(Mandatory = $false)]
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

# Function to detect GitHub user from git remote
function Get-GitHubUserFromRemote {
    $remotes = git remote -v 2>$null
    if ($remotes) {
        foreach ($remote in $remotes) {
            if ($remote -match 'github\.com[/:]([^/]+)/') {
                return $matches[1]
            }
        }
    }
    return $null
}

# Get GitHub user if not provided
if ([string]::IsNullOrEmpty($GitHubUser)) {
    $GitHubUser = Get-GitHubUserFromRemote
    
    if ([string]::IsNullOrEmpty($GitHubUser)) {
        Write-Warning "Could not detect GitHub user from git remote."
        $GitHubUser = Read-Host "Enter your GitHub username or organization name"
    }
}

# Ensure script path uses forward slashes and doesn't start with /
$ScriptPath = $ScriptPath -replace '\\', '/' -replace '^/', ''

# Construct the raw GitHub URL
$basePath = "scripted-actions"
if ($ScriptPath -notlike "$basePath/*") {
    $ScriptPath = "$basePath/$ScriptPath"
}

$rawUrl = "https://raw.githubusercontent.com/$GitHubUser/$Repository/$Branch/$ScriptPath"

Write-Host "Downloading script from: $rawUrl" -ForegroundColor Cyan

try {
    # Download the script
    $scriptContent = Invoke-WebRequest -Uri $rawUrl -UseBasicParsing -ErrorAction Stop
    
    # Create temp file
    $tempScript = Join-Path $env:TEMP "NMW_$(Split-Path -Leaf $ScriptPath)_$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
    $scriptContent.Content | Out-File -FilePath $tempScript -Encoding UTF8
    
    Write-Host "Script downloaded to: $tempScript" -ForegroundColor Green
    Write-Host "Executing script..." -ForegroundColor Cyan
    Write-Host ""

    # Execute the script
    if ($Arguments.Count -gt 0) {
        # Convert hashtable to parameter splatting
        & powershell.exe -ExecutionPolicy Bypass -File $tempScript @Arguments
    } else {
        & powershell.exe -ExecutionPolicy Bypass -File $tempScript
    }
    
    $exitCode = $LASTEXITCODE
    
    # Cleanup
    if (-not $PassThru) {
        Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "Script saved at: $tempScript (not removed due to -PassThru)" -ForegroundColor Yellow
    }
    
    if ($exitCode -ne 0 -and $exitCode -ne $null) {
        exit $exitCode
    }
}
catch {
    Write-Error "Failed to download or execute script: $_"
    Write-Error "URL attempted: $rawUrl"
    exit 1
}

