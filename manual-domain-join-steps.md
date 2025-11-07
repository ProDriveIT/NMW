# Manual Domain Join Steps for Failed AVD VM

## Prerequisites
1. **Fix DNS First** - Update VNet DNS settings to point to domain controller DNS servers
2. **Wait 5-10 minutes** for DNS propagation
3. **Connect to VM** using RDP with local administrator account

## Step-by-Step Process

### 1. Connect to the VM
- Use Azure Portal > Virtual Machines > Select VM > Connect > RDP
- Use the local administrator credentials from deployment

### 2. Verify DNS Resolution
Once connected, open PowerShell as Administrator and test:
```powershell
# Test DNS resolution
nslookup cheesman.co.uk

# Test domain controller discovery
nltest /dsgetdc:cheesman.co.uk
```

If these fail, DNS is still not configured correctly.

### 3. Join Domain Manually

**Option A: Using GUI**
1. Right-click **This PC** > **Properties**
2. Click **Change settings**
3. Click **Change** under Computer Name
4. Select **Domain** and enter: `cheesman.co.uk`
5. Enter domain admin credentials: `jstock_jit@cheesman.co.uk`
6. Click **OK** and restart when prompted

**Option B: Using PowerShell (Recommended)**
```powershell
# Run as Administrator
$domainName = "cheesman.co.uk"
$username = "jstock_jit@cheesman.co.uk"
$credential = Get-Credential -UserName $username -Message "Enter domain password"

# Join domain
Add-Computer -DomainName $domainName -Credential $credential -Force -Restart
```

### 4. After Domain Join
After the VM restarts and is domain-joined:

1. **Verify Domain Join**
   ```powershell
   (Get-WmiObject Win32_ComputerSystem).Domain
   # Should return: cheesman.co.uk
   ```

2. **Register AVD Agent** (if not already registered)
   - The AVD agent may need to be registered manually
   - Check if agent is installed: `Get-Service -Name "RDAgent*"`
   - If agent exists but not registered, you may need to re-run the registration

3. **Verify AVD Agent Status**
   - Check in Azure Portal > Host Pool > Virtual Machines
   - VM should show as "Available" after domain join and agent registration

## Important Notes

- **DNS Must Work First** - Domain join will fail if DNS can't resolve the domain
- **Network Connectivity** - Ensure VM can reach domain controllers (ports 53, 88, 389, etc.)
- **AVD Agent** - May need manual registration after domain join
- **Future Deployments** - Fix DNS on VNet before deploying to avoid this issue

## Troubleshooting

If domain join still fails:
1. Check DNS: `nslookup cheesman.co.uk`
2. Check connectivity: `Test-NetConnection -ComputerName <DC-IP> -Port 389`
3. Check NSG rules allow outbound to domain controllers
4. Verify VPN/ExpressRoute connectivity if DCs are on-premises


