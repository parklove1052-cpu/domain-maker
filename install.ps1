# =====================================================================
# install.ps1 - Domain Maker installer
# =====================================================================
# One-time setup. Run from the cloned repo root:
#
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# What it does (idempotent):
#   1. Asks for: workspace root, workspace name, (optional) Obsidian vault,
#      shortcut for the meta-domain (default: "make").
#   2. Copies scripts/ to <workspace>/scripts/ and materializes
#      domain-config.json with the chosen paths.
#   3. Copies templates/domain-maker/ to <workspace>/domains/<MetaShortcut>/.
#   4. Patches PowerShell profile: function <MetaShortcut> { ... }
#   5. (Optional) Registers statusLine in Claude Code global settings.
#   6. (Optional) Creates an Obsidian junction for the meta-domain.
# =====================================================================

[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [string]$WorkspaceName,
    [string]$ObsidianVault,
    [string]$MetaShortcut = 'make',
    [string]$MetaName = 'domain-maker',
    [switch]$RegisterStatusLine,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Read-Default {
    param([string]$Prompt, [string]$Default)
    if ($NonInteractive) { return $Default }
    $shown = if ($Default) { " [$Default]" } else { "" }
    $val = Read-Host ($Prompt + $shown)
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default }
    return $val.Trim()
}

Write-Host ""
Write-Host "  ┌────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │   Domain Maker - installer                 │" -ForegroundColor Cyan
Write-Host "  └────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""

# ---- gather inputs ---------------------------------------------------
if (-not $WorkspaceRoot) {
    $defaultWs = Join-Path $env:USERPROFILE 'claude-workspace'
    $WorkspaceRoot = Read-Default "Workspace root (folder for all domains)" $defaultWs
}
$WorkspaceRoot = [System.IO.Path]::GetFullPath($WorkspaceRoot)

if (-not $WorkspaceName) {
    $WorkspaceName = Read-Default "Workspace display name (shown in statusLine when no domain matches)" (Split-Path -Leaf $WorkspaceRoot)
}

if (-not $ObsidianVault -and -not $NonInteractive) {
    $useObs = Read-Default "Use an Obsidian vault for cross-domain memory? (y/N)" "N"
    if ($useObs -match '^[Yy]') {
        $ObsidianVault = Read-Default "  Obsidian vault path" ""
    }
}
if ($ObsidianVault) { $ObsidianVault = [System.IO.Path]::GetFullPath($ObsidianVault) }

$MetaShortcut = Read-Default "Shortcut for the meta-domain (typed in terminal to create new domains)" $MetaShortcut
$MetaName     = Read-Default "Folder/name for the meta-domain" $MetaName

if (-not $RegisterStatusLine -and -not $NonInteractive) {
    $rs = Read-Default "Register Claude Code statusLine? (Y/n)" "Y"
    $RegisterStatusLine = ($rs -match '^[Yy]')
}

# ---- derive paths ----------------------------------------------------
$DomainsRoot     = Join-Path $WorkspaceRoot 'domains'
$WorkspaceScripts = Join-Path $WorkspaceRoot 'scripts'
$MetaDomainPath  = Join-Path $DomainsRoot $MetaName

Write-Host ""
Write-Host "  Settings:" -ForegroundColor Cyan
Write-Host "    workspace root :  $WorkspaceRoot" -ForegroundColor DarkGray
Write-Host "    workspace name :  $WorkspaceName" -ForegroundColor DarkGray
Write-Host "    obsidian vault :  $(if ($ObsidianVault) { $ObsidianVault } else { '(skip)' })" -ForegroundColor DarkGray
Write-Host "    meta shortcut  :  $MetaShortcut" -ForegroundColor DarkGray
Write-Host "    meta folder    :  $MetaName" -ForegroundColor DarkGray
Write-Host "    statusLine     :  $(if ($RegisterStatusLine) { 'register' } else { 'skip' })" -ForegroundColor DarkGray
Write-Host ""

if (-not $NonInteractive) {
    $go = Read-Default "Proceed? (Y/n)" "Y"
    if ($go -notmatch '^[Yy]') { Write-Host "  cancelled" -ForegroundColor Yellow; exit 0 }
}

# ---- 1. create directories ------------------------------------------
foreach ($p in @($WorkspaceRoot, $DomainsRoot, $WorkspaceScripts)) {
    if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
}
Write-Host "  [1/6] workspace folders ready" -ForegroundColor Green

# ---- 2. copy scripts -------------------------------------------------
$srcScripts = Join-Path $RepoRoot 'scripts'
foreach ($f in @('new-domain.ps1', 'cc.ps1', 'statusline.ps1')) {
    Copy-Item -Path (Join-Path $srcScripts $f) -Destination (Join-Path $WorkspaceScripts $f) -Force
}
Write-Host "  [2/6] scripts copied -> $WorkspaceScripts" -ForegroundColor Green

# ---- 3. materialize domain-config.json ------------------------------
$ConfigDest = Join-Path $WorkspaceScripts 'domain-config.json'
if (Test-Path $ConfigDest) {
    Write-Host "  [3/6] domain-config.json already exists - kept as-is" -ForegroundColor Yellow
} else {
    $template = Get-Content (Join-Path $srcScripts 'domain-config.template.json') -Raw -Encoding UTF8
    $rendered = $template `
        -replace '\{\{WORKSPACE_NAME\}\}', ([regex]::Escape($WorkspaceName) -replace '\\','\\') `
        -replace '\{\{WORKSPACE_ROOT\}\}', ($WorkspaceRoot -replace '\\','\\') `
        -replace '\{\{DOMAINS_ROOT\}\}', ($DomainsRoot -replace '\\','\\') `
        -replace '\{\{OBSIDIAN_ROOT\}\}', ($ObsidianVault -replace '\\','\\')

    # Patch the bundled meta-domain entry to match user's chosen name/shortcut
    $parsed = $rendered | ConvertFrom-Json
    if ($parsed.domains -and $parsed.domains.Count -gt 0) {
        $parsed.domains[0].name     = $MetaName
        $parsed.domains[0].shortcut = $MetaShortcut
        $parsed.domains[0].folder   = $MetaName
    }
    $parsed | ConvertTo-Json -Depth 6 | Set-Content -Path $ConfigDest -Encoding UTF8
    Write-Host "  [3/6] domain-config.json generated" -ForegroundColor Green
}

# ---- 4. create the meta-domain folder -------------------------------
if (-not (Test-Path $MetaDomainPath)) { New-Item -Path $MetaDomainPath -ItemType Directory -Force | Out-Null }
$metaMem = Join-Path $MetaDomainPath 'memory'
if (-not (Test-Path $metaMem)) { New-Item -Path $metaMem -ItemType Directory -Force | Out-Null }

$srcMeta = Join-Path $RepoRoot 'templates\domain-maker'
$claudeMdDest = Join-Path $MetaDomainPath 'CLAUDE.md'
if (-not (Test-Path $claudeMdDest)) {
    Copy-Item -Path (Join-Path $srcMeta 'CLAUDE.md') -Destination $claudeMdDest -Force
}
$indexDest = Join-Path $metaMem 'INDEX.md'
if (-not (Test-Path $indexDest)) {
    Copy-Item -Path (Join-Path $srcMeta 'memory\INDEX.md') -Destination $indexDest -Force
}
$todosDest = Join-Path $MetaDomainPath 'todos.md'
if (-not (Test-Path $todosDest)) {
    Copy-Item -Path (Join-Path $srcMeta 'todos.md') -Destination $todosDest -Force
}
Write-Host "  [4/6] meta-domain created -> $MetaDomainPath" -ForegroundColor Green

# ---- 5. patch PowerShell profile ------------------------------------
$ProfileDir = "$env:USERPROFILE\Documents\WindowsPowerShell"
$ProfilePath = Join-Path $ProfileDir 'Microsoft.PowerShell_profile.ps1'
if (-not (Test-Path $ProfileDir)) { New-Item -Path $ProfileDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $ProfilePath)) { New-Item -Path $ProfilePath -ItemType File -Force | Out-Null }

$profileText = Get-Content $ProfilePath -Raw -Encoding UTF8
if (-not $profileText) { $profileText = '' }

$marker = '# === Domain Maker block ==='
$endMarker = '# === Domain Maker block end ==='
$blockLines = @(
    $marker,
    ('$DomainMakerScripts = "' + $WorkspaceScripts + '"'),
    '$OutputEncoding = [System.Text.Encoding]::UTF8',
    ('function ' + $MetaShortcut + ' { & "$DomainMakerScripts\cc.ps1" "' + $MetaName + '" @args }'),
    'function cc { param([string]$d) & "$DomainMakerScripts\cc.ps1" $d @args }',
    $endMarker
)
$block = $blockLines -join "`r`n"

if ($profileText -match [regex]::Escape($marker)) {
    Write-Host "  [5/6] PowerShell profile already contains the Domain Maker block - skipped" -ForegroundColor Yellow
} else {
    $backupPath = "$ProfilePath.bak-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"
    if (Test-Path $ProfilePath) { Copy-Item $ProfilePath $backupPath }
    $newContent = $profileText.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
    $tmpPath = "$ProfilePath.tmp"
    Set-Content -Path $tmpPath -Value $newContent -Encoding UTF8
    Move-Item -Path $tmpPath -Destination $ProfilePath -Force
    Write-Host "  [5/6] PowerShell profile patched (backup: $backupPath)" -ForegroundColor Green
}

# ---- 6. statusLine (optional) + obsidian junction -------------------
if ($RegisterStatusLine) {
    $claudeSettingsDir = Join-Path $env:USERPROFILE '.claude'
    if (-not (Test-Path $claudeSettingsDir)) { New-Item -Path $claudeSettingsDir -ItemType Directory -Force | Out-Null }
    $claudeSettings = Join-Path $claudeSettingsDir 'settings.json'
    $statusLineCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$WorkspaceScripts\statusline.ps1`""

    if (Test-Path $claudeSettings) {
        try {
            $obj = Get-Content $claudeSettings -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Write-Host "  [6/6] WARNING: ~/.claude/settings.json is not valid JSON - leave it alone." -ForegroundColor Yellow
            $obj = $null
        }
    } else {
        $obj = [PSCustomObject]@{}
    }

    if ($obj -ne $null) {
        $sl = [PSCustomObject]@{ type = 'command'; command = $statusLineCmd }
        if ($obj.PSObject.Properties.Match('statusLine').Count -gt 0) {
            $obj.statusLine = $sl
        } else {
            $obj | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue $sl -Force
        }
        $obj | ConvertTo-Json -Depth 10 | Set-Content -Path $claudeSettings -Encoding UTF8
        Write-Host "  [6/6] Claude Code statusLine registered" -ForegroundColor Green
    }
} else {
    Write-Host "  [6/6] statusLine registration skipped" -ForegroundColor DarkGray
}

# Obsidian junction for meta-domain
if ($ObsidianVault) {
    if (-not (Test-Path $ObsidianVault)) {
        New-Item -Path $ObsidianVault -ItemType Directory -Force | Out-Null
    }
    $junction = Join-Path $ObsidianVault "01_$MetaName"
    if (Test-Path $junction) {
        Write-Host "       obsidian junction exists - skipped" -ForegroundColor Yellow
    } else {
        cmd /c mklink /J "`"$junction`"" "`"$MetaDomainPath`"" | Out-Null
        if (Test-Path $junction) {
            Write-Host "       obsidian junction created: $junction" -ForegroundColor Green
        } else {
            Write-Host "       obsidian junction failed (manual: cmd /c mklink /J `"$junction`" `"$MetaDomainPath`")" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "  ✓ Installation complete." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next:" -ForegroundColor Cyan
Write-Host "    1. Open a NEW PowerShell terminal." -ForegroundColor White
Write-Host "    2. Type:  $MetaShortcut" -ForegroundColor Yellow
Write-Host "    3. Inside Claude Code, say: 'make a new <X> domain'." -ForegroundColor White
Write-Host ""
Write-Host '  (In an already-open terminal, run: . $PROFILE  to load the shortcut.)' -ForegroundColor DarkGray
Write-Host ""
