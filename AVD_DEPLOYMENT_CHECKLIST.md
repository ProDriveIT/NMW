# Azure Virtual Desktop - Complete Deployment Checklist

## Phase 1: Prerequisites and Subscription Setup

- [ ] Confirm valid Azure subscription exists and is active
- [ ] Verify subscription has sufficient quota for required VM sizes and resources
- [ ] Confirm Global Administrator role in Azure AD
- [ ] Confirm Owner role on target Azure subscription
- [ ] Document subscription ID and resource naming conventions
- [ ] Identify target regions for deployment (primary and secondary)
- [ ] Review and approve estimated monthly costs for AVD infrastructure

---

## Phase 2: FSLogix Storage Account Configuration

> **Automation Available**: This phase can be automated using `setup-avd-live-infrastructure.ps1` script.
> The script creates Premium storage account with 100GB Azure Files share, configures networking, and sets up permissions.
> See script documentation for details.

### Storage Account Creation
- [ ] Create Azure Storage Account for FSLogix profiles (e.g., `stavdprofiles`)
- [ ] Select appropriate storage account SKU (Standard or Premium based on performance needs)
- [ ] Configure storage account redundancy (LRS, ZRS, GRS based on requirements)
- [ ] Create Azure Files share for FSLogix profiles (e.g., `avd-profiles`)
- [ ] Set share quota appropriate for expected user count (recommend 5GB per user minimum)
- [ ] Document storage account name, resource group, and share name

### Network Configuration
- [ ] Configure storage account networking to allow access from session hosts
- [ ] Enable "Allow Azure services on the trusted services list" for build VM access
- [ ] Configure private endpoint for FSLogix storage (recommended for production)
- [ ] Configure DNS resolution for storage account (if using private endpoint)
- [ ] Test network connectivity from test VM to storage account

### Permissions Configuration
- [ ] Create Azure AD security group for session host VMs (e.g., `sg-avd-session-hosts`)
- [ ] Assign "Storage File Data SMB Share Contributor" role to session host security group on storage account
- [ ] Assign "Storage File Data SMB Share Elevated Contributor" role to session host security group (if needed for profile management)
- [ ] Document security group name and role assignments
- [ ] Verify session host security group has correct permissions using Azure Portal IAM

### Storage Account Security
- [ ] Enable soft delete on storage account (recommended: 7-14 days retention)
- [ ] Enable versioning on storage account (optional but recommended)
- [ ] Configure storage account firewall rules (if restricting access)
- [ ] Document storage account access method (public endpoint vs private endpoint)
- [ ] Generate and securely store storage account access keys (if needed)

---

## Phase 3: Infrastructure Setup - Development Environment

### Resource Group Creation
- [ ] Create development resource group (e.g., `rg-avd-dev`)
- [ ] Tag resource group appropriately (Environment: Dev, Project: AVD)
- [ ] Set resource group location to target region

### Infrastructure Setup Script Execution
- [ ] Open Azure Cloud Shell (PowerShell mode)
- [ ] Clone NMW repository: `git clone https://github.com/ProDriveIT/NMW.git`
- [ ] Navigate to CIT Deployment folder: `cd NMW/"CIT Deployment"`
- [ ] Run infrastructure setup script: `./setup-avd-cit-infrastructure.ps1`
- [ ] Provide subscription ID when prompted (or press Enter for current subscription)
- [ ] Wait for script completion (15-20 minutes for resource provider registration)
- [ ] Verify script output shows all resources created successfully

### Infrastructure Verification
- [ ] Verify resource group `rg-avd-cit-infrastructure` created
- [ ] Verify managed identity `umi-avd-cit` created
- [ ] Verify Azure Compute Gallery `gal_avd_images` created
- [ ] Verify gallery image definition `avd_session_host` created (Publisher: ProDriveIT, Offer: avd_images, SKU: windows11_avd)
- [ ] Verify storage account created (if script created one)
- [ ] Verify custom RBAC role created and assigned to managed identity
- [ ] Document all created resource names and locations

### Managed Identity Permissions
- [ ] Verify managed identity has Contributor role on resource group `rg-avd-cit-infrastructure`
- [ ] Verify managed identity has Contributor role on Azure Compute Gallery `gal_avd_images`
- [ ] Verify managed identity has Contributor role on image definition `avd_session_host`
- [ ] Verify managed identity has required Image Builder permissions
- [ ] Document managed identity name: `umi-avd-cit`

---

## Phase 4: Infrastructure Setup - Live/Production Environment

> **Automation Available**: This phase can be automated using `setup-avd-live-infrastructure.ps1` script.
> The script creates resource group, virtual network, subnet, NSG with AVD rules, and optionally creates security groups.
> Run from `CIT Deployment` folder: `.\setup-avd-live-infrastructure.ps1`

### Resource Group Creation
- [ ] Create production resource group (e.g., `rg-avd-prod`)
- [ ] Tag resource group appropriately (Environment: Production, Project: AVD)
- [ ] Set resource group location to target region
- [ ] Ensure resource group is separate from development environment

### Infrastructure Replication (if needed)
- [ ] Decide if production needs separate infrastructure or can share dev infrastructure
- [ ] If separate: Run infrastructure setup script again with production resource group
- [ ] If shared: Document that dev and prod will share same gallery and managed identity
- [ ] Document infrastructure sharing strategy

### Network Configuration
- [ ] Plan virtual network architecture for production
- [ ] Create or identify virtual network for session hosts
- [ ] Create or identify subnet for AVD session hosts (minimum /24 recommended)
- [ ] Configure network security group rules for session hosts
- [ ] Configure DNS settings for domain join (if applicable)
- [ ] Plan connectivity to on-premises resources (VPN, ExpressRoute, etc.)

---

## Phase 5: Custom Image Template (CIT) Creation

### CIT Basics Configuration
- [ ] Navigate to Azure Portal > Azure Virtual Desktop > Custom image templates
- [ ] Click "+ Create" to start new template wizard
- [ ] Enter template name (e.g., `AVD-GoldenImage-v1`)
- [ ] Select subscription
- [ ] Select resource group: `rg-avd-cit-infrastructure`
- [ ] Select location (same region as infrastructure)
- [ ] Select managed identity: User-assigned > `umi-avd-cit`
- [ ] Click Next

### Source Image Configuration
- [ ] Select "Platform image (marketplace)"
- [ ] Choose latest Windows 11 version (without apps)
- [ ] Verify source image is Gen2
- [ ] Click Next

### Distribution Targets Configuration
- [ ] Check "Azure Compute Gallery" (leave "Managed image" unchecked)
- [ ] Select gallery name: `gal_avd_images`
- [ ] Select gallery image definition: `avd_session_host`
- [ ] Enter gallery image version: `0.0.1`
- [ ] Enter run output name: `AVDImageBuild1`
- [ ] Select replicated regions (at minimum, same region as infrastructure)
- [ ] Set "Excluded from latest" to No
- [ ] Set storage account type: `Standard_LRS`
- [ ] Click Next

### Build Properties Configuration
- [ ] Set build timeout: `200` minutes
- [ ] Set build VM size: `Standard_D2s_v4`
- [ ] Set OS disk size: `127` GB (or larger if needed)
- [ ] Leave staging group blank (auto-created)
- [ ] Leave build VM managed identity blank (optional)
- [ ] Leave virtual network blank (temporary network created)
- [ ] Click Next

### Customizations - Built-in Scripts
- [ ] Add "Install language packs" - Select English (United Kingdom)
- [ ] Add "Set default OS language" - Select English (United Kingdom)
- [ ] Add "Time zone redirection" - Enable: Yes
- [ ] Add "Disable storage sense" - Enable: Yes
- [ ] Add "Install and enable FSLogix" - Enable: Yes, Profile path: `\\[storageaccount].file.core.windows.net\[sharename]`
- [ ] Add "Configure RDP shortpath" - Enable: Yes
- [ ] Add "Install Teams with optimizations" - Enable: Yes
- [ ] Add "Configure session timeouts" - Enable: Yes, Configure time limits (6h disconnected, 2h idle, 12h active, 15min sign out)
- [ ] Add "Install multimedia redirection" - Enable: Yes, Architecture: x64, Edge: Yes, Chrome: Yes
- [ ] Add "Configure Windows optimizations" - Enable: Yes, Select all optimization options
- [ ] Add "Disable auto update" - Enable: Yes
- [ ] Add "Remove AppX packages" - Enable: Yes (keep commonly used apps)
- [ ] Add "Apply Windows updates" - Enable: Yes

### Customizations - Custom Scripts
- [ ] Add "Install Microsoft 365 Apps" - URI: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-m365-apps.ps1`
- [ ] Add "Install OneDrive Per Machine" - URI: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-onedrive-per-machine.ps1`
- [ ] Add "Optimize Microsoft Edge" - URI: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/optimize-microsoft-edge.ps1`
- [ ] Add "Install Google Chrome Per Machine" - URI: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-chrome-per-machine.ps1`
- [ ] Add "Install Adobe Reader Per Machine" - URI: `https://raw.githubusercontent.com/ProDriveIT/NMW/refs/heads/main/scripted-actions/windows-scripts/install-adobe-reader-per-machine.ps1`
- [ ] Verify script execution order (use Move up/Move down if needed)
- [ ] Click Next

### Tags and Review
- [ ] Add appropriate tags to template (Environment, Project, etc.)
- [ ] Review all settings in Review + Create tab
- [ ] Verify managed identity is correct
- [ ] Verify gallery and image definition are correct
- [ ] Click Create
- [ ] Wait for template creation (approximately 20 seconds)
- [ ] Verify template shows in Custom image templates list

---

## Phase 6: Image Build and Testing

### Initial Image Build
- [ ] Navigate to Custom image templates
- [ ] Select the created template
- [ ] Click "Start build"
- [ ] Monitor build status (click Refresh to update)
- [ ] Click template name to view detailed build run state
- [ ] Wait for build completion (typically 30-120 minutes)

### Build Verification
- [ ] Verify build status shows "Succeeded"
- [ ] If build failed, review build logs in temporary resource group
- [ ] Navigate to Azure Compute Gallery > `gal_avd_images` > Image definitions > `avd_session_host`
- [ ] Verify image version `0.0.1` appears
- [ ] Verify replication status shows "Completed" for all target regions
- [ ] Document image version and build completion date

### Build Troubleshooting (if needed)
- [ ] If build fails, navigate to temporary resource group: `IT_rg-avd-cit-infrastructure_[TemplateName]_[GUID]`
- [ ] Find Storage Account in temporary resource group
- [ ] Open Storage Account > Containers > `packerlogs` container
- [ ] Download and review `customization.log` for errors
- [ ] Address any script errors or permission issues
- [ ] Create new template with fixes (templates are immutable)
- [ ] Re-run build with updated template

---

## Phase 7: Custom/LOB Applications Deployment

### Application Preparation
- [ ] Identify all custom/LOB applications required for deployment
- [ ] Create installation scripts for each custom application
- [ ] Test installation scripts in isolated VM environment
- [ ] Upload application installers to Azure Blob Storage (if needed)
- [ ] Generate SAS tokens for blob storage access (if using private storage)
- [ ] Configure storage account network access (allow Azure services)

### Application Script Integration
- [ ] Add custom application installation scripts to CIT template
- [ ] For each application, add "+ Add your own script" in CIT customizations
- [ ] Configure script URI (GitHub raw URL or Azure Blob Storage with SAS token)
- [ ] Verify script execution order (custom apps after base applications)
- [ ] Document all custom application scripts and their order

### Application Testing
- [ ] Build new image version with custom applications included
- [ ] Create test VM from new image version
- [ ] Connect to test VM and verify all applications install correctly
- [ ] Test each application functionality
- [ ] Verify applications persist after sysprep/generalization
- [ ] Document any application-specific configuration requirements

### CCH Apps Deployment (if applicable)
- [ ] Upload CCHAPPS.zip to Azure Blob Storage
- [ ] Generate SAS token for CCHAPPS.zip with Read permission
- [ ] Add "Upload CCH Apps" script to CIT: `upload-cch-apps.ps1`
- [ ] Add "Run CCH Rollout Script" to CIT: `run-cch-rollout-script.ps1`
- [ ] Configure CCH rollout script to create scheduled task for first boot
- [ ] Verify CCH apps deployment in test VM
- [ ] Test CCH rollout script execution on first boot

---

## Phase 8: Host Pool Deployment

### Host Pool Creation - Basics
- [ ] Navigate to Azure Virtual Desktop > Host pools
- [ ] Click "+ Create"
- [ ] Enter host pool name (e.g., `hp-avd-production`)
- [ ] Select subscription
- [ ] Select resource group (production resource group)
- [ ] Select location (region)
- [ ] Set validation environment: No (unless creating validation pool)
- [ ] Select host pool type: Pooled (recommended) or Personal
- [ ] Select load balancing algorithm: Breadth-first (recommended) or Depth-first
- [ ] Click Next

### Virtual Machine Configuration
- [ ] Select resource group for VMs (can be different from host pool resource group)
- [ ] Enter VM name prefix (e.g., `avd-vm`)
- [ ] Select virtual machine location (should match image replication region)
- [ ] Select availability options (Availability zone or Availability set)
- [ ] Select security type: Trusted launch (recommended) or Standard
- [ ] Click on Image field to select custom image

### Custom Image Selection
- [ ] Click "See all images" or Image field
- [ ] Select "Shared images" (custom images from gallery)
- [ ] Select gallery: `gal_avd_images`
- [ ] Select image definition: `avd_session_host`
- [ ] Select image version (latest recommended, e.g., `0.0.1`)
- [ ] Verify image details show: Publisher: ProDriveIT, Offer: avd_images, SKU: windows11_avd
- [ ] Click Select to confirm

### VM Size and Configuration
- [ ] Select VM size (must be Gen2-compatible, e.g., `Standard_D2s_v4`, `Standard_D4s_v4`)
- [ ] Enter number of VMs to create
- [ ] Select OS disk type: Premium SSD (recommended) or Standard SSD
- [ ] Select virtual network for session hosts
- [ ] Select subnet for session hosts
- [ ] Select network security group: None (recommended) or existing NSG
- [ ] Set public IP: No (recommended for security)
- [ ] Click Next

### Domain Join Configuration (if applicable)
- [ ] Configure domain join settings (if using Active Directory)
- [ ] Enter domain name
- [ ] Select OU for computer objects
- [ ] Enter domain join credentials (service account)
- [ ] Verify domain join account has permissions to join computers to domain
- [ ] Document domain join account and OU

### Workspace Configuration
- [ ] Set "Register desktop app group" to Yes (recommended)
- [ ] Select existing workspace or create new workspace
- [ ] Configure workspace name and location
- [ ] Click Next

### Tags and Deployment
- [ ] Add appropriate tags to host pool
- [ ] Review all settings in Review + Create tab
- [ ] Verify custom image is selected correctly
- [ ] Verify VM size is Gen2-compatible
- [ ] Verify network configuration is correct
- [ ] Click Create
- [ ] Wait for deployment completion (15-30 minutes)
- [ ] Monitor deployment progress in Notifications

### Host Pool Verification
- [ ] Navigate to Host pools > Select your host pool
- [ ] Click Virtual machines tab
- [ ] Verify all VMs show Status: Available
- [ ] Verify Agent version is shown (indicates AVD agent installed)
- [ ] Verify VMs are domain-joined (if configured)
- [ ] Document host pool name and VM count

---

## Phase 9: Access and Permissions Configuration

### User Access - Security Groups
- [ ] Create Azure AD security group for AVD users (e.g., `sg-avd-users`)
- [ ] Add test users to security group
- [ ] Document security group name and membership
- [ ] Verify security group is Azure AD security group (not distribution group)

### Application Group Assignment
- [ ] Navigate to Host pools > Your host pool > Application groups
- [ ] Select or create Desktop application group
- [ ] Click Assignments tab
- [ ] Click "+ Add" to assign users/groups
- [ ] Select user security group: `sg-avd-users`
- [ ] Verify assignment shows in list
- [ ] Document application group name and assigned security group

### Session Host Permissions - FSLogix Storage
- [ ] Verify session host VMs are members of session host security group (e.g., `sg-avd-session-hosts`)
- [ ] Verify session host security group has "Storage File Data SMB Share Contributor" role on FSLogix storage account
- [ ] Verify session host security group has "Storage File Data SMB Share Elevated Contributor" role (if needed)
- [ ] Test FSLogix profile access from a session host VM
- [ ] Verify session hosts can create/access profiles in FSLogix share
- [ ] Document role assignments and verify in Azure Portal IAM

### Session Host Permissions - Domain (if applicable)
- [ ] Verify session host VMs have appropriate domain permissions
- [ ] Verify session hosts can access required network shares
- [ ] Verify session hosts can access required printers
- [ ] Test domain resource access from session host

### User Permissions - Desktop Access
- [ ] Verify users in security group can see desktop in Remote Desktop app
- [ ] Test user connection to host pool
- [ ] Verify user can log in and access desktop
- [ ] Verify user profile is created in FSLogix share
- [ ] Test user profile persistence (logout and login again)

### Network Access Requirements
- [ ] Verify users can access required internet resources
- [ ] Verify users can access required internal resources (if applicable)
- [ ] Configure network security group rules for required outbound access
- [ ] Test connectivity to required services (Office 365, Teams, etc.)
- [ ] Document any required firewall rules or network configurations

---

## Phase 10: User Acceptance Testing (UAT)

### UAT Environment Preparation
- [ ] Create UAT host pool (or use production host pool for testing)
- [ ] Deploy test session hosts using custom image
- [ ] Assign UAT testers to security group
- [ ] Verify testers can access UAT environment
- [ ] Send UAT access notification to testers
- [ ] Provide UAT testing guide to testers

### Tester Selection
- [ ] Select 2-20 testers based on expected user count (10-20% of users, min 2, max 20)
- [ ] Ensure testers represent different roles and departments
- [ ] Include both technical and non-technical users
- [ ] Include key stakeholders and department heads
- [ ] Document tester list and contact information

### UAT Testing Period
- [ ] Provide 5-7 business days for testers to complete testing
- [ ] Monitor tester feedback and issues
- [ ] Track all reported issues in issue tracking system
- [ ] Prioritize issues (High/Medium/Low)
- [ ] Address critical (High priority) issues immediately

### UAT Feedback Collection
- [ ] Collect feedback from all testers
- [ ] Review all reported issues
- [ ] Categorize issues (missing apps, configuration, performance, etc.)
- [ ] Create action plan for issue resolution
- [ ] Communicate resolution timeline to testers

### UAT Issue Resolution
- [ ] Fix all critical (High priority) issues
- [ ] Update CIT template with fixes (create new template version)
- [ ] Rebuild image with fixes (new image version)
- [ ] Deploy updated image to UAT environment
- [ ] Request re-testing from testers for fixed issues
- [ ] Verify all critical issues are resolved

### UAT Sign-Off
- [ ] Collect sign-off from minimum 2 testers (or 5+ for large deployments)
- [ ] Verify all critical issues are resolved
- [ ] Verify at least 80% of required applications are functional
- [ ] Verify performance is acceptable
- [ ] Obtain IT administrator approval (for large deployments)
- [ ] Document UAT sign-off completion
- [ ] Store signed UAT sign-off forms

---

## Phase 11: Scaling Plan

### Capacity Planning
- [ ] Determine expected user count for production
- [ ] Calculate required session hosts based on user count and VM size
- [ ] Plan for peak usage scenarios (e.g., 150% of normal capacity)
- [ ] Document scaling strategy (manual vs automatic)
- [ ] Plan for future growth (6 months, 12 months)

### Scaling Configuration
- [ ] Configure autoscaling (if using Azure Automation or scaling plan)
- [ ] Set minimum session host count
- [ ] Set maximum session host count
- [ ] Configure scaling triggers (CPU, memory, active sessions)
- [ ] Configure scale-out and scale-in schedules
- [ ] Test autoscaling functionality (if enabled)

### Cost Optimization
- [ ] Review VM sizing for cost optimization
- [ ] Consider using Azure Reserved Instances for predictable workloads
- [ ] Plan for shutdown schedules (outside business hours)
- [ ] Configure cost alerts and budgets
- [ ] Document estimated monthly costs

### Monitoring and Alerts
- [ ] Configure Azure Monitor alerts for host pool health
- [ ] Set up alerts for session host availability
- [ ] Configure alerts for FSLogix storage capacity
- [ ] Set up cost alerts for budget thresholds
- [ ] Document alert configuration and response procedures

---

## Phase 12: Production Deployment and Live Sign-Off

### Production Image Deployment
- [ ] Verify UAT sign-off is complete
- [ ] Verify final image version is approved
- [ ] Deploy approved image version to production host pool
- [ ] Verify all production session hosts are using approved image
- [ ] Test production environment connectivity
- [ ] Verify all applications work in production

### Production Access Rollout
- [ ] Add production users to security group
- [ ] Verify users can access production environment
- [ ] Send welcome email to users with connection instructions
- [ ] Provide user training materials (if applicable)
- [ ] Set up user support process

### Production Verification
- [ ] Verify all production session hosts show Status: Available
- [ ] Verify FSLogix profiles are being created correctly
- [ ] Verify user sessions are working correctly
- [ ] Monitor production environment for issues
- [ ] Test failover scenarios (if applicable)

### Documentation
- [ ] Document final image version deployed to production
- [ ] Document host pool configuration
- [ ] Document security group memberships
- [ ] Document network configuration
- [ ] Document support procedures
- [ ] Create runbook for common operations

### Live Sign-Off
- [ ] Obtain sign-off from project sponsor
- [ ] Obtain sign-off from IT manager/director
- [ ] Obtain sign-off from business stakeholders
- [ ] Document production deployment completion
- [ ] Store signed live sign-off forms
- [ ] Archive project documentation

### Post-Deployment
- [ ] Schedule regular image update process (monthly/quarterly)
- [ ] Plan for Windows updates and security patches
- [ ] Plan for application updates
- [ ] Set up regular backup procedures for FSLogix profiles
- [ ] Schedule regular review of scaling and cost optimization
- [ ] Document lessons learned and improvement opportunities

---

## Critical Permissions Summary

### Session Hosts to FSLogix Storage
- Security Group: `sg-avd-session-hosts` (or equivalent)
- Role: "Storage File Data SMB Share Contributor" on storage account
- Role: "Storage File Data SMB Share Elevated Contributor" (if needed)
- Scope: Storage account level

### Users to Host Pool
- Security Group: `sg-avd-users` (or equivalent)
- Assignment: Desktop application group
- Access: Via Azure AD authentication

### Managed Identity for CIT
- Managed Identity: `umi-avd-cit`
- Role: Contributor on resource group `rg-avd-cit-infrastructure`
- Role: Contributor on Azure Compute Gallery `gal_avd_images`
- Role: Contributor on image definition `avd_session_host`

---

## Important Notes

- **Resource Groups**: Keep development and production environments in separate resource groups for clarity
- **Image Versions**: Each build creates a new image version - maintain version history
- **Templates are Immutable**: Cannot edit existing templates - must create new template for changes
- **FSLogix Profiles**: Ensure session hosts have correct permissions before first user login
- **Testing**: Always test in development/UAT before production deployment
- **Documentation**: Document all configurations, permissions, and procedures

---

**Checklist Version:** 1.0  
**Last Updated:** [Date]  
**For Questions:** Refer to AVD_CIT_QUICK_START.md and AVD_CIT_UAT_GUIDE.md

