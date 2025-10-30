# Configure Storage Account for Azure Image Builder Access
# This allows the Image Builder build VM to access private blob containers

<#
.SYNOPSIS
    Configures storage account to allow Azure Image Builder access

.DESCRIPTION
    This script configures the storage account firewall to allow access from
    Azure services, enabling Azure Image Builder build VMs to download scripts
    from private blob containers.

.PARAMETER ResourceGroupName
    Resource group name where the storage account exists

.PARAMETER StorageAccountName
    Name of the storage account

.PARAMETER AllowAzureServices
    Allow access from Azure services (default: $true)
    
.PARAMETER AllowSpecificSubnets
    Allow access from specific subnet resource IDs (optional)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory = $false)]
    [bool]$AllowAzureServices = $true,
    
    [Parameter(Mandatory = $false)]
    [string[]]$AllowSpecificSubnets = @()
)

$ErrorActionPreference = 'Stop'

Write-Output "========================================="
Write-Output "Configure Storage Account for Image Builder"
Write-Output "========================================="
Write-Output ""

Write-Output "Storage Account: $StorageAccountName"
Write-Output "Resource Group: $ResourceGroupName"
Write-Output ""

try {
    # Get storage account
    $storageAccount = Get-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -ErrorAction Stop
    
    Write-Output "Current Storage Account Configuration:"
    Write-Output "  Allow Blob Public Access: $($storageAccount.AllowBlobPublicAccess)"
    Write-Output "  Network Rule Set:"
    $networkRules = $storageAccount.NetworkRuleSet
    
    if ($networkRules) {
        Write-Output "    Default Action: $($networkRules.DefaultAction)"
        Write-Output "    Bypass: $($networkRules.Bypass)"
        Write-Output "    Allowed Subnets: $($networkRules.IPRules.Count)"
        Write-Output "    Virtual Network Rules: $($networkRules.VirtualNetworkRules.Count)"
    }
    Write-Output ""
    
    # Update storage account to allow Azure services
    $updateParams = @{
        ResourceGroupName = $ResourceGroupName
        Name = $StorageAccountName
    }
    
    if ($AllowAzureServices) {
        Write-Output "Configuring storage account to allow Azure services..."
        
        # Get current network rules
        $currentRules = $storageAccount.NetworkRuleSet
        
        if (-not $currentRules) {
            $currentRules = @{
                DefaultAction = "Allow"
            }
        }
        
        # Configure to bypass Azure services
        # Bypass options: None, Logging, Metrics, AzureServices
        if ($storageAccount.NetworkRuleSet.Bypass -notmatch "AzureServices") {
            $updateParams["Bypass"] = "AzureServices"
        }
        
        # Ensure default action allows (or set IP rules if needed)
        if ($currentRules.DefaultAction -eq "Deny" -and -not $currentRules.IPRules -and -not $currentRules.VirtualNetworkRules) {
            Write-Warning "Storage account has DefaultAction=Deny with no rules. Setting to Allow for Azure services."
            $updateParams["DefaultAction"] = "Allow"
        }
        
        # Apply updates
        Update-AzStorageAccount @updateParams | Out-Null
        Write-Output "✓ Configured storage account to allow Azure services"
    }
    
    # Add specific subnet access if provided
    if ($AllowSpecificSubnets.Count -gt 0) {
        Write-Output ""
        Write-Output "Adding subnet access rules..."
        foreach ($subnetId in $AllowSpecificSubnets) {
            Add-AzStorageAccountNetworkRule `
                -ResourceGroupName $ResourceGroupName `
                -Name $StorageAccountName `
                -VirtualNetworkResourceId $subnetId | Out-Null
            Write-Output "  ✓ Added subnet: $subnetId"
        }
    }
    
    Write-Output ""
    Write-Output "========================================="
    Write-Output "Configuration Complete"
    Write-Output "========================================="
    Write-Output ""
    Write-Output "Your storage account is now configured to allow Azure Image Builder"
    Write-Output "build VMs to access scripts in the 'scripts' container."
    Write-Output ""
    Write-Output "You can now rebuild your image template."
}
catch {
    Write-Error "Failed to configure storage account: $_"
    exit 1
}
