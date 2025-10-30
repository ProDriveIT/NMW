### Script reorganization map

- windows-scripts/Enable WVD screen capture protection.ps1 -> windows-scripts/enable-screen-capture-protection.ps1
- windows-scripts/Enable AVD screen capture protection.ps1 -> extras/windows-scripts/Enable AVD screen capture protection.ps1

- windows-scripts/Enable RDP Shortpath.ps1 -> extras/windows-scripts/Enable RDP Shortpath.ps1
- windows-scripts/Enable RDP Shortpath for Public Networks.ps1 -> extras/windows-scripts/Enable RDP Shortpath for Public Networks.ps1
- custom-image-template-scripts/Configure RDP Shortpath for managed networks.ps1 -> custom-image-template-scripts/configure-rdp-shortpath.ps1

- windows-scripts/Optimize Microsoft Edge for WVD.ps1 -> extras/windows-scripts/Optimize Microsoft Edge for WVD.ps1
- windows-scripts/Optimize Microsoft Edge for AVD.ps1 -> windows-scripts/optimize-microsoft-edge.ps1

- windows-scripts/Virtual Desktop Optimizations (1909|2004|20H2).ps1 -> extras/windows-scripts/<same-filename>

- windows-scripts/Grant user local admin rights.ps1 -> extras/windows-scripts/Grant user local admin rights.ps1
- windows-scripts/Windows 11 22H2 - Modify Sysprep.ps1 -> extras/windows-scripts/Windows 11 22H2 - Modify Sysprep.ps1
- windows-scripts/Update Windows 10.ps1 -> extras/windows-scripts/Update Windows 10.ps1
- windows-scripts/Update Windows 11.ps1 -> extras/windows-scripts/Update Windows 11.ps1
- windows-scripts/Restart AVD Agent.ps1 -> extras/windows-scripts/Restart AVD Agent.ps1

- custom-image-template-scripts/Enable Windows optimizations for AVD.ps1 -> custom-image-template-scripts/enable-windows-optimizations.ps1

- custom-image-template-scripts/Install and enable FSLogix.ps1 -> custom-image-template-scripts/install-enable-fslogix.ps1
- custom-image-template-scripts/Enable FSLogix with Kerberos.ps1 -> custom-image-template-scripts/enable-fslogix-kerberos.ps1

- custom-image-template-scripts/Install language packs.ps1 -> custom-image-template-scripts/install-language-packs.ps1
- custom-image-template-scripts/Set default OS language.ps1 -> custom-image-template-scripts/set-default-os-language.ps1
- custom-image-template-scripts/Configure session timeouts.ps1 -> custom-image-template-scripts/configure-session-timeouts.ps1
- custom-image-template-scripts/Enable time zone redirection.ps1 -> custom-image-template-scripts/enable-timezone-redirection.ps1
- custom-image-template-scripts/Disable Storage sense.ps1 -> custom-image-template-scripts/disable-storage-sense.ps1
- custom-image-template-scripts/Disable MSIX app attach auto updates.ps1 -> custom-image-template-scripts/disable-msix-app-attach-auto-updates.ps1
- custom-image-template-scripts/Configure Microsoft Teams optimizations.ps1 -> custom-image-template-scripts/configure-teams-optimizations.ps1
- custom-image-template-scripts/Configure Multi Media Redirection.ps1 -> custom-image-template-scripts/configure-mmr.ps1
- custom-image-template-scripts/Configure Microsoft Office packages.ps1 -> custom-image-template-scripts/configure-office.ps1
- custom-image-template-scripts/Remove AppX packages.ps1 -> custom-image-template-scripts/remove-appx-packages.ps1
- custom-image-template-scripts/Admin Sysprep.ps1 -> custom-image-template-scripts/admin-sysprep.ps1

- windows-scripts/Install Microsoft Teams (new).ps1 -> windows-scripts/install-microsoft-teams-new.ps1
- windows-scripts/Install Microsoft Teams.ps1 -> extras/windows-scripts/Install Microsoft Teams.ps1

- App installers renamed to kebab-case in windows-scripts/: install-edge-choco.ps1, install-chrome-choco.ps1, install-firefox-choco.ps1, install-notepadpp-choco.ps1, install-7zip-choco.ps1, install-vscode-choco.ps1, install-m365-apps.ps1, install-onedrive-per-machine.ps1, install-zoom-vdi.ps1, install-remote-display-analyzer.ps1

- Agents & GPU renamed in windows-scripts/: install-ninjarmm-agent.ps1, install-sophos-endpoint.ps1, install-nvidia-gpu-driver-azure.ps1

- Archived misc to extras: windows-scripts/Configure clipboard transfer.ps1, windows-scripts/Disable Session Time Limits.ps1

- Azure runbooks archived to extras: Fix_Storage_Access_403.ps1, Fix_Storage_Access_Simple.ps1, Fix_Storage_Container.ps1

Notes
- Run `scripted-actions/Reorganize-AVD-Scripts.ps1` to apply changes. Review `scripted-actions/extras` for archived items.

