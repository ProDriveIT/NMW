# Quick fix to create the scripts container with private access
# Run this after Setup script if container creation failed

<#
.SYNOPSIS
    Creates the scripts container in the storage account with private access

.DESCRIPTION
    This script creates the "scripts" container in the storage account that was
    created by Setup-AzureImageBuilderInfrastructure.ps1 but failed due to public
    access restrictions.

.PARAMETER ResourceGroupName
    Resource group name where the storage account was created

.PARAMETER StorageAccountName
    Name of the storage account (from the setup script output)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName
)

$ErrorActionPreference = 'Stop'

Write-Output "Creating scripts container in storage account: $StorageAccountName"

try {
    # Get storage account
    $storageAccount = Get-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -ErrorAction Stop
    
    $ctx = $storageAccount.Context
    
    # Check if container already exists
    $container = Get-AzStorageContainer `
        -Name "scripts" `
        -Context $ctx `
        -ErrorAction SilentlyContinue
    
    if ($container) {
        Write-Output "✓ Container 'scripts' already exists"
    }
    else {
        # Create container with private access (Permission Off)
        New-AzStorageContainer `
            -Name "scripts" `
            -Context $ctx `
            -Permission Off | Out-Null
        
        Write-Output "✓ Created 'scripts' container with private access"
    }
    
    Write-Output ""
    Write-Output "Container Details:"
    Write-Output "  Storage Account: $StorageAccountName"
    Write-Output "  Container: scripts"
    Write-Output "  Access: Private (requires SAS tokens or firewall rules)"
    Write-Output ""
    Write-Output "You can now upload scripts to this container."
}
catch {
    Write-Error "Failed to create container: $_"
    exit 1
}
