# Quick Fix for 403 Authorization Permission Mismatch
# Configures storage account to allow Azure Image Builder access

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName
)

$ErrorActionPreference = 'Stop'

Write-Output "Fixing storage account access for Azure Image Builder..."
Write-Output ""

# Get storage account
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName `
    -ErrorAction Stop

# Method 1: Try using Update-AzStorageAccount with network rules
try {
    # Get current settings
    $currentNetworkRules = $storageAccount.NetworkRuleSet
    
    # Create new network rule set that allows Azure services
    $newNetworkRuleSet = New-Object Microsoft.Azure.Commands.Management.Storage.Models.PSNetworkRuleSet
    $newNetworkRuleSet.DefaultAction = "Allow"
    $newNetworkRuleSet.Bypass = "AzureServices"
    $newNetworkRuleSet.IPRules = @()
    $newNetworkRuleSet.VirtualNetworkRules = @()
    
    Update-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -NetworkRuleSet $newNetworkRuleSet
    
    Write-Output "✓ Method 1: Updated via PowerShell cmdlet"
}
catch {
    Write-Warning "Method 1 failed: $_"
    Write-Output ""
    Write-Output "Trying alternative method via Azure REST API..."
    
    # Method 2: Use REST API directly
    $context = Get-AzContext
    $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
    
    $subscriptionId = $context.Subscription.Id
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName?api-version=2023-01-01"
    
    # Get current storage account properties
    $headers = @{
        'Authorization' = "Bearer $token"
        'Content-Type' = 'application/json'
    }
    
    $storageAccountJson = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    
    # Update networkAcls to allow Azure services
    if (-not $storageAccountJson.properties.networkAcls) {
        $storageAccountJson.properties.networkAcls = @{}
    }
    
    $storageAccountJson.properties.networkAcls.bypass = "AzureServices"
    $storageAccountJson.properties.networkAcls.defaultAction = "Allow"
    $storageAccountJson.properties.networkAcls.ipRules = @()
    $storageAccountJson.properties.networkAcls.virtualNetworkRules = @()
    
    # Update storage account
    $body = $storageAccountJson | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $body | Out-Null
    
    Write-Output "✓ Method 2: Updated via REST API"
}

Write-Output ""
Write-Output "========================================="
Write-Output "Storage account configured successfully!"
Write-Output "========================================="
Write-Output ""
Write-Output "The storage account now allows Azure services (including Image Builder)"
Write-Output "to access your private container."
Write-Output ""
Write-Output "You can now retry your image build."
Write-Output ""
