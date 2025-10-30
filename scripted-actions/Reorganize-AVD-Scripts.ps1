#description: Reorganize AVD scripts into a lean baseline, archive extras, and normalize names
#tags: maintenance, AVD, scripts, reorg

param(
    [string]$Root = "C:\Dev\NMW"
)

$ErrorActionPreference = 'Stop'

Write-Host "Reorganizing AVD scripts under $Root ..."

$ws = Join-Path $Root "scripted-actions\windows-scripts"
$cis = Join-Path $Root "scripted-actions\custom-image-template-scripts"
$ar  = Join-Path $Root "scripted-actions\azure-runbooks"
$extras = Join-Path $Root "scripted-actions\extras"

$null = New-Item -ItemType Directory -Path (Join-Path $extras "windows-scripts") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $extras "azure-runbooks") -Force

function Move-ToExtras($path) {
    if (Test-Path $path) {
        $target = $path -replace [regex]::Escape($Root), $extras
        $null = New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
        Write-Host "Archiving: $path -> $target"
        Move-Item -LiteralPath $path -Destination $target -Force
    }
}

function Rename-IfExists($from, $to) {
    if (Test-Path $from) {
        $dir = Split-Path $from -Parent
        $dest = Join-Path $dir $to
        if ($from -ne $dest) {
            Write-Host "Renaming: $from -> $dest"
            Rename-Item -LiteralPath $from -NewName $to -Force
        }
    }
}

# 1) Screen capture protection -> single canonical script
Move-ToExtras (Join-Path $ws "Enable AVD screen capture protection.ps1")
Rename-IfExists (Join-Path $ws "Enable WVD screen capture protection.ps1") "enable-screen-capture-protection.ps1"

# 2) RDP Shortpath -> consolidate to one script in CIT folder
Move-ToExtras (Join-Path $ws "Enable RDP Shortpath.ps1")
Move-ToExtras (Join-Path $ws "Enable RDP Shortpath for Public Networks.ps1")
Rename-IfExists (Join-Path $cis "Configure RDP Shortpath for managed networks.ps1") "configure-rdp-shortpath.ps1"

# 3) Edge optimization -> single script
Move-ToExtras (Join-Path $ws "Optimize Microsoft Edge for WVD.ps1")
Rename-IfExists (Join-Path $ws "Optimize Microsoft Edge for AVD.ps1") "optimize-microsoft-edge.ps1"

# 4) Legacy VDOT versions
@(
  "Virtual Desktop Optimizations (1909).ps1",
  "Virtual Desktop Optimizations (2004).ps1",
  "Virtual Desktop Optimizations (20H2).ps1"
) | ForEach-Object { Move-ToExtras (Join-Path $ws $_) }

# 5) Risky/special-case items to extras
Move-ToExtras (Join-Path $ws "Grant user local admin rights.ps1")
Move-ToExtras (Join-Path $ws "Windows 11 22H2 - Modify Sysprep.ps1")
Move-ToExtras (Join-Path $ws "Update Windows 10.ps1")
Move-ToExtras (Join-Path $ws "Update Windows 11.ps1")
Move-ToExtras (Join-Path $ws "Restart AVD Agent.ps1")

# 6) Keep current optimization script in CIT
Rename-IfExists (Join-Path $cis "Enable Windows optimizations for AVD.ps1") "enable-windows-optimizations.ps1"

# 7) FSLogix scripts (keep both, clarify names)
Rename-IfExists (Join-Path $cis "Install and enable FSLogix.ps1") "install-enable-fslogix.ps1"
Rename-IfExists (Join-Path $cis "Enable FSLogix with Kerberos.ps1") "enable-fslogix-kerberos.ps1"

# 8) Language & locale
Rename-IfExists (Join-Path $cis "Install language packs.ps1") "install-language-packs.ps1"
Rename-IfExists (Join-Path $cis "Set default OS language.ps1") "set-default-os-language.ps1"

# 9) Sessions, storage sense, MSIX updates, Teams/Office configs
Rename-IfExists (Join-Path $cis "Configure session timeouts.ps1") "configure-session-timeouts.ps1"
Rename-IfExists (Join-Path $cis "Enable time zone redirection.ps1") "enable-timezone-redirection.ps1"
Rename-IfExists (Join-Path $cis "Disable Storage sense.ps1") "disable-storage-sense.ps1"
Rename-IfExists (Join-Path $cis "Disable MSIX app attach auto updates.ps1") "disable-msix-app-attach-auto-updates.ps1"
Rename-IfExists (Join-Path $cis "Configure Microsoft Teams optimizations.ps1") "configure-teams-optimizations.ps1"
Rename-IfExists (Join-Path $cis "Configure Multi Media Redirection.ps1") "configure-mmr.ps1"
Rename-IfExists (Join-Path $cis "Configure Microsoft Office packages.ps1") "configure-office.ps1"
Rename-IfExists (Join-Path $cis "Remove AppX packages.ps1") "remove-appx-packages.ps1"
Rename-IfExists (Join-Path $cis "Admin Sysprep.ps1") "admin-sysprep.ps1"

# 10) App installers (normalize naming; archive legacy Teams)
Rename-IfExists (Join-Path $ws "Install Microsoft Teams (new).ps1") "install-microsoft-teams-new.ps1"
Move-ToExtras (Join-Path $ws "Install Microsoft Teams.ps1")

Rename-IfExists (Join-Path $ws "Install Microsoft Edge via Chocolatey.ps1") "install-edge-choco.ps1"
Rename-IfExists (Join-Path $ws "Install Google Chrome via Chocolatey.ps1") "install-chrome-choco.ps1"
Rename-IfExists (Join-Path $ws "Install Mozilla Firefox via Chocolatey.ps1") "install-firefox-choco.ps1"
Rename-IfExists (Join-Path $ws "Install Notepad++ via Chocolatey.ps1") "install-notepadpp-choco.ps1"
Rename-IfExists (Join-Path $ws "Install 7zip via Chocolatey.ps1") "install-7zip-choco.ps1"
Rename-IfExists (Join-Path $ws "Install VSCode via Chocolatey.ps1") "install-vscode-choco.ps1"
Rename-IfExists (Join-Path $ws "Install Microsoft 365 Office Apps.ps1") "install-m365-apps.ps1"
Rename-IfExists (Join-Path $ws "Install OneDrive Sync Per Machine.ps1") "install-onedrive-per-machine.ps1"
Rename-IfExists (Join-Path $ws "Install Zoom VDI client.ps1") "install-zoom-vdi.ps1"
Rename-IfExists (Join-Path $ws "Install Remote Display Analyzer.ps1") "install-remote-display-analyzer.ps1"

# 11) Agents & GPU
Rename-IfExists (Join-Path $ws "Install NinjaRMM agent.ps1") "install-ninjarmm-agent.ps1"
Rename-IfExists (Join-Path $ws "Install Sophos Server Endpoint Protection agent.ps1") "install-sophos-endpoint.ps1"
Rename-IfExists (Join-Path $ws "Install NVIDIA GPU Driver (Azure Local).ps1") "install-nvidia-gpu-driver-azure.ps1"

# 12) Misc to extras if not widely used
Move-ToExtras (Join-Path $ws "Configure clipboard transfer.ps1")
Move-ToExtras (Join-Path $ws "Disable Session Time Limits.ps1")

# 13) Azure runbooks: archive "fix_*" helpers
@( "Fix_Storage_Access_403.ps1", "Fix_Storage_Access_Simple.ps1", "Fix_Storage_Container.ps1" ) |
  ForEach-Object { Move-ToExtras (Join-Path $ar $_) }

Write-Host "Reorganization complete. Review archived files under: $extras"


