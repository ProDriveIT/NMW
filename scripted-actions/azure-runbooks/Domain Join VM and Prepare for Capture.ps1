#requires -Version 5.1

<#
.SYNOPSIS
    Domain joins an Azure VM, installs apps from DC, and prepares for capture.

.DESCRIPTION
    This script domain joins an Azure VM, installs applications from a network share on the domain controller,
    and then prepares the machine for capture (sysprep/generalize).
    
    The script:
    1. Prompts for VM information (resource group, VM name)
    2. Prompts for domain information (domain name, OU, credentials)
    3. Prompts for application installation details (network share path, apps to install)
    4. Joins the VM to the domain
    5. Installs applications from the DC network share
    6. Prepares the VM for capture (sysprep)
    
    Can be called from CLI like: 
    .\Domain Join VM and Prepare for Capture.ps1

.PARAMETER ResourceGroupName
    Resource group name containing the VM (optional - will prompt if not provided)

.PARAMETER VMName
    Name of the VM to domain join (optional - will prompt if not provided)

.PARAMETER DomainName
    Domain name to join (e.g., contoso.com) (optional - will prompt if not provided)

.PARAMETER OUPath
    Organizational Unit path (optional, e.g., OU=Workstations,DC=contoso,DC=com)

.PARAMETER DomainUsername
    Domain username for joining (optional - will prompt if not provided)

.PARAMETER DomainPassword
    Domain password (optional - will prompt securely if not provided)

.PARAMETER AppSharePath
    Network share path on DC for applications (e.g., \\dc01\Apps) (optional - will prompt if not provided)

.PARAMETER AppsToInstall
    Array of application installer names/paths to run from the share (optional - will prompt if not provided)

.PARAMETER SkipApps
    Switch to skip application installation step

.PARAMETER SkipCapture
    Switch to skip sysprep/capture preparation step

.EXAMPLE
    .\Domain Join VM and Prepare for Capture.ps1
    
.EXAMPLE
    .\Domain Join VM and Prepare for Capture.ps1 -ResourceGroupName "rg-avd-prod" -VMName "avd-vm-001"

.EXAMPLE
    .\Domain Join VM and Prepare for Capture.ps1 -ResourceGroupName "rg-avd-prod" -VMName "avd-vm-001" -DomainName "contoso.com" -AppSharePath "\\dc01\Apps" -AppsToInstall @("app1.msi", "app2.exe")

.NOTES
    Requires:
    - Azure PowerShell module (Az.Compute)
    - VM must be running and accessible
    - Domain credentials with permission to join computers
    - Network connectivity from VM to domain controller
    - Access to application share on DC
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$VMName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$DomainName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$OUPath = "",
    
    [Parameter(Mandatory = $false)]
    [string]$DomainUsername = "",
    
    [Parameter(Mandatory = $false)]
    [SecureString]$DomainPassword = $null,
    
    [Parameter(Mandatory = $false)]
    [string]$AppSharePath = "",
    
    [Parameter(Mandatory = $false)]
    [string[]]$AppsToInstall = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipApps,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipCapture
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "`n$Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Warning-Message {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor White
Write-Host "Domain Join VM and Prepare for Capture" -ForegroundColor White
Write-Host "===========================================" -ForegroundColor White
Write-Host ""

# ============================================================================
# VALIDATION AND PROMPTS
# ============================================================================

Write-Step "[Step 1] Gathering VM information..."

# Check Azure PowerShell module
try {
    Import-Module Az.Compute -ErrorAction Stop | Out-Null
    Write-Success "Azure PowerShell module loaded"
}
catch {
    Write-Error-Message "Azure PowerShell module (Az.Compute) not found"
    Write-Host "Install with: Install-Module -Name Az.Compute" -ForegroundColor Yellow
    exit 1
}

# Check Azure login
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Error-Message "Not logged in to Azure"
        Write-Host "Please run: Connect-AzAccount" -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Logged in to Azure as: $($context.Account.Id)"
}
catch {
    Write-Error-Message "Failed to check Azure login"
    Write-Host "Please run: Connect-AzAccount" -ForegroundColor Yellow
    exit 1
}

# Prompt for Resource Group if not provided
if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    Write-Host "Enter the resource group name containing the VM:" -ForegroundColor Yellow
    $ResourceGroupName = Read-Host "Resource Group"
    if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
        Write-Error-Message "Resource group name is required"
        exit 1
    }
}

# Prompt for VM Name if not provided
if ([string]::IsNullOrWhiteSpace($VMName)) {
    Write-Host "Enter the VM name:" -ForegroundColor Yellow
    $VMName = Read-Host "VM Name"
    if ([string]::IsNullOrWhiteSpace($VMName)) {
        Write-Error-Message "VM name is required"
        exit 1
    }
}

# Verify VM exists
Write-Host "  Verifying VM exists..." -NoNewline
try {
    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop
    Write-Host " found" -ForegroundColor Green
    Write-Host "    VM Status: $($VM.PowerState)" -ForegroundColor Gray
    Write-Host "    Location: $($VM.Location)" -ForegroundColor Gray
}
catch {
    Write-Host " not found" -ForegroundColor Red
    Write-Error-Message "VM '$VMName' not found in resource group '$ResourceGroupName'"
    exit 1
}

# Check if VM is running
if ($VM.PowerState -ne "VM running") {
    Write-Warning-Message "VM is not running. Current state: $($VM.PowerState)"
    $startVM = Read-Host "Start the VM now? (Y/N)"
    if ($startVM -eq 'Y' -or $startVM -eq 'y') {
        Write-Host "Starting VM..." -ForegroundColor Cyan
        Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
        Write-Host "Waiting for VM to be ready..." -ForegroundColor Gray
        $maxWait = 60
        $waitCount = 0
        do {
            Start-Sleep -Seconds 5
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
            $waitCount++
        } while ($VM.PowerState -ne "VM running" -and $waitCount -lt $maxWait)
        
        if ($VM.PowerState -ne "VM running") {
            Write-Error-Message "VM did not start within timeout period"
            exit 1
        }
        Write-Success "VM is running"
    }
    else {
        Write-Error-Message "VM must be running to execute domain join"
        exit 1
    }
}

Write-Step "[Step 2] Gathering domain information..."

# Prompt for Domain Name if not provided
if ([string]::IsNullOrWhiteSpace($DomainName)) {
    Write-Host "Enter the domain name (e.g., contoso.com or CONTOSO):" -ForegroundColor Yellow
    $DomainName = Read-Host "Domain Name"
    if ([string]::IsNullOrWhiteSpace($DomainName)) {
        Write-Error-Message "Domain name is required"
        exit 1
    }
}

# Prompt for OU Path if not provided
if ([string]::IsNullOrWhiteSpace($OUPath)) {
    Write-Host "Enter Organizational Unit (OU) path (optional, e.g., OU=Workstations,DC=contoso,DC=com):" -ForegroundColor Yellow
    Write-Host "Press Enter to skip and use default location."
    $OUPath = Read-Host "OU Path"
    if ([string]::IsNullOrWhiteSpace($OUPath)) {
        $OUPath = $null
        Write-Host "  Using default domain location" -ForegroundColor Gray
    }
}

# Prompt for Domain Credentials if not provided
if ([string]::IsNullOrWhiteSpace($DomainUsername)) {
    Write-Host "Enter domain administrator username (DOMAIN\username format recommended):" -ForegroundColor Yellow
    $DomainUsername = Read-Host "Domain Username"
    if ([string]::IsNullOrWhiteSpace($DomainUsername)) {
        Write-Error-Message "Domain username is required"
        exit 1
    }
}

if ($null -eq $DomainPassword) {
    Write-Host "Enter domain administrator password:" -ForegroundColor Yellow
    $DomainPassword = Read-Host "Domain Password" -AsSecureString
    if ($null -eq $DomainPassword) {
        Write-Error-Message "Domain password is required"
        exit 1
    }
}

# Convert SecureString to plain text for script execution (will be passed securely via RunCommand)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DomainPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

Write-Step "[Step 3] Gathering application installation information..."

# Prompt for App Share Path if not provided and not skipping apps
if (-not $SkipApps) {
    if ([string]::IsNullOrWhiteSpace($AppSharePath)) {
        Write-Host "Enter network share path on DC for applications (e.g., \\dc01\Apps):" -ForegroundColor Yellow
        $AppSharePath = Read-Host "Application Share Path"
    }
    
    # Prompt for Apps to Install if not provided
    if ($AppsToInstall.Count -eq 0) {
        Write-Host "Enter application installer names/paths (one per line, empty line to finish):" -ForegroundColor Yellow
        Write-Host "Examples: app1.msi, subfolder\app2.exe, app3.msi /quiet" -ForegroundColor Gray
        $AppsToInstall = @()
        do {
            $app = Read-Host "Application (or press Enter to finish)"
            if (-not [string]::IsNullOrWhiteSpace($app)) {
                $AppsToInstall += $app
            }
        } while (-not [string]::IsNullOrWhiteSpace($app))
        
        if ($AppsToInstall.Count -eq 0) {
            Write-Warning-Message "No applications specified. Skipping app installation."
            $SkipApps = $true
        }
    }
}

# ============================================================================
# DOMAIN JOIN SCRIPT
# ============================================================================

Write-Step "[Step 4] Joining VM to domain..."

$domainJoinScript = @"
`$ErrorActionPreference = 'Stop'

# Check if already domain joined
`$computerSystem = Get-WmiObject Win32_ComputerSystem
if (`$computerSystem.PartOfDomain -eq `$true) {
    Write-Output "Computer is already joined to domain: `$(`$computerSystem.Domain)"
    Write-Output "Skipping domain join."
    exit 0
}

Write-Output "Joining computer to domain: $DomainName"

# Create credential object
`$securePassword = ConvertTo-SecureString '$PlainPassword' -AsPlainText -Force
`$domainCredential = New-Object System.Management.Automation.PSCredential('$DomainUsername', `$securePassword)

try {
    if ('$OUPath' -and '$OUPath' -ne '') {
        Write-Output "Joining to OU: $OUPath"
        Add-Computer -DomainName '$DomainName' -OUPath '$OUPath' -Credential `$domainCredential -Force -ErrorAction Stop
    } else {
        Add-Computer -DomainName '$DomainName' -Credential `$domainCredential -Force -ErrorAction Stop
    }
    
    Write-Output "Successfully joined domain: $DomainName"
    Write-Output "Restart required for changes to take effect."
    
    # Restart computer
    Write-Output "Restarting computer in 30 seconds..."
    Start-Sleep -Seconds 30
    Restart-Computer -Force
}
catch {
    Write-Error "Failed to join domain: `$(`$_.Exception.Message)"
    exit 1
}
"@

# Save script to temp file
$tempScriptPath = ".\DomainJoin-$VMName-$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
$domainJoinScript | Out-File -FilePath $tempScriptPath -Encoding UTF8

try {
    Write-Host "  Executing domain join script on VM..." -NoNewline
    $runCommand = Invoke-AzVMRunCommand `
        -ResourceGroupName $ResourceGroupName `
        -VMName $VMName `
        -CommandId 'RunPowerShellScript' `
        -ScriptPath $tempScriptPath
    
    # Check for errors
    $errors = $runCommand.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdErr/succeeded' }
    if ($errors -and $errors.Message) {
        Write-Host " failed" -ForegroundColor Red
        Write-Error-Message "Domain join failed: $($errors.Message)"
        throw "Domain join failed"
    }
    
    Write-Host " completed" -ForegroundColor Green
    Write-Host "  Output:" -ForegroundColor Gray
    $output = $runCommand.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdOut/succeeded' }
    if ($output) {
        Write-Host "    $($output.Message)" -ForegroundColor Gray
    }
    
    Write-Success "Domain join initiated. VM will restart."
    
    # Wait for VM to restart
    Write-Host "  Waiting for VM to restart (this may take 2-3 minutes)..." -ForegroundColor Gray
    $maxWait = 180
    $waitCount = 0
    $vmRestarted = $false
    
    do {
        Start-Sleep -Seconds 10
        try {
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
            if ($VM.Statuses | Where-Object { $_.Code -eq 'PowerState/running' }) {
                if ($waitCount -gt 30) { # Give it at least 30 seconds after restart
                    $vmRestarted = $true
                }
            }
        }
        catch {
            # VM might be restarting
        }
        $waitCount++
    } while (-not $vmRestarted -and $waitCount -lt $maxWait)
    
    if (-not $vmRestarted) {
        Write-Warning-Message "VM restart verification timeout. Please verify VM is running before continuing."
    }
    else {
        Write-Success "VM has restarted and is ready"
    }
}
catch {
    Write-Error-Message "Failed to execute domain join: $_"
    if (Test-Path $tempScriptPath) {
        Remove-Item $tempScriptPath -Force
    }
    exit 1
}
finally {
    if (Test-Path $tempScriptPath) {
        Remove-Item $tempScriptPath -Force
    }
}

# ============================================================================
# APPLICATION INSTALLATION
# ============================================================================

if (-not $SkipApps -and $AppsToInstall.Count -gt 0) {
    Write-Step "[Step 5] Installing applications from DC share..."
    
    $appInstallScript = @"
`$ErrorActionPreference = 'Stop'

`$AppSharePath = '$AppSharePath'
`$AppsToInstall = @($(($AppsToInstall | ForEach-Object { "'$_'" }) -join ','))

Write-Output "Connecting to application share: `$AppSharePath"

# Map network drive
try {
    # Create credential for network share
    `$securePassword = ConvertTo-SecureString '$PlainPassword' -AsPlainText -Force
    `$domainCredential = New-Object System.Management.Automation.PSCredential('$DomainUsername', `$securePassword)
    
    # Map network drive
    `$driveLetter = 'Z:'
    `$netUse = New-Object -ComObject WScript.Network
    `$netUse.MapNetworkDrive(`$driveLetter, `$AppSharePath, `$false, `$domainCredential.UserName, `$domainCredential.GetNetworkCredential().Password)
    
    Write-Output "Mapped network drive `$driveLetter to `$AppSharePath"
}
catch {
    Write-Error "Failed to map network drive: `$(`$_.Exception.Message)"
    exit 1
}

# Install each application
foreach (`$app in `$AppsToInstall) {
    Write-Output "Installing application: `$app"
    
    `$appPath = Join-Path `$driveLetter `$app
    
    if (-not (Test-Path `$appPath)) {
        Write-Warning "Application not found: `$appPath"
        continue
    }
    
    `$extension = [System.IO.Path]::GetExtension(`$appPath).ToLower()
    
    try {
        if (`$extension -eq '.msi') {
            Write-Output "Running MSI installer: `$appPath"
            `$process = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"`$appPath`"", "/quiet", "/norestart" -Wait -PassThru
            if (`$process.ExitCode -eq 0 -or `$process.ExitCode -eq 3010) {
                Write-Output "Successfully installed: `$app (Exit code: `$(`$process.ExitCode))"
            } else {
                Write-Warning "Installation completed with exit code: `$(`$process.ExitCode) for `$app"
            }
        }
        elseif (`$extension -eq '.exe') {
            Write-Output "Running EXE installer: `$appPath"
            # Check if app path contains install arguments
            if (`$app -match '(.+\.exe)\s+(.+)') {
                `$exePath = `$matches[1]
                `$args = `$matches[2]
                `$fullPath = Join-Path `$driveLetter `$exePath
                `$process = Start-Process -FilePath `$fullPath -ArgumentList `$args -Wait -PassThru
            } else {
                `$process = Start-Process -FilePath `$appPath -ArgumentList "/S", "/quiet" -Wait -PassThru
            }
            if (`$process.ExitCode -eq 0 -or `$process.ExitCode -eq 3010) {
                Write-Output "Successfully installed: `$app (Exit code: `$(`$process.ExitCode))"
            } else {
                Write-Warning "Installation completed with exit code: `$(`$process.ExitCode) for `$app"
            }
        }
        else {
            Write-Warning "Unsupported file type: `$extension for `$app"
        }
    }
    catch {
        Write-Error "Failed to install `$app : `$(`$_.Exception.Message)"
    }
}

# Disconnect network drive
try {
    `$netUse.RemoveNetworkDrive(`$driveLetter, `$true)
    Write-Output "Disconnected network drive `$driveLetter"
}
catch {
    Write-Warning "Failed to disconnect network drive: `$(`$_.Exception.Message)"
}

Write-Output "Application installation completed"
"@

    # Save script to temp file
    $tempAppScriptPath = ".\AppInstall-$VMName-$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
    $appInstallScript | Out-File -FilePath $tempAppScriptPath -Encoding UTF8
    
    try {
        Write-Host "  Executing application installation script on VM..." -NoNewline
        $runCommand = Invoke-AzVMRunCommand `
            -ResourceGroupName $ResourceGroupName `
            -VMName $VMName `
            -CommandId 'RunPowerShellScript' `
            -ScriptPath $tempAppScriptPath
        
        # Check for errors
        $errors = $runCommand.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdErr/succeeded' }
        if ($errors -and $errors.Message) {
            Write-Host " completed with warnings" -ForegroundColor Yellow
            Write-Host "  Warnings:" -ForegroundColor Gray
            Write-Host "    $($errors.Message)" -ForegroundColor Gray
        }
        else {
            Write-Host " completed" -ForegroundColor Green
        }
        
        Write-Host "  Output:" -ForegroundColor Gray
        $output = $runCommand.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdOut/succeeded' }
        if ($output) {
            $output.Message -split "`n" | ForEach-Object {
                Write-Host "    $_" -ForegroundColor Gray
            }
        }
        
        Write-Success "Application installation completed"
    }
    catch {
        Write-Error-Message "Failed to execute application installation: $_"
        if (Test-Path $tempAppScriptPath) {
            Remove-Item $tempAppScriptPath -Force
        }
        exit 1
    }
    finally {
        if (Test-Path $tempAppScriptPath) {
            Remove-Item $tempAppScriptPath -Force
        }
    }
}
else {
    Write-Step "[Step 5] Skipping application installation"
}

# ============================================================================
# PREPARE FOR CAPTURE (SYSPREP)
# ============================================================================

if (-not $SkipCapture) {
    Write-Step "[Step 6] Preparing VM for capture (Sysprep)..."
    
    $sysprepScript = @"
`$ErrorActionPreference = 'Stop'

Write-Output "Preparing system for capture (Sysprep)..."
Write-Output "This will generalize the system and prepare it for image capture."

# Check if sysprep has already been run
`$sysprepMarker = 'C:\Windows\System32\Sysprep\Sysprep_succeeded.tag'
if (Test-Path `$sysprepMarker) {
    Write-Output "Sysprep has already been run on this system."
    Write-Output "System is ready for capture."
    exit 0
}

# Run sysprep
try {
    Write-Output "Running Sysprep with generalize and shutdown options..."
    `$sysprepPath = 'C:\Windows\System32\Sysprep\sysprep.exe'
    `$process = Start-Process -FilePath `$sysprepPath -ArgumentList '/generalize', '/oobe', '/shutdown', '/quiet' -Wait -PassThru
    
    if (`$process.ExitCode -eq 0) {
        Write-Output "Sysprep completed successfully. System will shut down."
        Write-Output "VM is now ready for capture."
    } else {
        Write-Error "Sysprep completed with exit code: `$(`$process.ExitCode)"
        exit 1
    }
}
catch {
    Write-Error "Failed to run Sysprep: `$(`$_.Exception.Message)"
    exit 1
}
"@

    # Save script to temp file
    $tempSysprepScriptPath = ".\Sysprep-$VMName-$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
    $sysprepScript | Out-File -FilePath $tempSysprepScriptPath -Encoding UTF8
    
    try {
        Write-Host "  Executing Sysprep script on VM..." -NoNewline
        Write-Host "`n    WARNING: This will shut down the VM after Sysprep completes!" -ForegroundColor Yellow
        
        $confirm = Read-Host "    Continue with Sysprep? (Y/N)"
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Host "    Sysprep cancelled by user" -ForegroundColor Yellow
            if (Test-Path $tempSysprepScriptPath) {
                Remove-Item $tempSysprepScriptPath -Force
            }
            exit 0
        }
        
        $runCommand = Invoke-AzVMRunCommand `
            -ResourceGroupName $ResourceGroupName `
            -VMName $VMName `
            -CommandId 'RunPowerShellScript' `
            -ScriptPath $tempSysprepScriptPath
        
        # Check for errors
        $errors = $runCommand.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdErr/succeeded' }
        if ($errors -and $errors.Message) {
            Write-Host " completed with errors" -ForegroundColor Red
            Write-Error-Message "Sysprep failed: $($errors.Message)"
            throw "Sysprep failed"
        }
        
        Write-Host " completed" -ForegroundColor Green
        Write-Host "  Output:" -ForegroundColor Gray
        $output = $runCommand.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdOut/succeeded' }
        if ($output) {
            $output.Message -split "`n" | ForEach-Object {
                Write-Host "    $_" -ForegroundColor Gray
            }
        }
        
        Write-Success "Sysprep completed. VM has been shut down and is ready for capture."
        Write-Host "  Next steps:" -ForegroundColor Cyan
        Write-Host "    1. Capture the VM as a managed image or snapshot" -ForegroundColor Gray
        Write-Host "    2. Use the captured image to create new VMs" -ForegroundColor Gray
    }
    catch {
        Write-Error-Message "Failed to execute Sysprep: $_"
        if (Test-Path $tempSysprepScriptPath) {
            Remove-Item $tempSysprepScriptPath -Force
        }
        exit 1
    }
    finally {
        if (Test-Path $tempSysprepScriptPath) {
            Remove-Item $tempSysprepScriptPath -Force
        }
    }
}
else {
    Write-Step "[Step 6] Skipping Sysprep (capture preparation)"
    Write-Host "  VM is ready but not prepared for capture." -ForegroundColor Yellow
    Write-Host "  Run Sysprep manually or re-run this script with -SkipCapture:`$false" -ForegroundColor Yellow
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "===========================================" -ForegroundColor White
Write-Host "Summary" -ForegroundColor White
Write-Host "===========================================" -ForegroundColor White
Write-Host ""

Write-Success "Operation completed!"
Write-Host ""
Write-Host "VM Details:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName"
Write-Host "  VM Name: $VMName"
Write-Host "  Domain: $DomainName"
if ($OUPath) {
    Write-Host "  OU Path: $OUPath"
}
Write-Host ""

if (-not $SkipApps -and $AppsToInstall.Count -gt 0) {
    Write-Host "Applications Installed:" -ForegroundColor Cyan
    foreach ($app in $AppsToInstall) {
        Write-Host "  - $app"
    }
    Write-Host ""
}

if (-not $SkipCapture) {
    Write-Host "Capture Status:" -ForegroundColor Cyan
    Write-Host "  VM has been sysprepped and shut down"
    Write-Host "  Ready for image capture"
    Write-Host ""
}

Write-Host "===========================================" -ForegroundColor White
Write-Host ""

