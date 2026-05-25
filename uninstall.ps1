# =====================================================================
# uninstall.ps1 - Remove Domain Maker
# =====================================================================
# Safe by default: only removes the PowerShell-profile block.
# Workspace/domains/memory and ~/.claude/settings.json are NEVER touched
# unless you explicitly opt in:
#   -RemoveStatusLine -WorkspaceRoot <path>  ← remove statusLine entry
#                                              (only if it points to this
#                                              workspace's statusline.ps1)
#   -PurgeWorkspace -WorkspaceRoot <path>    ← delete the workspace folder
#                                              (asks for "DELETE" confirm)
# =====================================================================

[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [switch]$PurgeWorkspace,
    [switch]$NonInteractive,
    [switch]$RemoveStatusLine
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Read-Default {
    param([string]$Prompt, [string]$Default)
    if ($NonInteractive) { return $Default }
    $shown = if ($Default) { " [$Default]" } else { "" }
    $val = Read-Host ($Prompt + $shown)
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default }
    return $val.Trim()
}

Write-Host ""
Write-Host "  Domain Maker - uninstaller" -ForegroundColor Cyan
Write-Host ""

# ---- 1. unpatch PowerShell profile ----------------------------------
$ProfilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $ProfilePath) {
    $text = Get-Content $ProfilePath -Raw -Encoding UTF8
    $pattern = '(?ms)\r?\n?# === Domain Maker block ===.*?# === Domain Maker block end ===\r?\n?'
    if ($text -match $pattern) {
        $backupPath = "$ProfilePath.bak-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"
        Copy-Item $ProfilePath $backupPath
        $newText = [regex]::Replace($text, $pattern, "`r`n")
        Set-Content -Path $ProfilePath -Value $newText -Encoding UTF8
        Write-Host "  [1/3] profile block removed (backup: $backupPath)" -ForegroundColor Green
    } else {
        Write-Host "  [1/3] profile block not found - nothing to remove" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [1/3] profile file not found - skipped" -ForegroundColor Yellow
}

# ---- 2. unregister statusLine (only if -RemoveStatusLine + known workspace) ----
# We refuse to remove a statusLine entry unless the user has explicitly opted in
# AND provides the workspace root so we can match the exact registered path.
# This prevents accidentally clobbering an unrelated statusline.ps1 setup.
$claudeSettings = Join-Path $env:USERPROFILE '.claude\settings.json'
if ($RemoveStatusLine) {
    if (-not $WorkspaceRoot) {
        if (-not $NonInteractive) {
            $WorkspaceRoot = Read-Default "Workspace root (so we can match the exact statusLine path)" ""
        }
    }
    if (-not $WorkspaceRoot) {
        Write-Host "  [2/3] -RemoveStatusLine needs -WorkspaceRoot - skipped" -ForegroundColor Yellow
    } elseif (-not (Test-Path $claudeSettings)) {
        Write-Host "  [2/3] ~/.claude/settings.json not found - skipped" -ForegroundColor Yellow
    } else {
        try {
            $obj = Get-Content $claudeSettings -Raw -Encoding UTF8 | ConvertFrom-Json
            $expected = (Join-Path $WorkspaceRoot 'scripts\statusline.ps1')
            $expectedNorm = $expected.ToLower()
            if ($obj.PSObject.Properties.Match('statusLine').Count -gt 0 -and
                $obj.statusLine.command -and
                $obj.statusLine.command.ToLower().Contains($expectedNorm)) {
                $obj.PSObject.Properties.Remove('statusLine')
                $obj | ConvertTo-Json -Depth 10 | Set-Content -Path $claudeSettings -Encoding UTF8
                Write-Host "  [2/3] statusLine entry removed (matched $expected)" -ForegroundColor Green
            } else {
                Write-Host "  [2/3] no matching Domain Maker statusLine entry - skipped" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [2/3] ~/.claude/settings.json parse error - skipped" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  [2/3] statusLine entry kept (pass -RemoveStatusLine to remove it)" -ForegroundColor DarkGray
}

# ---- 3. (optional) purge workspace ----------------------------------
if ($PurgeWorkspace) {
    if (-not $WorkspaceRoot) {
        $WorkspaceRoot = Read-Default "Workspace root to PURGE (DANGER: deletes all domains)" ""
    }
    if ($WorkspaceRoot -and (Test-Path $WorkspaceRoot)) {
        if (-not $NonInteractive) {
            Write-Host ""
            Write-Host "  About to delete: $WorkspaceRoot" -ForegroundColor Red
            $c = Read-Host "  Type 'DELETE' to confirm"
            if ($c -ne 'DELETE') {
                Write-Host "  cancelled" -ForegroundColor Yellow
                exit 0
            }
        }
        Remove-Item -Path $WorkspaceRoot -Recurse -Force
        Write-Host "  [3/3] workspace purged: $WorkspaceRoot" -ForegroundColor Green
    } else {
        Write-Host "  [3/3] workspace not found - skipped" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [3/3] workspace folder kept (use -PurgeWorkspace to delete)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Done. Obsidian junctions (if any) must be removed manually:" -ForegroundColor Cyan
Write-Host "      cmd /c rmdir `"<vault>\<NN>_<Name>`"" -ForegroundColor DarkGray
Write-Host ""
