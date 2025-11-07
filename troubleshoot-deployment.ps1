# Troubleshoot AVD Host Pool Deployment Failure
# Run this script to get detailed error information

$ResourceGroupName = "rg-CA-Prod-UKSouth-001"
$SubscriptionId = "fb8c75fd-6b99-44d1-b127-06b4c3e4c816"

# Set the subscription context
az account set --subscription $SubscriptionId

# Get the failed deployment name
Write-Host "Getting failed deployment information..." -ForegroundColor Cyan
$deployments = az deployment group list --resource-group $ResourceGroupName --query "[?properties.provisioningState=='Failed'].{Name:name, Timestamp:properties.timestamp}" --output table

Write-Host "`nFailed Deployments:" -ForegroundColor Yellow
$deployments

# Get detailed error for the specific deployment
$deploymentName = "HostPool-1049fc9a-1039-4409-a421-d7bad284d0a0-deployment"
Write-Host "`nGetting detailed error for: $deploymentName" -ForegroundColor Cyan

$errorDetails = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --query "properties.error" `
    --output json

Write-Host "`nError Details:" -ForegroundColor Red
$errorDetails | ConvertFrom-Json | ConvertTo-Json -Depth 10

# Get nested deployment errors
Write-Host "`nGetting nested deployment errors..." -ForegroundColor Cyan
$nestedDeployment = "vmCreation-linkedTemplate-1049fc9a-1039-4409-a421-d7bad284d0a0"
$nestedError = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $nestedDeployment `
    --query "properties.error" `
    --output json

Write-Host "`nNested Deployment Error:" -ForegroundColor Red
$nestedError | ConvertFrom-Json | ConvertTo-Json -Depth 10

# Check for common issues
Write-Host "`n`nChecking for common issues..." -ForegroundColor Cyan

# Check VM quota
Write-Host "`n1. Checking VM quota in UK South region..." -ForegroundColor Yellow
az vm list-usage --location "uksouth" --output table

# Check if image exists and is accessible
Write-Host "`n2. Checking for custom images in the resource group..." -ForegroundColor Yellow
az image list --resource-group $ResourceGroupName --output table

# Check network resources
Write-Host "`n3. Checking virtual networks..." -ForegroundColor Yellow
az network vnet list --resource-group $ResourceGroupName --output table

Write-Host "`n`nCommon causes of VM creation failures:" -ForegroundColor Cyan
Write-Host "  - VM size not available in the region" -ForegroundColor White
Write-Host "  - Quota exceeded for VM cores/virtual machines" -ForegroundColor White
Write-Host "  - Image generation mismatch (Gen1 vs Gen2)" -ForegroundColor White
Write-Host "  - Network/subnet configuration issues" -ForegroundColor White
Write-Host "  - Domain join failures (if domain join is configured)" -ForegroundColor White
Write-Host "  - AVD agent registration failures" -ForegroundColor White
Write-Host "  - Insufficient permissions on resource group" -ForegroundColor White


