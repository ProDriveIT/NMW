# Using NMW Scripts from GitHub

This guide explains how to call scripts from your NMW GitHub repository from anywhere, without needing to clone the repository locally.

## Method 1: Using Invoke-NMWScript Helper Script (Recommended)

The `Invoke-NMWScript.ps1` helper script downloads and executes any script from your GitHub repository.

### Basic Usage

```powershell
# Download and run a script
.\Invoke-NMWScript.ps1 -ScriptPath "windows-scripts/install-m365-apps.ps1"

# Specify GitHub details explicitly
.\Invoke-NMWScript.ps1 -ScriptPath "windows-scripts/install-m365-apps.ps1" -GitHubUser "yourusername" -Branch "main"

# Run a script from a different directory
.\Invoke-NMWScript.ps1 -ScriptPath "custom-image-template-scripts/admin-sysprep.ps1"

# Run an Azure runbook script
.\Invoke-NMWScript.ps1 -ScriptPath "azure-runbooks/Update AVD Agent.ps1"
```

### Making It Available Globally

**Option A: Add to PowerShell Profile**

Add this function to your PowerShell profile (`$PROFILE`):

```powershell
function Invoke-NMWScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string]$GitHubUser = "yourusername",  # Change this to your GitHub username
        [string]$Repository = "NMW",
        [string]$Branch = "main",
        [hashtable]$Arguments = @{}
    )
    
    $rawUrl = "https://raw.githubusercontent.com/$GitHubUser/$Repository/$Branch/scripted-actions/$($ScriptPath -replace '^scripted-actions/', '')"
    $scriptContent = Invoke-WebRequest -Uri $rawUrl -UseBasicParsing
    $tempScript = Join-Path $env:TEMP "NMW_$(Split-Path -Leaf $ScriptPath)_$(Get-Random).ps1"
    $scriptContent.Content | Out-File -FilePath $tempScript -Encoding UTF8
    
    try {
        if ($Arguments.Count -gt 0) {
            & powershell.exe -ExecutionPolicy Bypass -File $tempScript @Arguments
        } else {
            & powershell.exe -ExecutionPolicy Bypass -File $tempScript
        }
    }
    finally {
        Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
    }
}
```

Then you can use it from anywhere:
```powershell
Invoke-NMWScript -ScriptPath "windows-scripts/install-m365-apps.ps1"
```

**Option B: Install as Module**

1. Copy `Invoke-NMWScript.ps1` to your PowerShell modules directory:
   ```powershell
   $modulePath = "$env:ProgramFiles\WindowsPowerShell\Modules\NMWScripts"
   New-Item -ItemType Directory -Path $modulePath -Force
   Copy-Item ".\Invoke-NMWScript.ps1" "$modulePath\Invoke-NMWScript.ps1"
   ```

2. Import the module:
   ```powershell
   Import-Module NMWScripts
   ```

## Method 2: Direct Raw GitHub URLs

You can also download and execute scripts directly using raw GitHub URLs:

```powershell
# One-liner to download and execute
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yourusername/NMW/main/scripted-actions/windows-scripts/install-m365-apps.ps1" -UseBasicParsing).Content

# Download first, then execute (allows parameter passing)
$scriptUrl = "https://raw.githubusercontent.com/yourusername/NMW/main/scripted-actions/windows-scripts/install-m365-apps.ps1"
$scriptContent = (Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content
$tempFile = Join-Path $env:TEMP "temp_script.ps1"
$scriptContent | Out-File $tempFile
& $tempFile
Remove-Item $tempFile
```

### URL Format

The general format for raw GitHub URLs is:
```
https://raw.githubusercontent.com/{username}/{repository}/{branch}/scripted-actions/{path-to-script}
```

Examples:
- `https://raw.githubusercontent.com/yourusername/NMW/main/scripted-actions/windows-scripts/install-m365-apps.ps1`
- `https://raw.githubusercontent.com/yourusername/NMW/main/scripted-actions/custom-image-template-scripts/admin-sysprep.ps1`
- `https://raw.githubusercontent.com/yourusername/NMW/main/scripted-actions/azure-runbooks/Update AVD Agent.ps1`

## Method 3: Use in Azure Automation / Runbooks

For Azure Automation runbooks, you can use the raw URLs directly:

```powershell
# Download and dot-source
$scriptUrl = "https://raw.githubusercontent.com/yourusername/NMW/main/scripted-actions/windows-scripts/install-m365-apps.ps1"
Invoke-Expression (Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content
```

## Method 4: Use in Nerdio Manager Scripted Actions

When configuring scripted actions in Nerdio Manager, you can use the raw GitHub URLs directly in the script URI field:

```
https://raw.githubusercontent.com/yourusername/NMW/main/scripted-actions/windows-scripts/install-m365-apps.ps1
```

## Important Notes

1. **Public Repository Required**: These methods work best if your repository is public. For private repos, you'll need:
   - GitHub Personal Access Token (PAT) for authentication
   - Or use Azure Storage with SAS tokens (as currently implemented)

2. **Branch Protection**: Consider using a specific branch (like `main` or `production`) rather than always using `latest` to ensure stability.

3. **Execution Policy**: Scripts are executed with `ExecutionPolicy Bypass`. Ensure you trust the source.

4. **Internet Connectivity**: These methods require internet connectivity to download scripts.

5. **Error Handling**: The helper script includes error handling, but direct URL usage may require additional error checking.

## Quick Reference

| Scenario | Method | Example |
|----------|--------|---------|
| Local execution | Invoke-NMWScript | `Invoke-NMWScript -ScriptPath "windows-scripts/install-m365-apps.ps1"` |
| One-off execution | Direct URL | `Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/..." -UseBasicParsing).Content` |
| Azure Image Builder | Script URI | Use raw URL in `scriptUri` parameter |
| Nerdio Manager | Script URI | Use raw URL in scripted action configuration |
| Azure Automation | Download & Execute | Use `Invoke-WebRequest` with raw URL |

## Troubleshooting

**Issue**: "Could not detect GitHub user from git remote"
- **Solution**: Provide `-GitHubUser` parameter explicitly

**Issue**: "404 Not Found"
- **Solution**: Verify the repository name, branch, and script path are correct
- Ensure the repository is public or you have proper authentication

**Issue**: "Execution Policy prevents running scripts"
- **Solution**: The helper script uses `ExecutionPolicy Bypass`, but if using direct URL, wrap in: `powershell.exe -ExecutionPolicy Bypass -Command "..."`

