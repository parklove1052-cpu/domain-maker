# cx.ps1 — open OpenAI Codex CLI inside a domain (Codex counterpart of cc.ps1)
#   cx.ps1                     → codex in the current folder
#   cx.ps1 <name-or-shortcut>  → cd into that domain, then codex
#   cx.ps1 <domain> exec "..." → extra args go straight to codex
# Codex reads the domain's CLAUDE.md because install.ps1 sets
# project_doc_fallback_filenames = ["CLAUDE.md"] in ~/.codex/config.toml.
$rest = @($args)
if ($rest.Count -gt 0 -and "$($rest[0])" -notmatch '^-') {
    $Config = Get-Content (Join-Path $PSScriptRoot 'domain-config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $q = "$($rest[0])"
    $d = $Config.domains | Where-Object { $_.name -eq $q -or $_.shortcut -eq $q -or $_.folder -eq $q } | Select-Object -First 1
    if ($d) {
        Set-Location -LiteralPath (Join-Path $Config.domainsRoot $d.folder)
        $rest = @($rest | Select-Object -Skip 1)
    }
}
& codex @rest
