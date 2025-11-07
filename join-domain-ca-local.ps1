# Quick Domain Join Script for ca.local domain
# Run this on the VM after fixing DNS

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Domain Join to ca.local" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if already domain joined
$currentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
$partOfDomain = (Get-WmiObject Win32_ComputerSystem).PartOfDomain

if ($partOfDomain -eq $true) {
    Write-Host "Computer is already joined to domain: $currentDomain" -ForegroundColor Green
    if ($currentDomain -eq "ca.local") {
        Write-Host "Already joined to the correct domain. No action needed." -ForegroundColor Green
        exit 0
    }
    else {
        Write-Warning "Joined to different domain: $currentDomain"
        Write-Host "You would need to leave the current domain first." -ForegroundColor Yellow
        exit 1
    }
}

# Domain configuration
$domainName = "ca.local"
Write-Host "Domain to join: $domainName" -ForegroundColor Cyan
Write-Host ""

# Test DNS resolution first
Write-Host "Testing DNS resolution for $domainName..." -ForegroundColor Yellow
try {
    $dnsResult = nslookup $domainName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "DNS resolution successful" -ForegroundColor Green
    }
    else {
        Write-Warning "DNS resolution may have issues. Continuing anyway..."
    }
}
catch {
    Write-Warning "Could not test DNS resolution: $_"
}

# Test domain controller discovery
Write-Host "Testing domain controller discovery..." -ForegroundColor Yellow
try {
    $dcResult = nltest /dsgetdc:$domainName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Domain controller discovery successful" -ForegroundColor Green
        Write-Host $dcResult
    }
    else {
        Write-Error "Cannot discover domain controller for $domainName"
        Write-Error "Please verify:"
        Write-Error "  1. DNS is configured correctly on the VNet"
        Write-Error "  2. Network connectivity to domain controllers"
        Write-Error "  3. NSG rules allow required ports"
        exit 1
    }
}
catch {
    Write-Error "Domain controller discovery failed: $_"
    exit 1
}

Write-Host ""
Write-Host "Enter domain credentials:" -ForegroundColor Yellow
Write-Host "  Recommended formats:" -ForegroundColor White
Write-Host "    - jstock_jit@ca.local (recommended)" -ForegroundColor Cyan
Write-Host "    - ca.local\jstock_jit (alternative)" -ForegroundColor Cyan
Write-Host "    - jstock_jit@cheesman.co.uk (if UPN suffix is configured)" -ForegroundColor Gray
Write-Host ""

# Prompt for credentials - try ca.local format first
$username = "jstock_jit@ca.local"
Write-Host "Using username: $username" -ForegroundColor Cyan
$domainCredential = Get-Credential -UserName $username -Message "Enter password for domain join"

if ($null -eq $domainCredential) {
    Write-Error "Credentials are required."
    exit 1
}

# Attempt to join domain
Write-Host ""
Write-Host "Attempting to join domain: $domainName" -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

try {
    Add-Computer -DomainName $domainName -Credential $domainCredential -Force -ErrorAction Stop
    Write-Host ""
    Write-Host "Successfully joined domain: $domainName" -ForegroundColor Green
    Write-Host ""
    Write-Host "Domain join successful! Restarting in 10 seconds..." -ForegroundColor Green
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
catch {
    Write-Error "Failed to join domain: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "  1. Verify DNS can resolve $domainName" -ForegroundColor White
    Write-Host "  2. Try using NetBIOS format: ca.local\jstock_jit" -ForegroundColor White
    Write-Host "  3. Verify account has permissions to join computers to domain" -ForegroundColor White
    Write-Host "  4. Check network connectivity to domain controllers" -ForegroundColor White
    Write-Host "  5. Verify NSG rules allow required ports (53, 88, 389, etc.)" -ForegroundColor White
    Write-Host ""
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    exit 1
}


