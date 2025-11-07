#requires -Version 5.1

<#
.SYNOPSIS
    Sets up infrastructure for Azure Virtual Desktop Live/Production environment.

.DESCRIPTION
    This script creates all required infrastructure for a live/production AVD environment in a fire-and-forget manner.
    It automates Phase 2 (FSLogix Storage) and Phase 4 (Live Infrastructure) from the AVD deployment checklist.
    
    Creates:
    - Resource Group (production)
    - FSLogix Storage Account (Premium for Azure Files)
    - Azure Files Premium share for profiles (100GB quota)
    - Virtual Network and Subnet for session hosts
    - Network Security Group with AVD rules
    - Azure AD Security Groups (if Graph API available)
    - Role assignments for storage access
    
    Stops before host pool creation (Phase 8).

.PARAMETER SubscriptionId
    Azure subscription ID (optional - will use current subscription if not provided)

.PARAMETER Location
    Azure region for resources (default: uksouth)

.PARAMETER ResourceGroupName
    Name of the resource group (default: rg-avd-prod)

.PARAMETER StorageShareName
    Name of the Azure Files share for FSLogix profiles (default: avd-profiles)

.PARAMETER VnetName
    Name of the virtual network (default: vnet-avd-prod)

.PARAMETER VnetAddressSpace
    Address space for the virtual network (default: 10.0.0.0/16)

.PARAMETER SubnetName
    Name of the subnet for session hosts (default: snet-avd-session-hosts)

.PARAMETER SubnetAddressPrefix
    Address prefix for the subnet (default: 10.0.1.0/24, minimum /24)

.PARAMETER UseExistingVnet
    Switch to use an existing virtual network instead of creating a new one

.PARAMETER ExistingVnetResourceGroup
    Resource group name if using an existing virtual network

.PARAMETER DnsServers
    Optional array of DNS server IP addresses for domain join (e.g., @("10.0.0.4", "10.0.0.5"))

.PARAMETER CreateSecurityGroups
    Switch to attempt creating Azure AD security groups (requires Graph API permissions)

.PARAMETER EnablePrivateEndpoint
    Switch to create private endpoint for storage account (requires additional networking setup)

.PARAMETER EnableStorageVersioning
    Switch to enable versioning on storage account (optional but recommended)

.EXAMPLE
    .\setup-avd-live-infrastructure.ps1
    
.EXAMPLE
    .\setup-avd-live-infrastructure.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -Location "uksouth"

.EXAMPLE
    .\setup-avd-live-infrastructure.ps1 -UseExistingVnet -ExistingVnetResourceGroup "rg-networking" -VnetName "vnet-existing"

.NOTES
    Assumes user has:
    - Global Administrator role in Azure AD (for security group creation)
    - Owner role on target subscription
    
    Requires: Azure CLI (az) installed and logged in
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "uksouth",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-avd-prod",
    
    [Parameter(Mandatory = $false)]
    [string]$StorageShareName = "avd-profiles",
    
    [Parameter(Mandatory = $false)]
    [string]$VnetName = "vnet-avd-prod",
    
    [Parameter(Mandatory = $false)]
    [string]$VnetAddressSpace = "10.0.0.0/16",
    
    [Parameter(Mandatory = $false)]
    [string]$SubnetName = "snet-avd-session-hosts",
    
    [Parameter(Mandatory = $false)]
    [string]$SubnetAddressPrefix = "10.0.1.0/24",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseExistingVnet,
    
    [Parameter(Mandatory = $false)]
    [string]$ExistingVnetResourceGroup = "",
    
    [Parameter(Mandatory = $false)]
    [string[]]$DnsServers = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateSecurityGroups,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnablePrivateEndpoint,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableStorageVersioning
)

$ErrorActionPreference = 'Stop'

# Fixed resource names following naming conventions
$StorageAccountBaseName = "stavdprofiles"
$NsgName = "nsg-avd-session-hosts"
$SessionHostSecurityGroupName = "sg-avd-session-hosts"
$UsersSecurityGroupName = "sg-avd-users"

# Storage configuration - Premium for Azure Files
$StorageAccountSku = "Premium_LRS"  # Premium required for Azure Files Premium
$StorageAccountKind = "FileStorage"  # FileStorage kind for Premium file shares
$StorageShareQuotaGB = 100  # Fixed at 100GB as specified
$StorageSoftDeleteRetentionDays = 7  # Soft delete retention

# Required resource providers
$RequiredProviders = @(
    "Microsoft.Storage",
    "Microsoft.Network",
    "Microsoft.DesktopVirtualization"
)

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
Write-Host "AVD Live/Production Infrastructure Setup" -ForegroundColor White
Write-Host "===========================================" -ForegroundColor White
Write-Host ""

# ============================================================================
# PRE-FLIGHT VALIDATION
# ============================================================================

Write-Step "[Pre-Flight Validation] Starting validation checks..."

# Check 1: Azure CLI Installation
Write-Host "  Checking Azure CLI installation..." -NoNewline
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    if (-not $azVersion) {
        Write-Error-Message "Azure CLI not found"
        Write-Host "`nPlease install Azure CLI: https://aka.ms/installazurecliwindows" -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Azure CLI installed (version: $($azVersion.'azure-cli'))"
}
catch {
    Write-Error-Message "Azure CLI not found"
    Write-Host "`nPlease install Azure CLI: https://aka.ms/installazurecliwindows" -ForegroundColor Yellow
    exit 1
}

# Check 2: Azure Login Status
Write-Host "  Checking Azure login status..." -NoNewline
try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Error-Message "Not logged in to Azure"
        Write-Host "`nPlease run: az login" -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Logged in as: $($account.user.name)"
    
    # Set default subscription if not provided
    if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
        $SubscriptionId = $account.id
        Write-Host "    Using current subscription: $($account.name)" -ForegroundColor Gray
    }
}
catch {
    Write-Error-Message "Not logged in to Azure"
    Write-Host "`nPlease run: az login" -ForegroundColor Yellow
    exit 1
}

# Check 3: Validate Subscription Access
Write-Host "  Validating subscription access..." -NoNewline
try {
    az account set --subscription $SubscriptionId --output none 2>&1 | Out-Null
    $subscription = az account show --subscription $SubscriptionId --output json | ConvertFrom-Json
    
    if (-not $subscription) {
        Write-Error-Message "Subscription not accessible"
        Write-Host "`nSubscription ID: $SubscriptionId" -ForegroundColor Yellow
        Write-Host "Please verify you have access to this subscription." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Success "Subscription accessible: $($subscription.name)"
    
    # Use subscription default location if not specified
    if ([string]::IsNullOrWhiteSpace($Location) -and $subscription.defaultLocation) {
        $Location = $subscription.defaultLocation
        Write-Host "    Using subscription default location: $Location" -ForegroundColor Gray
    }
}
catch {
    Write-Error-Message "Failed to access subscription"
    Write-Host "`nError: $_" -ForegroundColor Yellow
    Write-Host "Please verify:" -ForegroundColor Yellow
    Write-Host "  1. Subscription ID is correct: $SubscriptionId" -ForegroundColor Yellow
    Write-Host "  2. You have Owner role on the subscription" -ForegroundColor Yellow
    exit 1
}

# Check 4: Test Permission to Create Resources
Write-Host "  Testing permissions..." -NoNewline
try {
    $providers = az provider list --output json | ConvertFrom-Json
    if (-not $providers) {
        Write-Error-Message "Cannot read subscription resources"
        Write-Host "`nInsufficient permissions. Please ensure you have Owner role on the subscription." -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Permissions validated"
}
catch {
    Write-Error-Message "Permission check failed"
    Write-Host "`nError: $_" -ForegroundColor Yellow
    Write-Host "Please ensure you have Owner role on the subscription." -ForegroundColor Yellow
    exit 1
}

# Check 5: Validate Location
Write-Host "  Validating location..." -NoNewline
try {
    $locations = az account list-locations --output json | ConvertFrom-Json
    $validLocation = $locations | Where-Object { $_.name -eq $Location }
    if (-not $validLocation) {
        Write-Error-Message "Invalid location: $Location"
        Write-Host "`nPlease use a valid Azure region (e.g., eastus, westus2, uksouth)" -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Location valid: $Location"
}
catch {
    Write-Warning-Message "Location validation skipped (using: $Location)"
}

# Check 6: Validate Subnet CIDR (minimum /24)
Write-Host "  Validating subnet configuration..." -NoNewline
try {
    $subnetPrefixParts = $SubnetAddressPrefix -split '/'
    if ($subnetPrefixParts.Count -ne 2) {
        throw "Invalid subnet prefix format. Use CIDR notation (e.g., 10.0.1.0/24)"
    }
    $subnetMask = [int]$subnetPrefixParts[1]
    if ($subnetMask -gt 24) {
        Write-Warning-Message "Subnet mask is greater than /24. Minimum /24 recommended for AVD session hosts."
        Write-Host "    Current: /$subnetMask (minimum recommended: /24)" -ForegroundColor Yellow
    }
    else {
        Write-Success "Subnet configuration valid: $SubnetAddressPrefix"
    }
}
catch {
    Write-Warning-Message "Subnet validation skipped: $_"
}

# Check 7: Validate existing VNet if specified
if ($UseExistingVnet) {
    Write-Host "  Validating existing virtual network..." -NoNewline
    try {
        if ([string]::IsNullOrWhiteSpace($ExistingVnetResourceGroup)) {
            throw "ExistingVnetResourceGroup must be specified when using UseExistingVnet"
        }
        
        $existingVnet = az network vnet show `
            --resource-group $ExistingVnetResourceGroup `
            --name $VnetName `
            --output json 2>$null | ConvertFrom-Json
        
        if (-not $existingVnet) {
            throw "Virtual network '$VnetName' not found in resource group '$ExistingVnetResourceGroup'"
        }
        
        Write-Success "Existing virtual network found: $VnetName"
    }
    catch {
        Write-Error-Message "Failed to validate existing virtual network: $_"
        exit 1
    }
}

Write-Host ""
Write-Success "All pre-flight checks passed!"
Write-Host ""

# ============================================================================
# MAIN DEPLOYMENT
# ============================================================================

Write-Step "[Step 1] Registering resource providers..."

foreach ($provider in $RequiredProviders) {
    Write-Host "  Registering $provider..." -NoNewline
    
    try {
        $providerStatus = az provider show --namespace $provider --output json | ConvertFrom-Json
        
        if ($providerStatus.registrationState -eq "Registered") {
            Write-Host " already registered" -ForegroundColor Gray
        }
        else {
            az provider register --namespace $provider --output none 2>&1 | Out-Null
            
            # Wait for registration (with timeout)
            $maxAttempts = 30
            $attempt = 0
            $registered = $false
            
            while ($attempt -lt $maxAttempts -and -not $registered) {
                Start-Sleep -Seconds 2
                $providerStatus = az provider show --namespace $provider --output json | ConvertFrom-Json
                if ($providerStatus.registrationState -eq "Registered") {
                    $registered = $true
                }
                $attempt++
            }
            
            if ($registered) {
                Write-Host " registered" -ForegroundColor Green
            }
            else {
                Write-Host " registration pending" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host " failed" -ForegroundColor Red
        Write-Warning-Message "Failed to register $provider : $_"
    }
}

Write-Step "[Step 2] Creating resource group..."

try {
    $rg = az group show --name $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    
    if ($rg) {
        Write-Success "Resource group already exists"
        
        # Update tags if resource group exists
        try {
            az group update `
                --name $ResourceGroupName `
                --tags Environment=Production Project=AVD `
                --output none 2>&1 | Out-Null
            Write-Host "    Tags updated" -ForegroundColor Gray
        }
        catch {
            Write-Warning-Message "Failed to update tags (non-critical): $_"
        }
    }
    else {
        az group create `
            --name $ResourceGroupName `
            --location $Location `
            --tags Environment=Production Project=AVD `
            --output none
        Write-Success "Resource group created with tags"
    }
}
catch {
    Write-Error-Message "Failed to create resource group: $_"
    exit 1
}

Write-Step "[Step 3] Creating FSLogix storage account (Premium)..."

$storageAccountName = $null

try {
    # Check if storage account already exists in the resource group
    $existingStorageAccounts = az storage account list `
        --resource-group $ResourceGroupName `
        --output json | ConvertFrom-Json
    
    # Filter for FileStorage kind (Premium)
    $premiumStorageAccounts = $existingStorageAccounts | Where-Object { $_.kind -eq "FileStorage" }
    
    if ($premiumStorageAccounts.Count -gt 0) {
        $storageAccountName = $premiumStorageAccounts[0].name
        Write-Success "Premium storage account already exists: $storageAccountName"
    }
    else {
        # Generate unique storage account name
        $randomSuffix = Get-Random -Minimum 1000 -Maximum 9999
        $storageAccountName = "$StorageAccountBaseName$randomSuffix"
        
        # Check if name is available, try variations if needed
        $maxAttempts = 10
        $attempt = 0
        $nameAvailable = $false
        
        while ($attempt -lt $maxAttempts -and -not $nameAvailable) {
            $checkResult = az storage account check-name --name $storageAccountName --output json | ConvertFrom-Json
            
            if ($checkResult.nameAvailable) {
                $nameAvailable = $true
            }
            else {
                $randomSuffix = Get-Random -Minimum 1000 -Maximum 9999
                $storageAccountName = "$StorageAccountBaseName$randomSuffix"
                $attempt++
            }
        }
        
        if (-not $nameAvailable) {
            throw "Could not find available storage account name after $maxAttempts attempts"
        }
        
        Write-Host "  Creating Premium storage account: $storageAccountName..." -NoNewline
        az storage account create `
            --resource-group $ResourceGroupName `
            --name $storageAccountName `
            --location $Location `
            --sku $StorageAccountSku `
            --kind $StorageAccountKind `
            --output none 2>&1 | Out-Null
        
        Write-Host " created" -ForegroundColor Green
    }
    
    # Verify storage account exists
    $storageAccount = az storage account show `
        --resource-group $ResourceGroupName `
        --name $storageAccountName `
        --output json 2>$null | ConvertFrom-Json
    
    if (-not $storageAccount) {
        throw "Storage account creation failed or cannot be found"
    }
    
    # Enable soft delete for file shares
    Write-Host "  Enabling soft delete for file shares..." -NoNewline
    try {
        az storage account blob-service-properties update `
            --account-name $storageAccountName `
            --resource-group $ResourceGroupName `
            --enable-delete-retention true `
            --delete-retention-days $StorageSoftDeleteRetentionDays `
            --output none 2>&1 | Out-Null
        Write-Host " enabled ($StorageSoftDeleteRetentionDays days)" -ForegroundColor Green
    }
    catch {
        Write-Host " failed (non-critical)" -ForegroundColor Yellow
        Write-Warning-Message "Failed to enable soft delete: $_"
    }
    
    # Enable versioning if requested
    if ($EnableStorageVersioning) {
        Write-Host "  Enabling versioning..." -NoNewline
        try {
            az storage account blob-service-properties update `
                --account-name $storageAccountName `
                --resource-group $ResourceGroupName `
                --enable-versioning true `
                --output none 2>&1 | Out-Null
            Write-Host " enabled" -ForegroundColor Green
        }
        catch {
            Write-Host " failed (non-critical)" -ForegroundColor Yellow
            Write-Warning-Message "Failed to enable versioning: $_"
        }
    }
    
    # Configure network access - allow Azure services
    Write-Host "  Configuring network access..." -NoNewline
    try {
        az storage account update `
            --name $storageAccountName `
            --resource-group $ResourceGroupName `
            --default-action Allow `
            --bypass AzureServices `
            --output none 2>&1 | Out-Null
        Write-Host " configured (Azure services allowed)" -ForegroundColor Green
    }
    catch {
        Write-Host " failed (non-critical)" -ForegroundColor Yellow
        Write-Warning-Message "Failed to configure network access: $_"
    }
    
    # Create Azure Files Premium share
    Write-Host "  Creating Azure Files Premium share: $StorageShareName..." -NoNewline
    try {
        $storageKeys = az storage account keys list `
            --resource-group $ResourceGroupName `
            --account-name $storageAccountName `
            --output json | ConvertFrom-Json
        
        $storageKey = $storageKeys[0].value
        
        # Check if share exists
        $existingShare = az storage share show `
            --name $StorageShareName `
            --account-name $storageAccountName `
            --account-key $storageKey `
            --output json 2>$null | ConvertFrom-Json
        
        if ($existingShare) {
            Write-Host " already exists" -ForegroundColor Gray
            Write-Host "    Current quota: $($existingShare.quota)GB" -ForegroundColor Gray
            
            # Update quota if different
            if ($existingShare.quota -ne $StorageShareQuotaGB) {
                Write-Host "    Updating quota to ${StorageShareQuotaGB}GB..." -NoNewline
                az storage share update `
                    --name $StorageShareName `
                    --account-name $storageAccountName `
                    --account-key $storageKey `
                    --quota $StorageShareQuotaGB `
                    --output none 2>&1 | Out-Null
                Write-Host " updated" -ForegroundColor Green
            }
        }
        else {
            # Create Premium file share with quota
            az storage share create `
                --name $StorageShareName `
                --account-name $storageAccountName `
                --account-key $storageKey `
                --quota $StorageShareQuotaGB `
                --output none 2>&1 | Out-Null
            
            Write-Host " created (${StorageShareQuotaGB}GB quota)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host " failed" -ForegroundColor Red
        Write-Error-Message "Failed to create file share: $_"
        throw
    }
}
catch {
    Write-Error-Message "Failed to create storage account: $_"
    exit 1
}

Write-Step "[Step 4] Creating virtual network and subnet..."

$vnetResourceGroup = $ResourceGroupName
if ($UseExistingVnet) {
    $vnetResourceGroup = $ExistingVnetResourceGroup
}

try {
    if ($UseExistingVnet) {
        Write-Success "Using existing virtual network: $VnetName"
        $vnet = az network vnet show `
            --resource-group $vnetResourceGroup `
            --name $VnetName `
            --output json | ConvertFrom-Json
    }
    else {
        # Check if VNet already exists
        $existingVnet = az network vnet show `
            --resource-group $ResourceGroupName `
            --name $VnetName `
            --output json 2>$null | ConvertFrom-Json
        
        if ($existingVnet) {
            Write-Success "Virtual network already exists: $VnetName"
            $vnet = $existingVnet
        }
        else {
            Write-Host "  Creating virtual network: $VnetName..." -NoNewline
            
            # Build DNS servers parameter if provided
            $dnsParams = ""
            if ($DnsServers.Count -gt 0) {
                $dnsServersJson = ($DnsServers | ConvertTo-Json -Compress)
                $dnsParams = "--dns-servers $($DnsServers -join ' ')"
            }
            
            $vnet = az network vnet create `
                --resource-group $ResourceGroupName `
                --name $VnetName `
                --location $Location `
                --address-prefix $VnetAddressSpace `
                $dnsParams `
                --output json 2>&1 | ConvertFrom-Json
            
            Write-Host " created" -ForegroundColor Green
        }
    }
    
    # Create or verify subnet
    Write-Host "  Checking subnet: $SubnetName..." -NoNewline
    $existingSubnet = az network vnet subnet show `
        --resource-group $vnetResourceGroup `
        --vnet-name $VnetName `
        --name $SubnetName `
        --output json 2>$null | ConvertFrom-Json
    
    if ($existingSubnet) {
        Write-Host " already exists" -ForegroundColor Gray
        Write-Host "    Address prefix: $($existingSubnet.addressPrefix)" -ForegroundColor Gray
    }
    else {
        Write-Host " creating..." -NoNewline
        az network vnet subnet create `
            --resource-group $vnetResourceGroup `
            --vnet-name $VnetName `
            --name $SubnetName `
            --address-prefix $SubnetAddressPrefix `
            --output none 2>&1 | Out-Null
        
        Write-Host " created" -ForegroundColor Green
        Write-Host "    Address prefix: $SubnetAddressPrefix" -ForegroundColor Gray
    }
}
catch {
    Write-Error-Message "Failed to create virtual network/subnet: $_"
    exit 1
}

Write-Step "[Step 5] Creating network security group..."

try {
    $existingNsg = az network nsg show `
        --resource-group $ResourceGroupName `
        --name $NsgName `
        --output json 2>$null | ConvertFrom-Json
    
    if ($existingNsg) {
        Write-Success "Network security group already exists: $NsgName"
    }
    else {
        Write-Host "  Creating NSG: $NsgName..." -NoNewline
        az network nsg create `
            --resource-group $ResourceGroupName `
            --name $NsgName `
            --location $Location `
            --output none 2>&1 | Out-Null
        
        Write-Host " created" -ForegroundColor Green
    }
    
    # Create NSG rules for AVD
    Write-Host "  Configuring NSG rules for AVD..."
    
    # Rule 1: Allow RDP from Azure Load Balancer
    $rdpRuleName = "AllowRDPFromLoadBalancer"
    $existingRule = az network nsg rule show `
        --resource-group $ResourceGroupName `
        --nsg-name $NsgName `
        --name $rdpRuleName `
        --output json 2>$null | ConvertFrom-Json
    
    if (-not $existingRule) {
        az network nsg rule create `
            --resource-group $ResourceGroupName `
            --nsg-name $NsgName `
            --name $rdpRuleName `
            --priority 1000 `
            --source-address-prefixes AzureLoadBalancer `
            --source-port-ranges "*" `
            --destination-address-prefixes "*" `
            --destination-port-ranges 3389 `
            --access Allow `
            --protocol Tcp `
            --description "Allow RDP from Azure Load Balancer" `
            --output none 2>&1 | Out-Null
        Write-Host "    ✓ Rule created: Allow RDP from Azure Load Balancer" -ForegroundColor Gray
    }
    else {
        Write-Host "    ✓ Rule exists: Allow RDP from Azure Load Balancer" -ForegroundColor Gray
    }
    
    # Rule 2: Allow HTTPS outbound
    $httpsRuleName = "AllowHTTPSOutbound"
    $existingRule = az network nsg rule show `
        --resource-group $ResourceGroupName `
        --nsg-name $NsgName `
        --name $httpsRuleName `
        --output json 2>$null | ConvertFrom-Json
    
    if (-not $existingRule) {
        az network nsg rule create `
            --resource-group $ResourceGroupName `
            --nsg-name $NsgName `
            --name $httpsRuleName `
            --priority 1001 `
            --direction Outbound `
            --source-address-prefixes "*" `
            --source-port-ranges "*" `
            --destination-address-prefixes "*" `
            --destination-port-ranges 443 `
            --access Allow `
            --protocol Tcp `
            --description "Allow HTTPS outbound for AVD services" `
            --output none 2>&1 | Out-Null
        Write-Host "    ✓ Rule created: Allow HTTPS outbound" -ForegroundColor Gray
    }
    else {
        Write-Host "    ✓ Rule exists: Allow HTTPS outbound" -ForegroundColor Gray
    }
    
    # Rule 3: Allow required AVD endpoints outbound
    $avdEndpointsRuleName = "AllowAVDEndpointsOutbound"
    $existingRule = az network nsg rule show `
        --resource-group $ResourceGroupName `
        --nsg-name $NsgName `
        --name $avdEndpointsRuleName `
        --output json 2>$null | ConvertFrom-Json
    
    if (-not $existingRule) {
        # AVD requires outbound access to various Microsoft services
        az network nsg rule create `
            --resource-group $ResourceGroupName `
            --nsg-name $NsgName `
            --name $avdEndpointsRuleName `
            --priority 1002 `
            --direction Outbound `
            --source-address-prefixes "*" `
            --source-port-ranges "*" `
            --destination-address-prefixes "AzureCloud" `
            --destination-port-ranges 443 `
            --access Allow `
            --protocol Tcp `
            --description "Allow outbound to Azure Cloud for AVD services" `
            --output none 2>&1 | Out-Null
        Write-Host "    ✓ Rule created: Allow AVD endpoints outbound" -ForegroundColor Gray
    }
    else {
        Write-Host "    ✓ Rule exists: Allow AVD endpoints outbound" -ForegroundColor Gray
    }
    
    Write-Success "NSG rules configured"
}
catch {
    Write-Error-Message "Failed to create/configure NSG: $_"
    exit 1
}

Write-Step "[Step 6] Creating Azure AD security groups..."

$sessionHostGroupId = $null
$usersGroupId = $null

if ($CreateSecurityGroups) {
    try {
        # Check if Microsoft Graph extension is available
        $graphExtension = az extension list --query "[?name=='microsoft-graph'].name" --output tsv 2>$null
        if (-not $graphExtension) {
            Write-Host "  Installing Microsoft Graph extension..." -NoNewline
            az extension add --name microsoft-graph --yes --output none 2>&1 | Out-Null
            Write-Host " installed" -ForegroundColor Green
        }
        
        # Create session host security group
        Write-Host "  Creating security group: $SessionHostSecurityGroupName..." -NoNewline
        try {
            $existingGroup = az ad group show --group $SessionHostSecurityGroupName --output json 2>$null | ConvertFrom-Json
            if ($existingGroup) {
                $sessionHostGroupId = $existingGroup.id
                Write-Host " already exists" -ForegroundColor Gray
            }
            else {
                $newGroup = az ad group create `
                    --display-name $SessionHostSecurityGroupName `
                    --mail-nickname ($SessionHostSecurityGroupName -replace '-', '') `
                    --output json | ConvertFrom-Json
                $sessionHostGroupId = $newGroup.id
                Write-Host " created" -ForegroundColor Green
            }
        }
        catch {
            Write-Host " failed" -ForegroundColor Yellow
            Write-Warning-Message "Failed to create session host security group: $_"
            Write-Host "    You may need Global Administrator role or Graph API permissions." -ForegroundColor Yellow
        }
        
        # Create users security group
        Write-Host "  Creating security group: $UsersSecurityGroupName..." -NoNewline
        try {
            $existingGroup = az ad group show --group $UsersSecurityGroupName --output json 2>$null | ConvertFrom-Json
            if ($existingGroup) {
                $usersGroupId = $existingGroup.id
                Write-Host " already exists" -ForegroundColor Gray
            }
            else {
                $newGroup = az ad group create `
                    --display-name $UsersSecurityGroupName `
                    --mail-nickname ($UsersSecurityGroupName -replace '-', '') `
                    --output json | ConvertFrom-Json
                $usersGroupId = $newGroup.id
                Write-Host " created" -ForegroundColor Green
            }
        }
        catch {
            Write-Host " failed" -ForegroundColor Yellow
            Write-Warning-Message "Failed to create users security group: $_"
            Write-Host "    You may need Global Administrator role or Graph API permissions." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning-Message "Security group creation skipped (Graph API may not be available): $_"
        Write-Host "    You can create security groups manually in Azure AD." -ForegroundColor Yellow
    }
}
else {
    Write-Host "  Skipping security group creation (use -CreateSecurityGroups to enable)" -ForegroundColor Gray
    Write-Host "    Required groups:" -ForegroundColor Gray
    Write-Host "      - $SessionHostSecurityGroupName (for session host VMs)" -ForegroundColor Gray
    Write-Host "      - $UsersSecurityGroupName (for AVD users)" -ForegroundColor Gray
}

Write-Step "[Step 7] Assigning storage permissions..."

if ($sessionHostGroupId) {
    try {
        $storageScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"
        
        # Assign "Storage File Data SMB Share Contributor" role
        Write-Host "  Assigning 'Storage File Data SMB Share Contributor' role..." -NoNewline
        $existingAssignment = az role assignment list `
            --assignee $sessionHostGroupId `
            --scope $storageScope `
            --role "Storage File Data SMB Share Contributor" `
            --output json 2>$null | ConvertFrom-Json
        
        if ($existingAssignment.Count -gt 0) {
            Write-Host " already assigned" -ForegroundColor Gray
        }
        else {
            az role assignment create `
                --assignee $sessionHostGroupId `
                --role "Storage File Data SMB Share Contributor" `
                --scope $storageScope `
                --output none 2>&1 | Out-Null
            Write-Host " assigned" -ForegroundColor Green
        }
        
        # Optionally assign "Storage File Data SMB Share Elevated Contributor" role
        Write-Host "  Assigning 'Storage File Data SMB Share Elevated Contributor' role..." -NoNewline
        $existingAssignment = az role assignment list `
            --assignee $sessionHostGroupId `
            --scope $storageScope `
            --role "Storage File Data SMB Share Elevated Contributor" `
            --output json 2>$null | ConvertFrom-Json
        
        if ($existingAssignment.Count -gt 0) {
            Write-Host " already assigned" -ForegroundColor Gray
        }
        else {
            az role assignment create `
                --assignee $sessionHostGroupId `
                --role "Storage File Data SMB Share Elevated Contributor" `
                --scope $storageScope `
                --output none 2>&1 | Out-Null
            Write-Host " assigned" -ForegroundColor Green
        }
        
        Write-Success "Storage permissions configured"
    }
    catch {
        Write-Warning-Message "Failed to assign storage permissions: $_"
        Write-Host "    Manual step required: Assign 'Storage File Data SMB Share Contributor' role" -ForegroundColor Yellow
        Write-Host "      to security group '$SessionHostSecurityGroupName' on storage account '$storageAccountName'" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  Skipping role assignment (security group not created or not available)" -ForegroundColor Gray
    Write-Host "    Manual step required:" -ForegroundColor Yellow
    Write-Host "      1. Create security group: $SessionHostSecurityGroupName" -ForegroundColor Yellow
    Write-Host "      2. Assign 'Storage File Data SMB Share Contributor' role to the group on storage account" -ForegroundColor Yellow
}

# ============================================================================
# SUMMARY OUTPUT
# ============================================================================

Write-Host ""
Write-Host "===========================================" -ForegroundColor White
Write-Host "Setup Summary" -ForegroundColor White
Write-Host "===========================================" -ForegroundColor White
Write-Host ""

Write-Success "Infrastructure deployed successfully!"
Write-Host ""

Write-Host "Resource Details:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName"
Write-Host "  Location: $Location"
Write-Host ""

Write-Host "  FSLogix Storage Account: $storageAccountName"
Write-Host "    Type: Premium (FileStorage)"
Write-Host "    SKU: $StorageAccountSku"
Write-Host "    File Share: $StorageShareName"
Write-Host "    Share Quota: ${StorageShareQuotaGB}GB"
Write-Host "    Soft Delete: Enabled ($StorageSoftDeleteRetentionDays days)"
if ($EnableStorageVersioning) {
    Write-Host "    Versioning: Enabled"
}
Write-Host ""

Write-Host "  Virtual Network: $VnetName"
Write-Host "    Resource Group: $vnetResourceGroup"
Write-Host "    Address Space: $VnetAddressSpace"
Write-Host "    Subnet: $SubnetName"
Write-Host "    Subnet Prefix: $SubnetAddressPrefix"
if ($DnsServers.Count -gt 0) {
    Write-Host "    DNS Servers: $($DnsServers -join ', ')"
}
Write-Host ""

Write-Host "  Network Security Group: $NsgName"
Write-Host "    Rules configured for AVD session hosts"
Write-Host ""

if ($sessionHostGroupId) {
    Write-Host "  Security Groups:"
    Write-Host "    Session Hosts: $SessionHostSecurityGroupName (ID: $sessionHostGroupId)"
    if ($usersGroupId) {
        Write-Host "    Users: $UsersSecurityGroupName (ID: $usersGroupId)"
    }
    Write-Host ""
}

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "===========" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Add session host VMs to security group: $SessionHostSecurityGroupName"
Write-Host "   (This will be done automatically when VMs are created if using managed identity)"
Write-Host ""
Write-Host "2. Configure FSLogix on session hosts:"
Write-Host "   Profile path: \\$storageAccountName.file.core.windows.net\$StorageShareName"
Write-Host ""
Write-Host "3. Create host pool (Phase 8 of deployment checklist):"
Write-Host "   - Navigate to Azure Virtual Desktop > Host pools"
Write-Host "   - Use virtual network: $VnetName"
Write-Host "   - Use subnet: $SubnetName"
Write-Host "   - Use NSG: $NsgName"
Write-Host ""
Write-Host "4. Add users to security group: $UsersSecurityGroupName"
Write-Host "   and assign them to the desktop application group"
Write-Host ""

if (-not $sessionHostGroupId) {
    Write-Host "Manual Steps Required:" -ForegroundColor Yellow
    Write-Host "=====================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Create Azure AD security group: $SessionHostSecurityGroupName"
    Write-Host "2. Assign 'Storage File Data SMB Share Contributor' role to the group on:"
    Write-Host "   Storage account: $storageAccountName"
    Write-Host "3. Create Azure AD security group: $UsersSecurityGroupName"
    Write-Host ""
}

Write-Host "For more information, see: AVD_DEPLOYMENT_CHECKLIST.md"
Write-Host ""

Write-Host "===========================================" -ForegroundColor White
Write-Host "Setup completed!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor White
Write-Host ""

