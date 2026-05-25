# =====================================================================
# new-domain.ps1 - Create a new domain (called from inside the
# "domain-maker" meta-domain, or directly).
#
# Steps performed:
#   1. <workspace>/domains/<Folder>/  + CLAUDE.md + memory/INDEX.md + todos.md
#   2. (optional) Obsidian vault NTFS junction: <vault>/<NN>_<Name>
#   3. PowerShell profile patch: function <Shortcut> { ... }   (with backup)
#   4. domain-config.json: append new entry
#   5. <workspace>/domains/<Folder>/.vscode/settings.json   (title + colors)
#
# All paths are read from domain-config.json (single source of truth).
# =====================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$Shortcut,
    [string]$Icon = "📁",
    [string]$Description = "(no description)",
    [string]$Folder,
    [string]$Color = "#1e40af"
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir 'domain-config.json'
if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: domain-config.json not found at: $ConfigPath" -ForegroundColor Red
    Write-Host "Run install.ps1 first." -ForegroundColor Yellow
    exit 1
}
$Config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $Folder) { $Folder = $Name }

# ---- duplicate check ----
$dup = $Config.domains | Where-Object { $_.name -eq $Name -or $_.shortcut -eq $Shortcut -or $_.folder -eq $Folder }
if ($dup) {
    Write-Host "Domain or shortcut already exists: $($dup.name) / $($dup.shortcut)" -ForegroundColor Red
    exit 1
}

# ---- obsidian prefix auto-number (only if vault configured) ----
$useObsidian = -not [string]::IsNullOrWhiteSpace($Config.obsidianRoot) -and (Test-Path $Config.obsidianRoot)
$nextPrefix = $null
$ObsidianLink = $null
if ($useObsidian) {
    $existingPrefixes = $Config.domains |
        Where-Object { $_.obsidianPrefix } |
        ForEach-Object { [int]$_.obsidianPrefix } |
        Sort-Object -Descending
    $nextPrefix = if ($existingPrefixes.Count -gt 0) { ($existingPrefixes[0] + 1).ToString('00') } else { '01' }
    $ObsidianLink = Join-Path $Config.obsidianRoot ("{0}_{1}" -f $nextPrefix, $Name)
}

$DomainPath = Join-Path $Config.domainsRoot $Folder

Write-Host ""
Write-Host "  Create domain: $Icon $Name" -ForegroundColor Cyan
Write-Host "  Shortcut:      $Shortcut" -ForegroundColor Cyan
Write-Host "  Folder:        $DomainPath" -ForegroundColor DarkGray
if ($useObsidian) {
    Write-Host "  Obsidian:      $ObsidianLink" -ForegroundColor DarkGray
} else {
    Write-Host "  Obsidian:      (not configured - skipped)" -ForegroundColor DarkGray
}
Write-Host ""

# ---- 1. domain folder + base files ----
if (Test-Path $DomainPath) {
    Write-Host "  [warn] domain folder already exists - keeping existing, filling missing." -ForegroundColor Yellow
} else {
    New-Item -Path $DomainPath -ItemType Directory -Force | Out-Null
    Write-Host "  [1/5] domain folder created" -ForegroundColor Green
}

$memoryDir = Join-Path $DomainPath 'memory'
if (-not (Test-Path $memoryDir)) { New-Item -Path $memoryDir -ItemType Directory -Force | Out-Null }

$claudeMdPath = Join-Path $DomainPath 'CLAUDE.md'
if (-not (Test-Path $claudeMdPath)) {
    $claudeMd = @"
# $Name domain

## Purpose

$Description

## Memory index

See ``./memory/INDEX.md``.

## Safety rules

- Confirm before deleting memory / CLAUDE.md / settings.json.
- Never hardcode credentials. Use ``.env``.
"@
    Set-Content -Path $claudeMdPath -Value $claudeMd -Encoding UTF8
}

$indexPath = Join-Path $memoryDir 'INDEX.md'
if (-not (Test-Path $indexPath)) {
    $index = @"
# $Name memory index

(empty - fill as you work)
"@
    Set-Content -Path $indexPath -Value $index -Encoding UTF8
}

$todosPath = Join-Path $DomainPath 'todos.md'
if (-not (Test-Path $todosPath)) {
    $todos = @"
# $Name todos

## In Progress

## Pending

## Done
"@
    Set-Content -Path $todosPath -Value $todos -Encoding UTF8
}

Write-Host "  [1/5] base files created (CLAUDE.md, memory/INDEX.md, todos.md)" -ForegroundColor Green

# ---- 2. Obsidian junction (optional) ----
if ($useObsidian) {
    if (Test-Path $ObsidianLink) {
        Write-Host "  [2/5] obsidian junction already exists - skipped" -ForegroundColor Yellow
    } else {
        $mklinkOut = cmd /c mklink /J "`"$ObsidianLink`"" "`"$DomainPath`"" 2>&1
        if (Test-Path $ObsidianLink) {
            Write-Host "  [2/5] obsidian junction created" -ForegroundColor Green
        } else {
            Write-Host "  [2/5] obsidian junction FAILED - aborting." -ForegroundColor Red
            Write-Host "        cause: $mklinkOut" -ForegroundColor Red
            Write-Host "        manual: cmd /c mklink /J `"$ObsidianLink`" `"$DomainPath`"" -ForegroundColor Yellow
            exit 1
        }
    }
} else {
    Write-Host "  [2/5] obsidian vault not configured - skipped" -ForegroundColor DarkGray
}

# ---- 3. PowerShell profile patch (atomic) ----
$ProfilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (-not (Test-Path $ProfilePath)) {
    Write-Host "  [3/5] PowerShell profile not found - skipped" -ForegroundColor Yellow
    Write-Host "        run install.ps1 to bootstrap it." -ForegroundColor DarkGray
} else {
    $profileContent = Get-Content $ProfilePath -Raw -Encoding UTF8
    $functionDef = "function $Shortcut { & `"`$DomainMakerScripts\cc.ps1`" `"$Name`" @args }"
    if ($profileContent -match "function\s+$([regex]::Escape($Shortcut))\s*\{") {
        Write-Host "  [3/5] shortcut function already in profile - skipped" -ForegroundColor Yellow
    } else {
        $backupPath = "$ProfilePath.bak-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"
        Copy-Item $ProfilePath $backupPath

        # Insert INSIDE the "# === Domain Maker block end ===" marker so that
        # uninstall.ps1 can wipe every shortcut at once by removing the block.
        $endMarker = '# === Domain Maker block end ==='
        if ($profileContent.Contains($endMarker)) {
            $newContent = $profileContent.Replace($endMarker, ($functionDef + "`r`n" + $endMarker))
        } else {
            $newContent = $profileContent.TrimEnd() + "`r`n" + $functionDef + "`r`n"
        }
        $tmpPath = "$ProfilePath.tmp"
        Set-Content -Path $tmpPath -Value $newContent -Encoding UTF8
        Move-Item -Path $tmpPath -Destination $ProfilePath -Force
        Write-Host "  [3/5] profile patched (backup: $backupPath)" -ForegroundColor Green
    }
}

# ---- 4. domain-config.json append ----
$newDomain = [PSCustomObject]@{
    name           = $Name
    shortcut       = $Shortcut
    folder         = $Folder
    obsidianPrefix = $nextPrefix
    icon           = $Icon
    description    = $Description
    color          = $Color
}
$Config.domains = @($Config.domains) + $newDomain
$tmpConfig = "$ConfigPath.tmp"
$Config | ConvertTo-Json -Depth 6 | Set-Content -Path $tmpConfig -Encoding UTF8
Move-Item -Path $tmpConfig -Destination $ConfigPath -Force
Write-Host "  [4/5] domain-config.json updated" -ForegroundColor Green

# ---- 5. VS Code per-domain settings (title + colors) ----
$vscDir = Join-Path $DomainPath '.vscode'
if (-not (Test-Path $vscDir)) { New-Item -Path $vscDir -ItemType Directory -Force | Out-Null }
$vscSettingsPath = Join-Path $vscDir 'settings.json'
if (Test-Path $vscSettingsPath) {
    Write-Host "  [5/5] .vscode/settings.json already exists - skipped" -ForegroundColor Yellow
} else {
    $title = "$Icon $Name  `${separator}  `${rootName}  `${separator}  `${activeEditorShort}"
    $vscSettings = [ordered]@{
        'window.title' = $title
        'terminal.integrated.tabs.title' = "$Icon $Name"
        'workbench.colorCustomizations' = [ordered]@{
            'titleBar.activeBackground' = $Color
            'titleBar.activeForeground' = '#ffffff'
            'titleBar.inactiveBackground' = $Color
            'titleBar.inactiveForeground' = '#e5e7eb'
            'statusBar.background' = $Color
            'statusBar.foreground' = '#ffffff'
            'statusBar.noFolderBackground' = $Color
            'activityBar.background' = $Color
            'activityBar.foreground' = '#ffffff'
            'activityBar.activeBorder' = '#ffffff'
        }
    }
    $vscJson = $vscSettings | ConvertTo-Json -Depth 5
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($vscSettingsPath, $vscJson, $utf8NoBom)
    Write-Host "  [5/5] .vscode/settings.json created (color: $Color)" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Done. Open a new PowerShell terminal and type:" -ForegroundColor Cyan
Write-Host "      $Shortcut" -ForegroundColor Yellow
Write-Host ""
Write-Host "  (To activate in already-open terminals, run: . `$PROFILE)" -ForegroundColor DarkGray
Write-Host ""
