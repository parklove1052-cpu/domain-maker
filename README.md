# Domain Maker

> Spin up **isolated Claude Code "domains"** with a single Korean shortcut. Each domain has its own folder, CLAUDE.md, memory, color theme, and resumable session list. The included **meta-domain** lets Claude itself create new domains by name.

[한국어 README](#한국어) | [English README](#english)

---

## English

### What is this?

You probably use Claude Code (the CLI) for many unrelated jobs — coding, ops, trading, video editing, errands. Mixing them in one project muddles memory and CLAUDE.md. Domain Maker gives you:

- **One shortcut per domain.** Type `mkt` in any terminal → opens a Claude Code session **already inside** the marketing domain folder, with that domain's `CLAUDE.md` and `memory/` loaded.
- **Session resume TUI.** The shortcut shows past sessions for that domain so you can pick up where you left off.
- **Per-domain VS Code theme.** Each domain folder gets its own title-bar / status-bar / activity-bar color so you never confuse two open windows.
- **A meta-domain.** Type the install shortcut (default: `make`) → enter a Claude session whose only job is creating new domains. Say "make a new X domain" and Claude runs the full setup (folder + CLAUDE.md + profile patch + colors).
- **Optional Obsidian integration.** Each domain folder gets an NTFS junction inside an Obsidian vault, so all your domain memory shows up in one graph view.

Built for **Windows + PowerShell + Claude Code**. No admin rights required.

### Quick install (for humans)

```powershell
git clone https://github.com/<your-account>/domain-maker.git
cd domain-maker
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

You will be asked for:

| Field | Default | What it is |
|---|---|---|
| Workspace root | `~/claude-workspace` | Folder that will hold all your domains |
| Workspace name | folder name | Label shown in the statusLine when no domain matches |
| Obsidian vault | (skip) | Optional. If given, each domain gets a junction into the vault. |
| Meta-domain shortcut | `make` | What you type to enter the domain-creation meta-domain |
| Meta-domain folder name | `domain-maker` | The folder/CLAUDE.md name for the meta-domain |
| Register statusLine? | Yes | Wires `statusline.ps1` into `~/.claude/settings.json` |

After install:

```powershell
# open a NEW terminal, then:
make
# inside Claude: "make a new marketing domain, shortcut mkt, emoji 📣"
```

To make a domain non-interactively from anywhere:

```powershell
& "$env:USERPROFILE\claude-workspace\scripts\new-domain.ps1" `
    -Name "marketing" -Shortcut "mkt" -Icon "📣" `
    -Description "ads + content planning" -Color "#ea580c"
```

### Quick install (for Claude Code)

If you are Claude Code reading this on someone's machine, the human just told you "install this repo." Do:

1. `git clone` this repo to a folder of your choice (e.g. `~/Documents/github/domain-maker`).
2. Ask the user the six install fields above. Default to the table values. For Obsidian, ask "do you have an Obsidian vault you want to integrate?" — if no, pass `-ObsidianVault ""`.
3. Run `install.ps1` with `-NonInteractive` and the gathered arguments:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1 `
       -NonInteractive `
       -WorkspaceRoot "<answer>" `
       -WorkspaceName "<answer>" `
       -ObsidianVault "<answer-or-empty>" `
       -MetaShortcut "<answer>" `
       -MetaName "<answer>" `
       -RegisterStatusLine    # omit if user said no
   ```
4. Tell the user to **open a new PowerShell terminal** and type their meta-shortcut. Then inside the new Claude Code session, they can ask to create more domains.

### How a domain works

When the user types a domain shortcut (e.g. `mkt`):

1. `cc.ps1` reads `domain-config.json`, finds the domain.
2. Sets the PowerShell window title + ANSI prompt prefix so you can see which domain owns this terminal.
3. Scans `~/.claude/projects/*.jsonl` to list past sessions whose `cwd` is this domain's folder.
4. Shows a numbered TUI: pick a session number, press `Enter` to resume the latest, `N` for new, `Q` to cancel.
5. Runs `claude --dangerously-skip-permissions [--resume <id>]` inside the domain folder, so Claude Code picks up the domain's `CLAUDE.md` automatically.

When you ask the meta-domain to "make a new X domain," Claude runs `new-domain.ps1` which:

1. Creates `<workspace>/domains/<X>/` with starter `CLAUDE.md`, `memory/INDEX.md`, `todos.md`.
2. (If Obsidian configured) creates `<vault>/<NN>_<X>` as an NTFS junction → same files, two paths.
3. Backs up your PowerShell profile, then appends `function <shortcut> { ... }` atomically.
4. Adds the new domain to `domain-config.json` (single source of truth).
5. Generates `<workspace>/domains/<X>/.vscode/settings.json` with the chosen color applied to title/status/activity bars.

The statusLine binary (`statusline.ps1`) reads `domain-config.json` and matches the current `cwd` against every registered domain — bottom-right shows the domain icon + name in a blue box.

### Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Safe by default: removes only the PowerShell-profile block. Your workspace, domains, memory, and `~/.claude/settings.json` are kept. To also remove the statusLine entry (only when you know the path), pass `-RemoveStatusLine -WorkspaceRoot <path>`. Use `-PurgeWorkspace` only when you are testing.

### Customizing colors

Edit `templates/domain-maker/CLAUDE.md` to change the color palette your meta-domain suggests. Or pass `-Color "#hex"` directly to `new-domain.ps1`.

### Requirements

- Windows 10 / 11
- PowerShell 5.1 or later (PowerShell 7 also works)
- [Claude Code](https://docs.claude.com/claude-code) installed and on PATH
- (Optional) Obsidian, if you want the vault integration
- (Optional) VS Code, for the per-domain theme

### License

MIT. See `LICENSE`.

---

## 한국어

### 이게 뭐예요?

Claude Code(CLI)로 여러 종류 일을 하다 보면 메모리·`CLAUDE.md`가 섞여서 골치 아픕니다. Domain Maker는:

- **도메인별 한 글자 단축어.** 터미널에 `마케` 입력 → 마케팅 도메인 폴더 안에서 Claude Code 세션이 바로 열림. 그 도메인의 `CLAUDE.md`와 `memory/`가 자동 로드.
- **세션 이어가기 TUI.** 단축어 입력 시 그 도메인의 과거 세션 목록이 뜸. 번호로 선택해서 이어갈 수 있음.
- **도메인별 VS Code 테마.** 도메인 폴더마다 다른 색의 타이틀바/상태바/액티비티바 → 두 창 열어놔도 헷갈리지 않음.
- **메타도메인.** 설치 시 정한 단축어(기본 `make`) 입력 → 새 도메인 생성 전용 Claude 세션. "X 도메인 만들어줘"라고 말하면 Claude가 폴더+CLAUDE.md+프로필 패치+색상까지 한 방에 끝냄.
- **옵시디언 통합 (선택).** 도메인 폴더마다 옵시디언 볼트 안에 NTFS 정션을 만들어줌 → 옵시디언 그래프뷰에서 모든 도메인 메모리가 한눈에.

**Windows + PowerShell + Claude Code** 환경 전용. 관리자 권한 필요 없음.

### 빠른 설치 (사람용)

```powershell
git clone https://github.com/<계정>/domain-maker.git
cd domain-maker
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

설치 시 물어보는 항목:

| 항목 | 기본값 | 설명 |
|---|---|---|
| 워크스페이스 루트 | `~/claude-workspace` | 모든 도메인이 들어갈 폴더 |
| 워크스페이스 이름 | 폴더명 | 도메인 밖일 때 statusLine 표시 라벨 |
| 옵시디언 볼트 | (스킵) | 입력 시 각 도메인을 정션으로 연결 |
| 메타도메인 단축어 | `make` | 도메인 생성 세션 진입 단축어 |
| 메타도메인 폴더명 | `domain-maker` | 메타도메인 폴더/CLAUDE.md 이름 |
| statusLine 등록 | Y | `~/.claude/settings.json`에 자동 등록 |

설치 후:

```powershell
# 새 터미널 열고:
make
# Claude 안에서: "마케팅 도메인 만들어줘, 단축어 마케, 이모지 📣"
```

### 빠른 설치 (Claude Code용)

이 README를 다른 사람 PC에서 Claude Code가 읽고 있다면, 사용자가 "이 repo 설치해줘"라고 한 상황입니다:

1. 이 repo를 적당한 곳에 `git clone` (예: `~/Documents/github/domain-maker`).
2. 위 6개 항목을 사용자에게 물어봅니다. 기본값은 위 표대로. 옵시디언은 "쓰는 볼트 있냐"고 묻고, 없으면 빈 문자열 전달.
3. `-NonInteractive` 플래그로 install 실행:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1 `
       -NonInteractive `
       -WorkspaceRoot "<답>" `
       -WorkspaceName "<답>" `
       -ObsidianVault "<답-또는-빈값>" `
       -MetaShortcut "<답>" `
       -MetaName "<답>" `
       -RegisterStatusLine
   ```
4. 새 PowerShell 터미널을 열고 메타 단축어 입력하라고 안내. 그 안에서 추가 도메인을 만들면 됩니다.

### 동작 원리

도메인 단축어(예: `마케`)를 누르면:

1. `cc.ps1`이 `domain-config.json`을 읽어 단축어와 매칭되는 도메인을 찾음.
2. PowerShell 윈도우 타이틀과 ANSI 프롬프트 prefix를 도메인 라벨로 설정 (어느 터미널인지 시각적으로 구분).
3. `~/.claude/projects/*.jsonl` 중 `cwd`가 해당 도메인 폴더인 세션 리스트 추출.
4. 번호 선택 TUI 표시: 숫자 = 그 세션 이어가기, Enter = 최근 세션, `N` = 새 세션, `Q` = 취소.
5. 해당 도메인 폴더로 들어가서 `claude --dangerously-skip-permissions [--resume <id>]` 실행 → 그 도메인의 `CLAUDE.md`가 자동 로드.

메타도메인에서 "X 도메인 만들어줘" 하면 Claude가 `new-domain.ps1` 호출:

1. `<workspace>/domains/<X>/` 폴더 + 기본 `CLAUDE.md`/`memory/INDEX.md`/`todos.md` 생성.
2. (옵시디언 설정 시) `<vault>/<NN>_<X>` NTFS 정션 생성 → 양쪽 경로가 같은 파일.
3. PowerShell 프로필 백업 후 `function <단축어> { ... }` 한 줄 atomic 추가.
4. `domain-config.json`에 새 도메인 항목 추가.
5. `<workspace>/domains/<X>/.vscode/settings.json` 생성 → 지정한 색으로 타이틀/상태/액티비티 바 테마.

statusLine 스크립트(`statusline.ps1`)는 `domain-config.json`을 읽어 현재 `cwd`를 모든 도메인과 매칭 → 오른쪽 하단에 도메인 아이콘+이름이 파란 박스로 표시.

### 제거

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

기본은 안전: PowerShell 프로필 블록만 제거. 워크스페이스/도메인/메모리/글로벌 settings.json은 보존. statusLine 항목까지 같이 빼고 싶으면 `-RemoveStatusLine -WorkspaceRoot <경로>`로 명시 (경로 매칭으로 다른 설정 보호). `-PurgeWorkspace`는 테스트할 때만.

### 요구사항

- Windows 10 / 11
- PowerShell 5.1+ (7도 가능)
- [Claude Code](https://docs.claude.com/claude-code) 설치 및 PATH 등록
- 옵시디언 (선택)
- VS Code (선택, 도메인별 테마 확인용)

### 라이선스

MIT. `LICENSE` 참조.
