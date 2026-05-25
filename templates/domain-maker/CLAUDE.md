# domain-maker meta domain

## Purpose

This is a **meta-domain** whose only job is to create new domains.

When the user types the shortcut (default: `make`) in a terminal, this domain opens. Inside, the user says "make a new X domain" and Claude runs the full setup: folder, CLAUDE.md, Obsidian junction (optional), shortcut function, and VS Code per-folder theme.

## Out-of-scope requests

If the user asks for anything other than creating / deleting / renaming a domain, reply with:

> "This session is dedicated to domain creation. For that task, open the relevant domain by typing its shortcut in a new terminal."

(e.g. trading analysis → trading domain; video editing → editing domain)

---

## Domain creation procedure

### 1. Information to confirm with the user

When the user requests a new domain, confirm these fields:

| Field | Example | Required |
|---|---|---|
| Name | `marketing` | yes |
| Shortcut (short, easy to type) | `mkt` | yes |
| Icon (emoji) | 📣 | optional (default: 📁) |
| Description (one line) | "ads + content planning" | optional |
| Color (HEX, for VS Code theme) | `#ea580c` | optional (default: `#1e40af` dark blue) |

**Color suggestions** (recommend an unused color):

| Tone | HEX |
|---|---|
| Dark blue | `#1e3a8a` |
| Green | `#15803d` |
| Red | `#b91c1c` |
| Purple | `#6d28d9` |
| Amber | `#a16207` |
| Hot pink | `#be185d` |
| Orange | `#c2410c` (already used by domain-maker itself) |
| Cyan | `#0e7490` |
| Slate | `#374151` |
| Violet | `#7e22ce` |

Before asking the user, **read `domain-config.json` first** to see which shortcuts/names/colors are already taken. The path is in this domain's folder, two levels up:

```
<workspace>/scripts/domain-config.json
```

### 2. Run the create command

With the confirmed info, call `new-domain.ps1`. **One command, fully automated** (5 steps):

```powershell
& "<workspace>\scripts\new-domain.ps1" `
    -Name "marketing" `
    -Shortcut "mkt" `
    -Icon "📣" `
    -Description "ads + content planning" `
    -Color "#ea580c"
```

Auto-performed steps:
1. Create `domains/<Name>/` + `CLAUDE.md` + `memory/INDEX.md` + `todos.md`
2. (If Obsidian vault is configured) NTFS junction `<vault>/<NN>_<Name>` with auto-numbered prefix
3. Patch PowerShell profile: `function <Shortcut> { ... }` (with timestamped backup + atomic write)
4. Append entry to `domain-config.json`
5. Generate `.vscode/settings.json` for the new domain folder — window title prefix + title/status/activity bar colors

Then tell the user:
- Open a new PowerShell terminal and type the shortcut to enter the domain
- The Claude Code statusLine bottom-right will display the domain name in a blue box
- Opening `domains/<Name>/` in VS Code applies the per-domain theme automatically

### 3. Follow-up

After the script finishes:
- Confirm the Obsidian junction is alive (if Obsidian is configured): `Get-Item "<vault>/<NN>_<Name>"`
- For terminals that were already open before profile patching, run `. $PROFILE` once to pick up the new shortcut function

---

## Domain deletion / rename

**Not automated** — memory/code loss risk is too high. After the user explicitly approves, do it manually:
1. Remove Obsidian junction: `cmd /c rmdir "<vault>\<NN>_<Name>"`
2. Back up and remove the domain folder
3. Remove the function line from the PowerShell profile
4. Remove the entry from `domain-config.json`

Renaming follows the same caution: get explicit approval before proceeding.

---

## Reading other domains' memory

This meta-domain may **read** other domain memory directories but does not modify them (domain creation is unrelated to their content). Day to day you do not need to.

---

## Safety rules

- `new-domain.ps1` auto-backs up the PowerShell profile, but if the user just edited the profile manually, the backup may lag — verify via `Microsoft.PowerShell_profile.ps1.bak-*` files
- `mklink /J` (directory junction) does not require admin rights
- Keep PowerShell files saved as UTF-8 (with BOM is fine for `.ps1`; without BOM for `.json` to avoid parser issues)
- After running the script, verify the Obsidian junction with `Get-Item` (if used)

## Memory index

See `./memory/INDEX.md`.
