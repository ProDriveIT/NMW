#description: Sets up Azure Image Builder infrastructure (Resource Group, Managed Identity, Permissions) for automated golden image builds
#tags: Nerdio, Preview, Azure Image Builder, Custom Image Templates

<#
.SYNOPSIS
    Sets up Azure Image Builder infrastructure for automated golden image creation

.DESCRIPTION
    This script automates the setup of Azure Image Builder infrastructure, including:
    - Resource Group creation for image building
    - User-assigned managed identity creation
    - Resource provider registration
    - Role assignments for the managed identity
    - Optional storage account for script storage
    
    This enables fully automated golden image builds using Custom Image Template Scripts
    without requiring manual VM access.

.PARAMETER SubscriptionId
    Azure subscription ID where resources will be created

.PARAMETER ResourceGroupName
    Name of the resource group for image building infrastructure

.PARAMETER Location
    Azure region for resources (e.g., 'eastus', 'westus2')

.PARAMETER IdentityName
    Name for the user-assigned managed identity (default: 'umi-avd-image-builder')

.PARAMETER CreateStorageAccount
    Create a storage account for storing build scripts (default: $true)

.PARAMETER StorageAccountName
    Name for the storage account (auto-generated if not specified)

.PARAMETER ComputeGalleryResourceGroup
    Resource group containing Azure Compute Gallery (if using Gallery distribution)

.PARAMETER ComputeGalleryName
    Name of Azure Compute Gallery (if using Gallery distribution)

.EXAMPLE
    .\Setup-AzureImageBuilderInfrastructure.ps1 `
        -SubscriptionId "12345678-1234-1234-1234-123456789012" `
        -ResourceGroupName "rg-avd-image-builder" `
        -Location "eastus"

.NOTES
    Author: Generated for Nerdio Manager for WVD
    Requires: Az PowerShell module
    Requires: Contributor or Owner role on subscription
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [string]$IdentityName = "umi-avd-image-builder",
    
    [Parameter(Mandatory = $false)]
    [bool]$CreateStorageAccount = $true,
    
    [Parameter(Mandatory = $false)]
    [string]$StorageAccountName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ComputeGalleryResourceGroup = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ComputeGalleryName = ""
)

$ErrorActionPreference = 'Stop'

Write-Output "========================================="
Write-Output "Azure Image Builder Infrastructure Setup"
Write-Output "========================================="
Write-Output ""

# Step 1: Set Subscription Context
Write-Output "[Step 1/7] Setting subscription context..."
try {
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    $context = Get-AzContext
    Write-Output "✓ Connected to subscription: $($context.Subscription.Name)"
    Write-Output "  Subscription ID: $($context.Subscription.Id)"
}
catch {
    Write-Error "Failed to set subscription context: $_"
    exit 1
}

# Step 2: Register Resource Providers
Write-Output ""
Write-Output "[Step 2/7] Registering required resource providers..."
$providers = @(
    "Microsoft.VirtualMachineImages",
    "Microsoft.Storage",
    "Microsoft.Compute",
    "Microsoft.KeyVault",
    "Microsoft.Network"
)

foreach ($provider in $providers) {
    Write-Output "  Registering $provider..."
    $registration = Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue
    
    # Wait for registration to complete
    $maxAttempts = 10
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
        $state = Get-AzResourceProvider -ProviderNamespace $provider | 
            Select-Object -ExpandProperty RegistrationState -First 1
        if ($state -eq "Registered") {
            Write-Output "  ✓ $provider is registered"
            break
        }
        Start-Sleep -Seconds 5
        $attempt++
    }
    
    if ($attempt -eq $maxAttempts) {
        Write-Warning "  ⚠ $provider registration still pending (may need more time)"
    }
}

# Step 3: Create Resource Group
Write-Output ""
Write-Output "[Step 3/7] Creating resource group..."
try {
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if ($rg) {
        Write-Output "✓ Resource group '$ResourceGroupName' already exists"
    }
    else {
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Output "✓ Resource group '$ResourceGroupName' created in $Location"
    }
}
catch {
    Write-Error "Failed to create resource group: $_"
    exit 1
}

# Step 4: Create User-Assigned Managed Identity
Write-Output ""
Write-Output "[Step 4/7] Creating user-assigned managed identity..."
try {
    $identity = Get-AzUserAssignedIdentity `
        -ResourceGroupName $ResourceGroupName `
        -Name $IdentityName `
        -ErrorAction SilentlyContinue
    
    if ($identity) {
        Write-Output "✓ Managed identity '$IdentityName' already exists"
    }
    else {
        $identity = New-AzUserAssignedIdentity `
            -ResourceGroupName $ResourceGroupName `
            -Name $IdentityName `
            -Location $Location
        Write-Output "✓ Managed identity '$IdentityName' created"
    }
    
    $identityPrincipalId = $identity.PrincipalId
    $identityId = $identity.Id
    Write-Output "  Principal ID: $identityPrincipalId"
    Write-Output "  Resource ID: $identityId"
}
catch {
    Write-Error "Failed to create managed identity: $_"
    exit 1
}

# Step 5: Grant Contributor Role on Resource Group
Write-Output ""
Write-Output "[Step 5/7] Assigning Contributor role to managed identity..."
try {
    $roleAssignment = Get-AzRoleAssignment `
        -ObjectId $identityPrincipalId `
        -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" `
        -RoleDefinitionName "Contributor" `
        -ErrorAction SilentlyContinue
    
    if ($roleAssignment) {
        Write-Output "✓ Contributor role already assigned on resource group"
    }
    else {
        New-AzRoleAssignment `
            -ObjectId $identityPrincipalId `
            -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" `
            -RoleDefinitionName "Contributor" | Out-Null
        Write-Output "✓ Contributor role assigned on resource group"
    }
}
catch {
    Write-Error "Failed to assign role: $_"
    exit 1
}

# Step 6: Grant Permissions on Compute Gallery (if specified)
if ($ComputeGalleryResourceGroup -and $ComputeGalleryName) {
    Write-Output ""
    Write-Output "[Step 6a/7] Assigning Contributor role on Azure Compute Gallery..."
    try {
        $galleryScope = "/subscriptions/$SubscriptionId/resourceGroups/$ComputeGalleryResourceGroup/providers/Microsoft.Compute/galleries/$ComputeGalleryName"
        
        $galleryRoleAssignment = Get-AzRoleAssignment `
            -ObjectId $identityPrincipalId `
            -Scope $galleryScope `
            -RoleDefinitionName "Contributor" `
            -ErrorAction SilentlyContinue
        
        if ($galleryRoleAssignment) {
            Write-Output "✓ Contributor role already assigned on Compute Gallery"
        }
        else {
            New-AzRoleAssignment `
                -ObjectId $identityPrincipalId `
                -Scope $galleryScope `
                -RoleDefinitionName "Contributor" | Out-Null
            Write-Output "✓ Contributor role assigned on Compute Gallery"
        }
    }
    catch {
        Write-Warning "⚠ Failed to assign role on Compute Gallery: $_"
    }
}

# Step 6/7: Create Storage Account (Optional)
if ($CreateStorageAccount) {
    Write-Output ""
    Write-Output "[Step 6b/7] Creating storage account for build scripts..."
    
    if (-not $StorageAccountName) {
        # Generate unique storage account name
        $randomSuffix = Get-Random -Minimum 1000 -Maximum 9999
        $StorageAccountName = "stavdimg$($ResourceGroupName.Replace('-','').Substring(0,[Math]::Min(8,$ResourceGroupName.Length)))$randomSuffix".ToLower()
    }
    
    try {
        $storageAccount = Get-AzStorageAccount `
            -ResourceGroupName $ResourceGroupName `
            -Name $StorageAccountName `
            -ErrorAction SilentlyContinue
        
        if ($storageAccount) {
            Write-Output "✓ Storage account '$StorageAccountName' already exists"
        }
        else {
            $storageAccount = New-AzStorageAccount `
                -ResourceGroupName $ResourceGroupName `
                -Name $StorageAccountName `
                -Location $Location `
                -SkuName Standard_LRS `
                -Kind StorageV2
            Write-Output "✓ Storage account '$StorageAccountName' created"
        }
        
        # Create scripts container
        $ctx = $storageAccount.Context
        $container = Get-AzStorageContainer `
            -Name "scripts" `
            -Context $ctx `
            -ErrorAction SilentlyContinue
        
        if (-not $container) {
            New-AzStorageContainer `
                -Name "scripts" `
                -Context $ctx `
                -Permission Blob | Out-Null
            Write-Output "✓ Created 'scripts' container in storage account"
        }
        else {
            Write-Output "✓ 'scripts' container already exists"
        }
        
        # Output storage account details
        Write-Output ""
        Write-Output "  Storage Account Name: $StorageAccountName"
        Write-Output "  Container Name: scripts"
        Write-Output "  Blob URL Pattern: https://$StorageAccountName.blob.core.windows.net/scripts/"
    }
    catch {
        Write-Warning "⚠ Failed to create storage account: $_"
        Write-Warning "  You can create it manually or use script URLs from another location"
    }
}

# Step 7: Summary
Write-Output ""
Write-Output "[Step 7/7] Setup Summary"
Write-Output "========================================="
Write-Output ""
Write-Output "✓ Resource Group: $ResourceGroupName"
Write-Output "  Location: $Location"
Write-Output ""
Write-Output "✓ Managed Identity: $IdentityName"
Write-Output "  Principal ID: $identityPrincipalId"
Write-Output "  Resource ID: $identityId"
Write-Output ""
Write-Output "✓ Permissions:"
Write-Output "  - Contributor role on resource group"
if ($ComputeGalleryResourceGroup -and $ComputeGalleryName) {
    Write-Output "  - Contributor role on Compute Gallery"
}
Write-Output ""
if ($CreateStorageAccount -and $storageAccount) {
    Write-Output "✓ Storage Account: $StorageAccountName"
    Write-Output "  Container: scripts"
    Write-Output ""
}

Write-Output "Next Steps:"
Write-Output "==========="
Write-Output "1. Upload your Custom Image Template Scripts to the storage account:"
Write-Output "   Set-AzStorageBlobContent -Container scripts -File '<script>.ps1' -Context `$ctx"
Write-Output ""
Write-Output "2. Create an Azure Image Builder template using:"
Write-Output "   - Identity: $identityId"
Write-Output "   - Scripts from: https://$StorageAccountName.blob.core.windows.net/scripts/"
Write-Output ""
Write-Output "3. Or use Azure AVD Custom Image Templates (CIT) in Azure Portal"
Write-Output ""
Write-Output "For detailed instructions, see: CUSTOM_IMAGE_TEMPLATE_SCRIPTS_PLAN.md"
Write-Output ""
Write-Output "========================================="
Write-Output "Setup completed successfully!"
Write-Output "========================================="
