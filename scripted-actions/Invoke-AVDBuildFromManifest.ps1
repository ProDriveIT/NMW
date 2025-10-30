param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'

$cis = Join-Path $RepoRoot "scripted-actions\custom-image-template-scripts"
$ws  = Join-Path $RepoRoot "scripted-actions\windows-scripts"

if (!(Test-Path $ManifestPath)) { throw "Manifest not found: $ManifestPath" }

$manifest = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json

function Run($path, $args = @()) {
    if (Test-Path $path) {
        Write-Host "Running: $path $($args -join ' ')"
        & powershell.exe -ExecutionPolicy Bypass -File $path @args
    }
    else {
        Write-Warning "Missing script: $path"
    }
}

# Features
if ($manifest.features.optimizations) { Run (Join-Path $cis "enable-windows-optimizations.ps1") }
if ($manifest.features.timezoneRedirection) { Run (Join-Path $cis "enable-timezone-redirection.ps1") }
if ($manifest.features.storageSense.disable) { Run (Join-Path $cis "disable-storage-sense.ps1") }

if ($manifest.features.fslogix.enable) {
    if ($manifest.features.fslogix.mode -eq "kerberos") {
        Run (Join-Path $cis "enable-fslogix-kerberos.ps1")
    }
    else {
        Run (Join-Path $cis "install-enable-fslogix.ps1")
    }
}

if ($manifest.features.rdpShortpath.enable) { Run (Join-Path $cis "configure-rdp-shortpath.ps1") }
if ($manifest.features.screenCaptureProtection) { Run (Join-Path $ws "enable-screen-capture-protection.ps1") }

# Language
if ($manifest.features.language.installPacks -and $manifest.features.language.installPacks.Count -gt 0) {
    Run (Join-Path $cis "install-language-packs.ps1") @("--Languages", ($manifest.features.language.installPacks -join ","))
}
if ($manifest.features.language.defaultLocale) {
    Run (Join-Path $cis "set-default-os-language.ps1") @("--Locale", $manifest.features.language.defaultLocale)
}

# Apps
if ($manifest.apps.office.install) { Run (Join-Path $ws "install-m365-apps.ps1") @("--Channel", $manifest.apps.office.channel) }
if ($manifest.apps.teamsNew) { Run (Join-Path $ws "install-microsoft-teams-new.ps1") }

if ($manifest.apps.browsers.edge) { Run (Join-Path $ws "install-edge-choco.ps1") }
if ($manifest.apps.browsers.chrome) { Run (Join-Path $ws "install-chrome-choco.ps1") }
if ($manifest.apps.browsers.firefox) { Run (Join-Path $ws "install-firefox-choco.ps1") }

if ($manifest.apps.tools.notepadpp) { Run (Join-Path $ws "install-notepadpp-choco.ps1") }
if ($manifest.apps.tools.sevenZip) { Run (Join-Path $ws "install-7zip-choco.ps1") }
if ($manifest.apps.tools.vscode) { Run (Join-Path $ws "install-vscode-choco.ps1") }

if ($manifest.apps.onedrivePerMachine) { Run (Join-Path $ws "install-onedrive-per-machine.ps1") }
if ($manifest.apps.zoomVdi) { Run (Join-Path $ws "install-zoom-vdi.ps1") }

if ($manifest.apps.agents.ninjaRmm) { Run (Join-Path $ws "install-ninjarmm-agent.ps1") }
if ($manifest.apps.agents.sophos)   { Run (Join-Path $ws "install-sophos-endpoint.ps1") }

if ($manifest.apps.gpu.nvidiaAzure) { Run (Join-Path $ws "install-nvidia-gpu-driver-azure.ps1") }

Write-Host "Manifest application complete."


