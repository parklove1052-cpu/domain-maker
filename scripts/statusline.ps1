# =====================================================================
# statusline.ps1 - Claude Code statusLine command
# =====================================================================
# Wired into your Claude Code global settings.json:
#   "statusLine": { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File <path>\\statusline.ps1" }
#
# stdin: JSON payload from Claude Code (workspace.current_dir, model, ...)
# stdout: single-line text shown in the bottom-right corner.
# Must be fast (no external IO).
# =====================================================================

$ErrorActionPreference = 'SilentlyContinue'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# ANSI: 24-bit dark blue background + bold white text = "blue box"
$esc = [char]27
$reset = "$esc[0m"
$blueBox = "$esc[1m$esc[48;2;30;64;175m$esc[97m"

try {
    # Read stdin as raw bytes then UTF-8 decode (avoids cp949 conversion)
    $stdin = [Console]::OpenStandardInput()
    $ms = New-Object System.IO.MemoryStream
    $buf = New-Object byte[] 4096
    while (($n = $stdin.Read($buf, 0, $buf.Length)) -gt 0) { $ms.Write($buf, 0, $n) }
    $input_json = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
    $payload = $input_json | ConvertFrom-Json

    $cwd = $null
    if ($payload.workspace -and $payload.workspace.current_dir) {
        $cwd = $payload.workspace.current_dir
    } elseif ($payload.cwd) {
        $cwd = $payload.cwd
    } else {
        $cwd = (Get-Location).Path
    }

    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $configPath = Join-Path $scriptDir 'domain-config.json'
    if (-not (Test-Path $configPath)) {
        Write-Output "$blueBox  $cwd  $reset"
        exit 0
    }

    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $cwdNormalized = $cwd.TrimEnd('\').ToLower()

    $matched = $null
    foreach ($d in $config.domains) {
        $domainPath = (Join-Path $config.domainsRoot $d.folder).TrimEnd('\').ToLower()
        if ($cwdNormalized -eq $domainPath -or $cwdNormalized.StartsWith($domainPath + '\')) {
            $matched = $d
            break
        }
    }

    $modelName = if ($payload.model -and $payload.model.display_name) { $payload.model.display_name } else { '' }

    if ($matched) {
        $boxed = "$blueBox  $($matched.icon) $($matched.name)  $reset"
    } else {
        $workspaceLabel = if ($config.workspaceName) { $config.workspaceName } else { 'workspace' }
        $boxed = "$blueBox  📂 $workspaceLabel  $reset"
    }

    if ($modelName) {
        Write-Output "$boxed  ·  $modelName"
    } else {
        Write-Output $boxed
    }
} catch {
    Write-Output "$blueBox  📂  $reset"
    exit 0
}
