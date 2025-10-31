#description: Join Windows VM to Active Directory domain
#execution mode: IndividualWithRestart
#tags: Domain, Configuration

<#
.SYNOPSIS
    Joins a Windows computer to an Active Directory domain.

.DESCRIPTION
    Prompts for domain information and credentials, then joins the computer to the domain.
    Optionally allows specifying an Organizational Unit (OU) path.

.EXAMPLE
    .\join-domain.ps1
#>

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Domain Join Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if already domain joined
$currentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
$partOfDomain = (Get-WmiObject Win32_ComputerSystem).PartOfDomain

if ($partOfDomain -eq $true) {
    Write-Warning "This computer is already joined to domain: $currentDomain"
    $continue = Read-Host "Do you want to leave the domain and join a different one? (Y/N)"
    if ($continue -ne 'Y' -and $continue -ne 'y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "Leaving domain..." -ForegroundColor Yellow
    Remove-Computer -UnjoinDomainCredential (Get-Credential -Message "Enter domain admin credentials to unjoin") -Force -Restart
    exit 0
}

# Prompt for domain name
Write-Host "Enter the domain name (e.g., contoso.com or CONTOSO):" -ForegroundColor Yellow
$domainName = Read-Host "Domain name"
if ([string]::IsNullOrWhiteSpace($domainName)) {
    Write-Error "Domain name cannot be empty."
    exit 1
}

# Prompt for OU (optional)
Write-Host ""
Write-Host "Enter Organizational Unit (OU) path (optional, e.g., OU=Workstations,DC=contoso,DC=com):" -ForegroundColor Yellow
Write-Host "Press Enter to skip and use default location."
$ouPath = Read-Host "OU Path"
if ([string]::IsNullOrWhiteSpace($ouPath)) {
    $ouPath = $null
    Write-Host "Using default domain location." -ForegroundColor Gray
} else {
    Write-Host "Will join to OU: $ouPath" -ForegroundColor Gray
}

# Prompt for credentials
Write-Host ""
Write-Host "Enter domain administrator credentials:" -ForegroundColor Yellow
$domainCredential = Get-Credential -Message "Enter domain admin credentials (DOMAIN\username format recommended)"

if ($null -eq $domainCredential) {
    Write-Error "Credentials are required."
    exit 1
}

# Optional: Set computer name
Write-Host ""
$changeName = Read-Host "Do you want to change the computer name? (Y/N, default: N)"
if ($changeName -eq 'Y' -or $changeName -eq 'y') {
    $newComputerName = Read-Host "Enter new computer name"
    if (-not [string]::IsNullOrWhiteSpace($newComputerName)) {
        Write-Host "Renaming computer to: $newComputerName" -ForegroundColor Cyan
        Rename-Computer -NewName $newComputerName -Force
        Write-Host "Computer renamed. Restart required before domain join." -ForegroundColor Yellow
        $restart = Read-Host "Restart now? (Y/N)"
        if ($restart -eq 'Y' -or $restart -eq 'y') {
            Restart-Computer -Force
            exit 0
        }
    }
}

# Attempt to join domain
Write-Host ""
Write-Host "Attempting to join domain: $domainName" -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Gray

try {
    if ($ouPath) {
        # Join with OU specified
        Add-Computer -DomainName $domainName -OUPath $ouPath -Credential $domainCredential -Force -ErrorAction Stop
        Write-Host "Successfully joined domain: $domainName" -ForegroundColor Green
        Write-Host "OU Path: $ouPath" -ForegroundColor Green
    } else {
        # Join without OU (default location)
        Add-Computer -DomainName $domainName -Credential $domainCredential -Force -ErrorAction Stop
        Write-Host "Successfully joined domain: $domainName" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Domain join successful!" -ForegroundColor Green
    Write-Host "A restart is required for changes to take effect." -ForegroundColor Yellow
    Write-Host ""
    
    $restart = Read-Host "Restart computer now? (Y/N)"
    if ($restart -eq 'Y' -or $restart -eq 'y') {
        Write-Host "Restarting computer in 10 seconds..." -ForegroundColor Cyan
        Start-Sleep -Seconds 2
        Restart-Computer -Force
    } else {
        Write-Host "Please restart the computer manually when ready." -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Failed to join domain: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    exit 1
}

