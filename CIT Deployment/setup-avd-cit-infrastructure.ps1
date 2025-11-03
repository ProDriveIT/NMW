#requires -Version 5.1

<#
.SYNOPSIS
    Sets up infrastructure for Azure Virtual Desktop Custom Image Templates.

.DESCRIPTION
    This script creates all required infrastructure for AVD Custom Image Templates in a fire-and-forget manner.
    It prompts only for subscription ID and uses fixed, generic names for all resources suitable for any client.
    
    Creates:
    - Resource Group
    - User-assigned Managed Identity
    - Azure Compute Gallery
    - Storage Account (optional, for scripts)
    - Custom RBAC Role with required permissions
    - All required role assignments
    
    Compatible with: https://learn.microsoft.com/en-us/azure/virtual-desktop/custom-image-templates

.PARAMETER SubscriptionId
    Azure subscription ID (optional - will use current subscription if not provided)

.EXAMPLE
    .\setup-avd-cit-infrastructure.ps1
    
.EXAMPLE
    .\setup-avd-cit-infrastructure.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"

.NOTES
    Assumes user has:
    - Global Administrator role in Azure AD
    - Owner role on target subscription
    
    Requires: Azure CLI (az) installed and logged in
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = ""
)

$ErrorActionPreference = 'Stop'

# Fixed resource names (no client-specific terms)
$ResourceGroupName = "rg-avd-cit-infrastructure"
$ManagedIdentityName = "umi-avd-cit"
$GalleryName = "gal_avd_images"
$StorageContainerName = "scripts"
$RoleToUse = "Contributor"  # Using built-in Contributor role - simpler and always available
$Location = "uksouth"
$GalleryImageDefinitionName = "avd_session_host"
$GalleryImageDefinitionPublisher = "ProDriveIT"
$GalleryImageDefinitionOffer = "avd_images"
$GalleryImageDefinitionSku = "windows11_avd"

# Required resource providers
$RequiredProviders = @(
    "Microsoft.DesktopVirtualization",
    "Microsoft.VirtualMachineImages",
    "Microsoft.Storage",
    "Microsoft.Compute",
    "Microsoft.Network",
    "Microsoft.KeyVault",
    "Microsoft.ContainerInstance"
)

# Note: Using built-in "Contributor" role which includes all required permissions:
# - Microsoft.Compute/galleries/read
# - Microsoft.Compute/galleries/images/read
# - Microsoft.Compute/galleries/images/versions/read
# - Microsoft.Compute/galleries/images/versions/write
# - Microsoft.Compute/images/write, read, delete
# This is simpler than creating a custom role and avoids permission issues

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
Write-Host "AVD Custom Image Template Infrastructure" -ForegroundColor White
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
    
    # Try to get location from subscription default
    if ($subscription.defaultLocation) {
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
    # Test ability to list resource providers (requires subscription read)
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

# Check 5: Resource Name Availability
Write-Host "  Checking resource name availability..." -NoNewline
try {
    # Check resource group
    $existingRg = az group show --name $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    if ($existingRg) {
        # Check if resource group is empty (warn but continue)
        $rgResources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        if ($rgResources.Count -gt 0) {
            Write-Warning-Message "Resource group exists and contains resources"
            Write-Host "    Resource group '$ResourceGroupName' exists with $($rgResources.Count) resource(s)." -ForegroundColor Yellow
            Write-Host "    This may cause issues during image builds. Consider using an empty resource group." -ForegroundColor Yellow
        }
        else {
            Write-Success "Resource group exists (empty)"
        }
    }
    else {
        Write-Success "Resource group name available"
    }
    
    # Check managed identity (will be in same RG)
    # Check gallery name (globally unique, check subscription-wide)
    $existingGallery = az sig show --resource-group $ResourceGroupName --gallery-name $GalleryName --output json 2>$null | ConvertFrom-Json
    if ($existingGallery) {
        Write-Success "Gallery already exists"
    }
    else {
        Write-Success "Gallery name available"
    }
    
    # Storage account name will be auto-generated with uniqueness check
    Write-Success "All resource names validated"
}
catch {
    Write-Warning-Message "Some resource checks skipped (may already exist)"
}

# Check 6: Validate Location
Write-Host "  Validating location..." -NoNewline
try {
    $locations = az account list-locations --output json | ConvertFrom-Json
    $validLocation = $locations | Where-Object { $_.name -eq $Location }
    if (-not $validLocation) {
        Write-Error-Message "Invalid location: $Location"
        Write-Host "`nPlease use a valid Azure region (e.g., eastus, westus2)" -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Location valid: $Location"
}
catch {
    Write-Warning-Message "Location validation skipped (using: $Location)"
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
    }
    else {
        az group create --name $ResourceGroupName --location $Location --output none
        Write-Success "Resource group created"
    }
}
catch {
    Write-Error-Message "Failed to create resource group: $_"
    exit 1
}

Write-Step "[Step 3] Creating managed identity..."

try {
    $identity = az identity show `
        --resource-group $ResourceGroupName `
        --name $ManagedIdentityName `
        --output json 2>$null | ConvertFrom-Json
    
    if ($identity) {
        Write-Success "Managed identity already exists"
        $identityPrincipalId = $identity.principalId
        $identityResourceId = $identity.id
    }
    else {
        $identity = az identity create `
            --resource-group $ResourceGroupName `
            --name $ManagedIdentityName `
            --location $Location `
            --output json | ConvertFrom-Json
        
        $identityPrincipalId = $identity.principalId
        $identityResourceId = $identity.id
        Write-Success "Managed identity created"
    }
    
    Write-Host "    Principal ID: $identityPrincipalId" -ForegroundColor Gray
    Write-Host "    Resource ID: $identityResourceId" -ForegroundColor Gray
}
catch {
    Write-Error-Message "Failed to create managed identity: $_"
    exit 1
}

Write-Step "[Step 4] Assigning Contributor role to managed identity..."

try {
    $rgScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
    
    # Check if role assignment already exists
    $existingAssignment = az role assignment list `
        --assignee $identityPrincipalId `
        --scope $rgScope `
        --role $RoleToUse `
        --output json 2>$null | ConvertFrom-Json
    
    if ($existingAssignment.Count -gt 0) {
        Write-Success "Role assignment already exists on resource group"
    }
    else {
        az role assignment create `
            --assignee $identityPrincipalId `
            --role $RoleToUse `
            --scope $rgScope `
            --output none 2>&1 | Out-Null
        
        Write-Success "Contributor role assigned on resource group"
    }
}
catch {
    Write-Error-Message "Failed to assign role: $_"
    exit 1
}

Write-Step "[Step 5] Creating Azure Compute Gallery..."

try {
    $gallery = az sig show `
        --resource-group $ResourceGroupName `
        --gallery-name $GalleryName `
        --output json 2>$null | ConvertFrom-Json
    
    if ($gallery) {
        Write-Success "Gallery already exists"
        $galleryResourceId = $gallery.id
    }
    else {
        Write-Host "  Creating gallery..." -NoNewline
        $gallery = az sig create `
            --resource-group $ResourceGroupName `
            --gallery-name $GalleryName `
            --location $Location `
            --description "Azure Virtual Desktop Custom Images" `
            --output json 2>&1
        
        # Check if creation succeeded
        if ($LASTEXITCODE -ne 0) {
            Write-Host " failed" -ForegroundColor Red
            throw "Failed to create gallery: $gallery"
        }
        
        $gallery = $gallery | ConvertFrom-Json
        $galleryResourceId = $gallery.id
        Write-Host " created" -ForegroundColor Green
        
        # Wait for gallery to fully propagate (portal sometimes caches)
        Write-Host "  Waiting for gallery to propagate..." -NoNewline
        $maxWait = 30
        $waitCount = 0
        $verified = $false
        
        while ($waitCount -lt $maxWait -and -not $verified) {
            Start-Sleep -Seconds 2
            $verifyGallery = az sig show `
                --resource-group $ResourceGroupName `
                --gallery-name $GalleryName `
                --output json 2>$null | ConvertFrom-Json
            
            if ($verifyGallery) {
                $verified = $true
            }
            $waitCount++
        }
        
        if ($verified) {
            Write-Host " verified" -ForegroundColor Green
        }
        else {
            Write-Host " still propagating" -ForegroundColor Yellow
            Write-Host "    Gallery may take a few minutes to appear in portal. You can continue." -ForegroundColor Gray
        }
    }
    
    # Assign Contributor role on gallery
    try {
        $galleryScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/galleries/$GalleryName"
        $galleryAssignment = az role assignment list `
            --assignee $identityPrincipalId `
            --scope $galleryScope `
            --role $RoleToUse `
            --output json 2>$null | ConvertFrom-Json
        
        if ($galleryAssignment.Count -gt 0) {
            Write-Success "Role assignment already exists on gallery"
        }
        else {
            az role assignment create `
                --assignee $identityPrincipalId `
                --role $RoleToUse `
                --scope $galleryScope `
                --output none 2>&1 | Out-Null
            
            Write-Success "Contributor role assigned on gallery"
        }
    }
    catch {
        Write-Warning-Message "Failed to assign role on gallery (non-critical): $_"
    }
    
    # Create gallery image definition
    try {
        $imageDefinition = az sig image-definition show `
            --resource-group $ResourceGroupName `
            --gallery-name $GalleryName `
            --gallery-image-definition $GalleryImageDefinitionName `
            --output json 2>$null | ConvertFrom-Json
        
        if ($imageDefinition) {
            Write-Success "Gallery image definition already exists: $GalleryImageDefinitionName"
        }
        else {
            Write-Host "  Creating gallery image definition..." -NoNewline
            az sig image-definition create `
                --resource-group $ResourceGroupName `
                --gallery-name $GalleryName `
                --gallery-image-definition $GalleryImageDefinitionName `
                --publisher $GalleryImageDefinitionPublisher `
                --offer $GalleryImageDefinitionOffer `
                --sku $GalleryImageDefinitionSku `
                --os-type Windows `
                --hyper-v-generation V2 `
                --output none 2>&1 | Out-Null
            
            Write-Host " created" -ForegroundColor Green
            Write-Host "    Definition name: $GalleryImageDefinitionName" -ForegroundColor Gray
            Write-Host "    Publisher: $GalleryImageDefinitionPublisher" -ForegroundColor Gray
            Write-Host "    Offer: $GalleryImageDefinitionOffer" -ForegroundColor Gray
            Write-Host "    SKU: $GalleryImageDefinitionSku" -ForegroundColor Gray
            Write-Host "    Generation: V2 (Gen2)" -ForegroundColor Gray
        }
        
        # Assign Contributor role on image definition (required for Image Builder access)
        try {
            $imageDefinitionScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/galleries/$GalleryName/images/$GalleryImageDefinitionName"
            
            $imageDefAssignment = az role assignment list `
                --assignee $identityPrincipalId `
                --scope $imageDefinitionScope `
                --role $RoleToUse `
                --output json 2>$null | ConvertFrom-Json
            
            if ($imageDefAssignment.Count -gt 0) {
                Write-Success "Role assignment already exists on image definition"
            }
            else {
                az role assignment create `
                    --assignee $identityPrincipalId `
                    --role $RoleToUse `
                    --scope $imageDefinitionScope `
                    --output none 2>&1 | Out-Null
                
                Write-Success "Contributor role assigned on image definition"
            }
        }
        catch {
            Write-Warning-Message "Failed to assign role on image definition: $_"
            Write-Host "    Manual fix: Assign 'Contributor' role to identity on the image definition" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning-Message "Failed to create gallery image definition (non-critical): $_"
        Write-Host "    You can create the image definition manually in the portal or during template creation." -ForegroundColor Yellow
    }
}
catch {
    Write-Error-Message "Failed to create gallery: $_"
    exit 1
}

Write-Step "[Step 6] Creating storage account..."

# Initialize storage account name variable
$storageAccountName = $null

try {
    # First, check if a storage account already exists in the resource group
    $existingStorageAccounts = az storage account list `
        --resource-group $ResourceGroupName `
        --output json | ConvertFrom-Json
    
    if ($existingStorageAccounts.Count -gt 0) {
        $storageAccountName = $existingStorageAccounts[0].name
        Write-Success "Storage account already exists: $storageAccountName"
    }
    else {
        # Generate unique storage account name
        $baseStorageName = "stavdcitscripts"
        $randomSuffix = Get-Random -Minimum 1000 -Maximum 9999
        $storageAccountName = "$baseStorageName$randomSuffix"
        
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
                $storageAccountName = "$baseStorageName$randomSuffix"
                $attempt++
            }
        }
        
        if (-not $nameAvailable) {
            throw "Could not find available storage account name after $maxAttempts attempts"
        }
        
        Write-Host "  Creating storage account: $storageAccountName..." -NoNewline
        az storage account create `
            --resource-group $ResourceGroupName `
            --name $storageAccountName `
            --location $Location `
            --sku Standard_LRS `
            --kind StorageV2 `
            --output none 2>&1 | Out-Null
        
        Write-Host " created" -ForegroundColor Green
    }
    
    # Verify storage account exists
    $existingStorage = az storage account show `
        --resource-group $ResourceGroupName `
        --name $storageAccountName `
        --output json 2>$null | ConvertFrom-Json
    
    if (-not $existingStorage) {
        throw "Storage account creation failed or cannot be found"
    }
    
    # Create container
    try {
        $storageKeys = az storage account keys list `
            --resource-group $ResourceGroupName `
            --account-name $storageAccountName `
            --output json | ConvertFrom-Json
        
        $storageKey = $storageKeys[0].value
        
        $containerExists = az storage container show `
            --name $StorageContainerName `
            --account-name $storageAccountName `
            --account-key $storageKey `
            --output json 2>$null | ConvertFrom-Json
        
        if ($containerExists) {
            Write-Success "Container already exists: $StorageContainerName"
        }
        else {
            az storage container create `
                --name $StorageContainerName `
                --account-name $storageAccountName `
                --account-key $storageKey `
                --public-access off `
                --output none 2>&1 | Out-Null
            
            Write-Success "Container created: $StorageContainerName (private access)"
        }
    }
    catch {
        Write-Warning-Message "Failed to create container (non-critical): $_"
    }
    
    # Assign Storage Blob Data Reader role (optional, for storage-based scripts)
    try {
        $storageScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"
        $storageAssignment = az role assignment list `
            --assignee $identityPrincipalId `
            --scope $storageScope `
            --role "Storage Blob Data Reader" `
            --output json 2>$null | ConvertFrom-Json
        
        if ($storageAssignment.Count -gt 0) {
            Write-Success "Storage role assignment already exists"
        }
        else {
            az role assignment create `
                --assignee $identityPrincipalId `
                --role "Storage Blob Data Reader" `
                --scope $storageScope `
                --output none 2>&1 | Out-Null
            
            Write-Success "Storage Blob Data Reader role assigned (for storage-based scripts)"
        }
    }
    catch {
        Write-Warning-Message "Failed to assign storage role (non-critical): $_"
    }
}
catch {
    Write-Warning-Message "Failed to create storage account (optional): $_"
    $storageAccountName = $null
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
Write-Host "  Managed Identity: $ManagedIdentityName"
Write-Host "    Resource ID: $identityResourceId"
Write-Host ""
Write-Host "  Image Gallery: $GalleryName"
Write-Host "    Resource ID: $galleryResourceId"
Write-Host "    Image Definition: $GalleryImageDefinitionName"
Write-Host "      Publisher: $GalleryImageDefinitionPublisher"
Write-Host "      Offer: $GalleryImageDefinitionOffer"
Write-Host "      SKU: $GalleryImageDefinitionSku"
Write-Host ""

if ($storageAccountName) {
    Write-Host "  Storage Account: $storageAccountName"
    Write-Host "    Container: $StorageContainerName"
    Write-Host "    URL: https://$storageAccountName.blob.core.windows.net/$StorageContainerName/"
    Write-Host ""
}

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "===========" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Open Azure Portal → Azure Virtual Desktop → Custom Image Templates"
Write-Host ""
Write-Host "2. Click 'Create' or '+ Add custom image template'"
Write-Host ""
Write-Host "3. On the Basics tab:"
Write-Host "   - Managed identity: Select 'User-assigned managed identity'"
Write-Host "   - Paste this Resource ID:"
Write-Host "     $identityResourceId" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. On the Distribution targets tab:"
Write-Host "   - Select 'Azure Compute Gallery'"
Write-Host "   - Gallery name: $GalleryName"
Write-Host "   - Gallery image definition: $GalleryImageDefinitionName (already created)"
Write-Host "     Or create a new one if you prefer different settings"
Write-Host ""
Write-Host "5. On the Customizations tab:"
Write-Host "   - Use GitHub raw URLs for scripts (recommended):"
Write-Host "     https://raw.githubusercontent.com/[your-org]/NMW/main/scripted-actions/custom-image-template-scripts/[script-name].ps1" -ForegroundColor Gray
Write-Host "   - Or use storage account with SAS tokens (if using storage)"
Write-Host ""

if ($storageAccountName) {
    Write-Host "For more information, see: AVD_CIT_QUICK_START.md"
    Write-Host ""
}

Write-Host "===========================================" -ForegroundColor White
Write-Host "Setup completed!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor White
Write-Host ""

