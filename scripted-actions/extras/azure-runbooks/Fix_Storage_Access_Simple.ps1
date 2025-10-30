# Simple fix for Storage Account 403 error - Works with standard Az.Storage module

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName
)

$ErrorActionPreference = 'Stop'

Write-Output "Configuring storage account for Azure Image Builder access..."
Write-Output ""

try {
    # Get the subscription context
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not logged in to Azure. Run Connect-AzAccount first."
        exit 1
    }
    
    $subscriptionId = $context.Subscription.Id
    
    # Get access token (refresh if needed)
    Write-Output "Authenticating..."
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (-not $azProfile) {
        Write-Error "Not logged in to Azure. Run Connect-AzAccount first."
        exit 1
    }
    
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
    $token = $profileClient.AcquireAccessToken($context.Subscription.TenantId).AccessToken
    
    if (-not $token) {
        # Fallback to Get-AzAccessToken
        $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
    }
    
    # Build REST API URI (ensure API version is properly formatted)
    $apiVersion = "2023-01-01"
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"
    $uriWithApiVersion = "$uri" + "?api-version=$apiVersion"
    
    $headers = @{
        'Authorization' = "Bearer $token"
        'Content-Type' = 'application/json'
    }
    
    Write-Output "Getting current storage account configuration..."
    $storageAccount = Invoke-RestMethod -Uri $uriWithApiVersion -Method Get -Headers $headers
    
    Write-Output "Updating network rules to allow Azure services..."
    
    # Update network ACLs
    if (-not $storageAccount.properties.networkAcls) {
        $storageAccount.properties | Add-Member -MemberType NoteProperty -Name "networkAcls" -Value @{} -Force
    }
    
    $storageAccount.properties.networkAcls.bypass = "AzureServices"
    $storageAccount.properties.networkAcls.defaultAction = "Allow"
    
    # Ensure IP rules and virtual network rules arrays exist
    if (-not $storageAccount.properties.networkAcls.ipRules) {
        $storageAccount.properties.networkAcls.ipRules = @()
    }
    if (-not $storageAccount.properties.networkAcls.virtualNetworkRules) {
        $storageAccount.properties.networkAcls.virtualNetworkRules = @()
    }
    
    # Convert to JSON (remove null properties, keep arrays even if empty)
    $body = $storageAccount | ConvertTo-Json -Depth 10 -Compress
    
    # Update storage account
    Write-Output "Applying changes..."
    Invoke-RestMethod -Uri $uriWithApiVersion -Method Put -Headers $headers -Body $body | Out-Null
    
    Write-Output ""
    Write-Output "========================================="
    Write-Output "✓ Storage account configured successfully!"
    Write-Output "========================================="
    Write-Output ""
    Write-Output "The storage account now allows:"
    Write-Output "  - Azure services bypass (AzureServices)"
    Write-Output "  - Default action: Allow"
    Write-Output ""
    Write-Output "Azure Image Builder can now access your scripts."
    Write-Output "You can retry your image build!"
}
catch {
    Write-Error "Failed to configure storage account: $_"
    Write-Output ""
    Write-Output "Alternative: Configure via Azure Portal:"
    Write-Output "  1. Go to Storage Account -> Networking"
    Write-Output "  2. Under 'Network access', select 'Allow access from Azure services'"
    Write-Output "  3. Set 'Default action' to 'Allow'"
    Write-Output "  4. Save"
    exit 1
}
