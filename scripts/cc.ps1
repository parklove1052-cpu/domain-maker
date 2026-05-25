# =====================================================================
# cc.ps1 - Enter a domain + resume previous Claude Code sessions
# =====================================================================
# Usage:
#   cc.ps1 <name-or-shortcut>          → show session-picker TUI
#   cc.ps1 <name-or-shortcut> -Auto    → resume the latest session (no menu)
#   cc.ps1                              → show domain-picker first
# =====================================================================

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$DomainQuery,
    [int]$Index,
    [switch]$Auto
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir 'domain-config.json'
$ProjectsRoot = Join-Path $env:USERPROFILE '.claude\projects'

if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: domain-config.json not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$Config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Select-Domain {
    param([string]$Query, [int]$Idx)

    if ($Idx -gt 0) {
        if ($Idx -le $Config.domains.Count) { return $Config.domains[$Idx - 1] }
        Write-Host "Index out of range: $Idx (1~$($Config.domains.Count))" -ForegroundColor Red
        exit 1
    }

    if ($Query) {
        $match = $Config.domains | Where-Object {
            $_.name -eq $Query -or $_.shortcut -eq $Query -or $_.folder -eq $Query
        } | Select-Object -First 1
        if ($match) { return $match }
        Write-Host "Domain not found: $Query" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │   Claude Code - pick a domain           │" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $Config.domains.Count; $i++) {
        $d = $Config.domains[$i]
        $line = "    [{0}] {1} {2}" -f ($i + 1), $d.icon, $d.name
        Write-Host $line -ForegroundColor White
        Write-Host ("         shortcut: {0,-10}  {1}" -f $d.shortcut, $d.description) -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "    [Q] cancel" -ForegroundColor DarkGray
    Write-Host ""
    $sel = Read-Host "  number"
    if ($sel -match '^[Qq]$' -or $sel -eq '') { exit 0 }
    $idx = 0
    if (-not [int]::TryParse($sel, [ref]$idx)) {
        Write-Host "bad input" -ForegroundColor Red; exit 1
    }
    if ($idx -lt 1 -or $idx -gt $Config.domains.Count) {
        Write-Host "out of range" -ForegroundColor Red; exit 1
    }
    return $Config.domains[$idx - 1]
}

$Domain = Select-Domain -Query $DomainQuery -Idx $Index

$DomainPath = Join-Path $Config.domainsRoot $Domain.folder
if (-not (Test-Path $DomainPath)) {
    Write-Host "Domain folder does not exist: $DomainPath" -ForegroundColor Red
    Write-Host "Create it from the domain-maker meta domain first." -ForegroundColor Yellow
    exit 1
}

# Window title + tab name for visual identification
$DomainLabel = "$($Domain.icon) $($Domain.name)"
$Host.UI.RawUI.WindowTitle = $DomainLabel
[Console]::Write(("{0}]0;{1}{2}" -f [char]27, $DomainLabel, [char]7))

# PowerShell prompt prefix that survives after claude exits
$global:DomainMakerLabel = $DomainLabel
function global:prompt {
    $esc = [char]27
    $box = "$esc[1m$esc[48;2;30;64;175m$esc[97m"
    $reset = "$esc[0m"
    "$box $global:DomainMakerLabel $reset PS $($PWD.ProviderPath)> "
}

# ---------------------------------------------------------------------
# Collect past sessions for this domain by reading jsonl cwd fields.
# Matching on jsonl content is more reliable than directory-name parsing.
# ---------------------------------------------------------------------
function Get-DomainSessions {
    param([string]$DomainCwd)

    if (-not (Test-Path $ProjectsRoot)) { return @() }

    $normalizedTarget = $DomainCwd.TrimEnd('\')
    $jsonlFiles = Get-ChildItem $ProjectsRoot -Recurse -Filter '*.jsonl' -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 50

    $sessions = @()
    foreach ($f in $jsonlFiles) {
        try {
            $reader = [System.IO.StreamReader]::new($f.FullName, [System.Text.Encoding]::UTF8)
            $sessionId = $null
            $sessionCwd = $null
            $firstUserMsg = $null
            $timestamp = $null
            $aiTitle = $null
            $lineCount = 0
            while ($null -ne ($line = $reader.ReadLine()) -and $lineCount -lt 50) {
                $lineCount++
                if (-not $sessionId -and $line -match '"sessionId":"([0-9a-f-]+)"') {
                    $sessionId = $Matches[1]
                }
                if (-not $sessionCwd -and $line -match '"cwd":"([^"]+)"') {
                    $sessionCwd = $Matches[1] -replace '\\\\', '\'
                }
                if (-not $aiTitle -and $line -match '"aiTitle":"((?:\\.|[^"\\])*)"') {
                    $aiTitle = $Matches[1] -replace '\\"','"' -replace '\\\\','\'
                }
                if (-not $firstUserMsg -and $line -match '"type":"user"' -and $line -match '"content":"((?:\\.|[^"\\])*)"') {
                    $firstUserMsg = $Matches[1] -replace '\\"','"' -replace '\\\\','\' -replace '\\n',' '
                    if ($line -match '"timestamp":"([^"]+)"') { $timestamp = $Matches[1] }
                }
                if ($sessionId -and $sessionCwd -and ($firstUserMsg -or $aiTitle)) { break }
            }
            $reader.Close()

            if (-not $sessionId -or -not $sessionCwd) { continue }
            if ($sessionCwd.TrimEnd('\') -ne $normalizedTarget) { continue }

            $title = if ($aiTitle) { $aiTitle } elseif ($firstUserMsg) { $firstUserMsg } else { '(untitled)' }
            if ($title.Length -gt 50) { $title = $title.Substring(0, 50) + '…' }

            $ts = if ($timestamp) {
                try { [DateTime]::Parse($timestamp) } catch { $f.LastWriteTime }
            } else { $f.LastWriteTime }

            $sessions += [PSCustomObject]@{
                SessionId = $sessionId
                Title     = $title
                Timestamp = $ts
                FilePath  = $f.FullName
            }
        } catch {
            continue
        }
    }
    return $sessions | Sort-Object -Property Timestamp -Descending
}

Write-Host ""
Write-Host "  $($Domain.icon) $($Domain.name)  searching sessions..." -ForegroundColor DarkGray

$sessions = Get-DomainSessions -DomainCwd $DomainPath

function Start-NewSession {
    Write-Host ""
    Write-Host "  $($Domain.icon) $($Domain.name)  new session..." -ForegroundColor Green
    Set-Location $DomainPath
    & claude --dangerously-skip-permissions
}

function Resume-Session {
    param([string]$SessionId)
    Write-Host ""
    Write-Host "  $($Domain.icon) $($Domain.name)  resume: $SessionId" -ForegroundColor Green
    Set-Location $DomainPath
    & claude --dangerously-skip-permissions --resume $SessionId
}

if ($sessions.Count -eq 0) {
    Write-Host "  No saved sessions. Starting a fresh session." -ForegroundColor DarkGray
    Start-NewSession
    exit 0
}

if ($Auto) {
    Resume-Session -SessionId $sessions[0].SessionId
    exit 0
}

# TUI
Write-Host ""
Write-Host "  ┌─────────────────────────────────────────┐" -ForegroundColor Green
Write-Host ("  │   {0} {1} - pick a session" -f $Domain.icon, $Domain.name) -ForegroundColor Green
Write-Host "  └─────────────────────────────────────────┘" -ForegroundColor Green
Write-Host ""

$max = [Math]::Min($sessions.Count, 9)
for ($i = 0; $i -lt $max; $i++) {
    $s = $sessions[$i]
    $marker = if ($i -eq 0) { '>' } else { ' ' }
    $color = if ($i -eq 0) { 'Yellow' } else { 'White' }
    $tsStr = $s.Timestamp.ToString('yyyy-MM-dd HH:mm')
    Write-Host ("  {0} [{1}] {2}" -f $marker, ($i + 1), $s.Title) -ForegroundColor $color
    Write-Host ("         {0}" -f $tsStr) -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "    [N] new session" -ForegroundColor White
Write-Host "    [Q] cancel" -ForegroundColor DarkGray
Write-Host ""
$sel = Read-Host "  number (Enter = resume latest)"

if ($sel -eq '') {
    Resume-Session -SessionId $sessions[0].SessionId
    exit 0
}
if ($sel -match '^[Nn]$') { Start-NewSession; exit 0 }
if ($sel -match '^[Qq]$') { Write-Host "  cancelled" -ForegroundColor DarkGray; exit 0 }
$idx = 0
if (-not [int]::TryParse($sel, [ref]$idx)) {
    Write-Host "  bad input. resuming latest." -ForegroundColor Red
    Resume-Session -SessionId $sessions[0].SessionId; exit 0
}
if ($idx -lt 1 -or $idx -gt $max) {
    Write-Host "  out of range. resuming latest." -ForegroundColor Red
    Resume-Session -SessionId $sessions[0].SessionId; exit 0
}
Resume-Session -SessionId $sessions[$idx - 1].SessionId
