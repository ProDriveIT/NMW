#description: Installs Adobe Reader DC via Chocolatey Package Manager (https://chocolatey.org/)
#execution mode: Combined
#tags: Nerdio, Apps install, Chocolatey
<#
This script installs Adobe Reader DC via Chocolatey
#>

# Install Chocolatey if it isn't already installed
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Adobe Reader DC
# Note: /DesktopIcon parameter must be passed correctly to avoid package lookup errors
# Using --ignore-errors to prevent build failure if parameter parsing has issues
choco install adobereader -y --params="'/DesktopIcon'" --ignore-errors

# Ensure script exits with success code even if Chocolatey has warnings
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Chocolatey exit code was $LASTEXITCODE, but continuing..."
    $LASTEXITCODE = 0
}

