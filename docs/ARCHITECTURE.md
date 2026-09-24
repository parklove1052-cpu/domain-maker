# Architecture

```
+-- install.ps1            ← run once on a fresh machine
+-- uninstall.ps1
+-- scripts/
|   +-- new-domain.ps1     ← creates a new domain (5-step macro)
|   +-- cc.ps1             ← enter-a-domain TUI + session resume
|   +-- cx.ps1             ← same, but opens Codex (reads CLAUDE.md via fallback)
|   +-- statusline.ps1     ← Claude Code statusLine renderer
|   +-- domain-config.template.json
+-- templates/
|   +-- domain-maker/      ← the meta-domain itself
|       +-- CLAUDE.md
|       +-- memory/INDEX.md
|       +-- todos.md
+-- docs/
    +-- ARCHITECTURE.md    ← you are here
```

## After install

```
<workspace-root>/
  scripts/
    new-domain.ps1
    cc.ps1
    statusline.ps1
    domain-config.json         ← single source of truth
  domains/
    <meta>/                    ← meta-domain (default name: domain-maker)
      CLAUDE.md
      memory/INDEX.md
      todos.md
      .vscode/settings.json
    <each new domain>/
      CLAUDE.md
      memory/INDEX.md
      todos.md
      .vscode/settings.json    ← per-domain title + colors

<user>/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1
  # === Domain Maker block ===
  $DomainMakerScripts = "<workspace-root>\scripts"
  function <meta-shortcut> { & "$DomainMakerScripts\cc.ps1" "<meta-name>" @args }
  function cc              { ... }
  function <each shortcut> { ... }     ← added by new-domain.ps1
  # === Domain Maker block end ===

<user>/.claude/settings.json
  { "statusLine": { "type": "command", "command": "...statusline.ps1" } }
```

## Why a single `domain-config.json`?

Three different scripts need to agree on shortcut → folder mapping:

- `cc.ps1` (enter a domain)
- `statusline.ps1` (which domain is the current `cwd` in?)
- `new-domain.ps1` (don't duplicate shortcuts)

Putting that in one JSON makes the entire system trivially scriptable. Adding a domain is "append one object." Removing one is "delete one object." No DB, no daemon.

## Why PowerShell functions instead of aliases?

Aliases in PowerShell cannot accept `@args`. Functions can, so you can pass flags like `-Auto` through. Each shortcut is one line — readable and deletable.

## Why NTFS junctions for Obsidian?

A junction is a directory-level "second entrance" — same files, no copy, no daemon. Edits made through either path are reflected in the other instantly. Your Git repo only sees the workspace path, so the Obsidian side is invisible to version control even though it shows up in graph view.

## Why a meta-domain?

Domain creation has friction (folder, CLAUDE.md, profile patch, color, junction, statusLine registration, …). Putting all that behind a single Claude session means the user never opens a file editor for the 7th step. The meta-domain's `CLAUDE.md` is the playbook Claude follows.

The meta-domain has a strict "refuse off-task work" rule — if the user asks for trading analysis in there, Claude redirects them to the trading domain instead of trying to help in the wrong context.
