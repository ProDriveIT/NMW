# Check Domain Join Requirements for AVD VMs
# This script helps diagnose domain join connectivity issues

$ResourceGroupName = "rg-CA-Prod-UKSouth-001"
$DomainName = "cheesman.co.uk"

Write-Host "=== Domain Join Troubleshooting for $DomainName ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check VNet DNS Settings
Write-Host "1. Checking VNet DNS Configuration..." -ForegroundColor Yellow
$vnets = az network vnet list --resource-group $ResourceGroupName --query "[].{Name:name, DNS:dhcpOptions.dnsServers}" --output json | ConvertFrom-Json

foreach ($vnet in $vnets) {
    Write-Host "  VNet: $($vnet.Name)" -ForegroundColor White
    if ($vnet.DNS) {
        Write-Host "    DNS Servers: $($vnet.DNS -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "    DNS Servers: Using Azure default (168.63.129.16)" -ForegroundColor Yellow
        Write-Host "    WARNING: Azure default DNS may not resolve on-premises domains!" -ForegroundColor Red
    }
}

# 2. Check Subnet Configuration
Write-Host "`n2. Checking Subnet Configuration..." -ForegroundColor Yellow
$subnets = az network vnet subnet list --resource-group $ResourceGroupName --vnet-name $vnets[0].Name --query "[].{Name:name, AddressPrefix:addressPrefix}" --output table
Write-Host $subnets

# 3. Check NSG Rules (if NSG is attached)
Write-Host "`n3. Checking Network Security Group Rules..." -ForegroundColor Yellow
Write-Host "  Required ports for domain join:" -ForegroundColor White
Write-Host "    - TCP 53 (DNS)" -ForegroundColor White
Write-Host "    - UDP 53 (DNS)" -ForegroundColor White
Write-Host "    - TCP 88 (Kerberos)" -ForegroundColor White
Write-Host "    - UDP 88 (Kerberos)" -ForegroundColor White
Write-Host "    - TCP 135 (RPC Endpoint Mapper)" -ForegroundColor White
Write-Host "    - TCP 389 (LDAP)" -ForegroundColor White
Write-Host "    - TCP 445 (SMB)" -ForegroundColor White
Write-Host "    - TCP 636 (LDAPS)" -ForegroundColor White
Write-Host "    - TCP 3268 (Global Catalog)" -ForegroundColor White
Write-Host "    - TCP 3269 (Global Catalog SSL)" -ForegroundColor White

# 4. Check if domain controllers are reachable
Write-Host "`n4. Domain Controller Connectivity Requirements:" -ForegroundColor Yellow
Write-Host "  The VM must be able to:" -ForegroundColor White
Write-Host "    - Resolve DNS for $DomainName" -ForegroundColor White
Write-Host "    - Reach domain controllers on required ports (see above)" -ForegroundColor White
Write-Host "    - Authenticate using account: jstock_jit@cheesman.co.uk" -ForegroundColor White

# 5. Common Solutions
Write-Host "`n=== COMMON SOLUTIONS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "SOLUTION 1: Configure Custom DNS on VNet" -ForegroundColor Yellow
Write-Host "  If domain controllers are on-premises:" -ForegroundColor White
Write-Host "    1. Go to Azure Portal > Virtual Networks" -ForegroundColor White
Write-Host "    2. Select your VNet" -ForegroundColor White
Write-Host "    3. Go to DNS servers > Custom" -ForegroundColor White
Write-Host "    4. Add your on-premises DNS server IPs" -ForegroundColor White
Write-Host "    5. Save and wait for DNS propagation" -ForegroundColor White
Write-Host ""
Write-Host "SOLUTION 2: Verify VPN/ExpressRoute Connectivity" -ForegroundColor Yellow
Write-Host "  If domain controllers are on-premises:" -ForegroundColor White
Write-Host "    - Ensure VPN Gateway or ExpressRoute is connected" -ForegroundColor White
Write-Host "    - Verify routes are configured correctly" -ForegroundColor White
Write-Host "    - Test connectivity from Azure to on-premises" -ForegroundColor White
Write-Host ""
Write-Host "SOLUTION 3: Check NSG Rules" -ForegroundColor Yellow
Write-Host "  Ensure NSG allows outbound traffic to domain controllers on required ports" -ForegroundColor White
Write-Host ""
Write-Host "SOLUTION 4: Use Azure AD Domain Services (Alternative)" -ForegroundColor Yellow
Write-Host "  If on-premises connectivity is not available, consider Azure AD DS" -ForegroundColor White
Write-Host ""
Write-Host "SOLUTION 5: Deploy without Domain Join (Temporary)" -ForegroundColor Yellow
Write-Host "  Deploy VMs without domain join, then join manually after network is configured" -ForegroundColor White


