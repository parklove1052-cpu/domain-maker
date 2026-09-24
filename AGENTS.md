# AGENTS.md — for OpenAI Codex / GPT agents

You are reading the **Domain Maker** repo. It was built for Claude Code, but every
part of it works the same for Codex. Read this file first, then `docs/ARCHITECTURE.md`.

## The idea in one paragraph

A "domain" is one folder per area of work (marketing, trading, video, …) under
`<workspace>/domains/`. Each domain folder holds its own rules and memory:

```
domains/<domain>/
  CLAUDE.md        ← the domain's rules. For Codex this IS the AGENTS.md (see below)
  memory/INDEX.md  ← index of memory notes; read it before answering
  memory/*.md      ← one fact per file
  todos.md         ← open tasks for this domain
```

A single registry, `<workspace>/scripts/domain-config.json`, maps
`name / shortcut / folder`. Every script reads it; nothing else holds state.

## How Codex enters a domain

| Claude Code | Codex |
|---|---|
| `cc <domain>` (session picker) | `cx <domain>` (runs `codex` inside the domain folder) |
| reads `CLAUDE.md` natively | reads `CLAUDE.md` via `project_doc_fallback_filenames = ["CLAUDE.md"]` in `~/.codex/config.toml` |

`install.ps1` adds both the `cx` function and that config line (backup first).
If you install by hand: copy `scripts/cx.ps1` next to `cc.ps1`, add
`function cx { & "$DomainMakerScripts\cx.ps1" @args }` to the PowerShell profile block,
and put the config line at the **top** of `~/.codex/config.toml` (before any `[table]`).

## Rules when you (Codex) work inside a domain

1. Treat that domain's `CLAUDE.md` as your instructions. Wording like "Claude must…"
   applies to you too.
2. Read `memory/INDEX.md` before acting; write new facts as new files in `memory/`
   and add one line to `INDEX.md` — same format the Claude sessions use, so both
   agents share one memory.
3. Stay in the domain. Work that belongs to another domain → say which domain, do not do it here.
4. Do not edit `CLAUDE.md`, `domain-config.json`, or the PowerShell profile unless the
   user asks. Creating domains is the meta-domain's job (`scripts/new-domain.ps1`).

## Files

| Path | What it does |
|---|---|
| `install.ps1` | one-time setup: workspace, meta-domain, profile block, statusLine, Codex config |
| `scripts/new-domain.ps1` | creates a domain (folder + CLAUDE.md + registry + shortcut + colors) |
| `scripts/cc.ps1` | enter a domain with Claude Code (session resume TUI) |
| `scripts/cx.ps1` | enter a domain with Codex |
| `scripts/statusline.ps1` | Claude Code status line (which domain am I in) |
| `templates/domain-maker/` | the meta-domain's CLAUDE.md / memory / todos |
