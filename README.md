# TSM — TMUX Session Manager

A self-contained tmux workspace manager built for SSH-first, always-on development. Define your sessions in one config file; every SSH login — including from a phone — drops you straight into a live, named workspace with an interactive switcher menu. No Ruby, Python, or fzf required: just bash and tmux.

---

## Why TSM?

Tools like [tmuxinator](https://github.com/tmux-plugins/tmuxinator) and [tmuxp](https://github.com/tmux-plugins/tmuxp) are excellent at defining complex multi-pane layouts for individual projects. [tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer) is great for fuzzy-jumping between project directories. [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) saves and restores whatever sessions happen to be running.

TSM is none of those things. It targets a different problem: **persistent, named workspaces that survive disconnects and greet you automatically on every SSH login**, with a built-in menu as the primary interface.

| | TSM | tmuxinator / tmuxp | tmux-sessionizer | tmux-resurrect |
|---|---|---|---|---|
| SSH auto-attach on login | **✓ built-in** | ✗ | ✗ | ✗ |
| Interactive session menu | **✓ built-in** | ✗ (type the name) | ✓ fzf popup | ✗ |
| All sessions in one config | **✓** | ✗ per-project files | ✗ | ✗ |
| Zero dependencies | **✓ pure bash** | ✗ Ruby / Python | ✗ needs fzf | ✓ |
| Per-session env vars | **✓** | partial (ERB / `${}`) | ✗ | ✗ |
| Multi-pane / window layouts | ✗ | ✓ | ✗ | saves live state |
| Fuzzy directory search | ✗ | ✗ | ✓ | ✗ |
| Save & restore across reboots | ✗ | ✗ | ✗ | ✓ |

**TSM works best when you want:**
- A fixed set of named workspaces (code, AI agent, shell, relay…) that are always running
- Every SSH login — from any client, including a phone — to land in the right place automatically
- Session startup commands (launch an AI agent, a dev server, set env vars) without writing a separate config file per session
- No runtime dependencies beyond tmux itself

**Reach for tmuxinator/tmuxp instead** if you need precise multi-window, multi-pane layouts per project.
**Reach for tmux-sessionizer** if you jump between many project directories and want fuzzy search.
**Pair with tmux-resurrect** if you need sessions to survive a server reboot.

---

## Features

- **SSH auto-attach** — every login lands in `main` automatically; no manual `tmux attach` ever
- **Dedicated launcher session** — `main` runs nothing but the menu, always ready as your home base
- **Single config file** — all sessions defined in one `conf/sessions.conf`; gitignored so each user keeps their own without forking the repo
- **Auto-launch** — sessions start AI agents, dev servers, or any shell command on creation
- **Per-session env vars** — `SESSION_ENVS` injects variables before the startup command runs, applied to the whole session so every future pane inherits them
- **Zero dependencies** — pure bash and tmux; works on any minimal SSH server
- **Phone-friendly** — `Ctrl+a` prefix, mouse enabled, status bar at top, `Alt+Arrow` pane nav

---

## Quick Start

```bash
# 1. Clone wherever you like
git clone <repo-url> ~/tsm
cd ~/tsm

# 2. Copy the example config and customise your sessions
cp conf/sessions.conf.example conf/sessions.conf
$EDITOR conf/sessions.conf

# 3. Run the installer (idempotent — safe to re-run)
bash install.sh
```

The installer:
1. Verifies `tmux` is installed
2. Makes all scripts executable
3. Writes `~/.tmux.conf` to source `conf/tmux.conf` (backs up any existing config)
4. Installs `tsm` to `~/.local/bin/tsm`
5. Appends the SSH auto-attach hook to `~/.bashrc`
6. Starts all configured sessions
7. Reloads a running tmux server if one is active

Then reload your shell and you're running:

```bash
source ~/.bashrc
tsm
```

---

## Configuration

All session definitions live in **`conf/sessions.conf`**. It is gitignored — `conf/sessions.conf.example` is the version-controlled template.

The six arrays are index-aligned: the same position across all arrays defines one session. There is also one scalar setting for IP display.

```bash
SESSIONS=( code dev other )
LABELS=(   "Project workspace" "AI developer" "General shell" )
KEYS=(     e d o )
DIRS=(     "$HOME/Projects" "$HOME/Projects" "$HOME" )
INIT_CMDS=( "" "auto" "" )
SESSION_ENVS=( "" "" "" )

# Optional: show IPv4 addresses in the menu header
SHOW_IPS=( wlan0 tailscale0 )
```

### `INIT_CMDS` — startup behaviour

| Value | Behaviour |
|-------|-----------|
| `""` | Plain shell, nothing sent |
| `"auto"` | Auto-detects `claude` then `aider`; launches whichever is found |
| `"claude"` | Explicitly launches Claude Code |
| `"codex"` | Explicitly launches OpenAI Codex |
| any string | Sent verbatim to the shell — e.g. `"npm run dev"` |

Override the auto-detected AI tool without editing the config:

```bash
export DEV_AI_CMD="aider --model gpt-4o"
```

### `SESSION_ENVS` — per-session environment variables

Space-separated `KEY=VALUE` pairs injected when a session is first created. Applied to tmux's environment table (so all future panes/windows in that session inherit them) and exported into the initial shell before `INIT_CMD` runs.

```bash
# Disable network sandbox for an AI agent session
SESSION_ENVS=( "" "CODEX_DISABLE_SANDBOX=1" "" )

# Multiple vars, space-separated
SESSION_ENVS=( "" "NODE_ENV=development PORT=3000" "" )
```

### `SHOW_IPS` — IP addresses in the menu header

An optional array of network interface names. When set, each interface's IPv4 address is displayed on the menu header line after the current time. Interfaces with no address show as `down`.

```bash
SHOW_IPS=( wlan0 tailscale0 )   # wifi + Tailscale VPN
SHOW_IPS=( eth0 )               # single wired interface
SHOW_IPS=()                     # disabled (default)
```

This is read from the same `sessions.conf` as all other settings — set it in your personal config to keep it out of version control.

### Adding a session

1. Append one entry to each array in `conf/sessions.conf`
2. Add a bind-key line in `conf/tmux.conf`:
   ```
   bind-key <letter> run-shell 'tmux switch-client -t <name> 2>/dev/null || tmux display "<name> not running"'
   ```
3. Update the `status-right` string in `conf/tmux.conf` to include the new hint
4. Reload: `tmux source-file ~/.tmux.conf`
5. Start: `tsm` (or `bash scripts/start-sessions.sh <name>`)

**Reserved keys** (already bound in `conf/tmux.conf`): `m` `s` `S` `H` `J` `K` `L` `v` `c` `|` `-`

### User-local override

To override config without touching the repo, copy to:

```bash
~/.config/tmsm/sessions.conf
```

This file takes precedence over `conf/sessions.conf` and is never touched by the installer.

---

## Session Menu

The `main` session runs a continuous interactive menu (`session-menu.sh`):

```
┌──────────────────────────────────────────┐
│         TMUX SESSION MANAGER             │
└──────────────────────────────────────────┘
  current: main  14:32
  wlan0 192.168.1.42  ·  tailscale0 100.100.0.1

  ▶ [1] code      Project workspace        idle
    [2] dev        AI developer             active (1)
    [3] other      General shell            stopped

  ──────────────────────────────────────────
  ↑/↓  navigate     Enter/[num]  select
  [r]  refresh  [s] start all  [q]  quit
  [k]  kill ALL sessions and exit
```

- **Arrow keys** or **number keys** to navigate and select
- Selecting a stopped session starts it before switching
- Status badges refresh on each keypress and every 30 seconds automatically
- `q` exits the menu loop but leaves `main` alive; run `tsm` to reopen it
- `k` prompts for confirmation then kills all sessions

---

## Key Bindings

The prefix is **`Ctrl+a`** (reachable on every mobile keyboard).

### Session navigation

| Keys | Action |
|------|--------|
| `Prefix` + `m` | Switch to **main** (session menu) |
| `Prefix` + `e` | Switch to **code** *(default config)* |
| `Prefix` + `d` | Switch to **dev** *(default config)* |
| `Prefix` + `o` | Switch to **other** *(default config)* |
| `Prefix` + `s` | Full visual session/window chooser |
| `Prefix` + `S` | Jump to the session menu in `main` |

Keys for additional sessions are defined in `conf/tmux.conf` alongside the session definitions.

### Pane and window management

| Keys | Action |
|------|--------|
| `Alt` + Arrow | Move between panes (no prefix needed) |
| `Prefix` + `\|` | Split pane horizontally |
| `Prefix` + `-` | Split pane vertically |
| `Prefix` + `H/J/K/L` | Resize pane |
| `Prefix` + `c` | New window (opens in current path) |

### Copy mode

| Keys | Action |
|------|--------|
| `Prefix` + `v` | Enter copy mode |
| `v` (in copy mode) | Begin selection |
| `y` (in copy mode) | Yank selection and exit |

---

## Session Flow

```
SSH login (or running `tsm` from any shell)
    │
    ▼
~/.bashrc detects SSH_CONNECTION + no existing $TMUX
    │
    ▼
tsm → start-sessions.sh all
    │   Creates any missing sessions, runs their INIT_CMDs,
    │   and applies SESSION_ENVS — then leaves them all detached.
    │
    └── tmux attach-session -t main
            │
            ▼
        ┌─────────────────────────────────────┐
        │  main  (dedicated launcher session) │
        │  window: menu — session-menu.sh     │◄─── Prefix+m from anywhere
        └─────────────────────────────────────┘
                │
                │  switch-client (terminal moves; main stays alive)
                ├──────────────────► code   (your project workspace)
                ├──────────────────► dev    (AI agent, auto-launched)
                └──────────────────► other  (general shell)
```

`main` is never used for real work — its only job is to run the menu and act as a stable home base. `switch-client` moves your terminal to the target session without detaching or killing anything. `Prefix + m` jumps back to the menu from any session.

---

## Project Structure

```
tsm/
├── install.sh                   # Idempotent setup — run once after cloning
├── conf/
│   ├── sessions.conf.example    # Committed template — copy to sessions.conf
│   ├── sessions.conf            # Your config — gitignored, edit freely
│   └── tmux.conf                # Full tmux configuration
├── scripts/
│   ├── start-sessions.sh        # Creates any missing sessions
│   ├── session-menu.sh          # Interactive session switcher (runs in 'main')
│   ├── ssh-attach.sh            # Auto-attach hook sourced by ~/.bashrc
│   └── tmsm.sh                  # Installed as ~/.local/bin/tsm
├── snippets/
│   ├── bashrc.snippet           # The block appended to ~/.bashrc
│   └── terminus-tips.md         # Phone terminal setup guide
└── tests/
    └── test_install.sh
```

---

## Phone Setup (Terminus)

See `snippets/terminus-tips.md` for the full guide. Key points:

- **Font**: JetBrains Mono or Fira Code (needed for box-drawing characters in the menu)
- **Keyboard toolbar**: enable the extended row; add `Ctrl`, `Alt`, `Esc`, `Tab`
- **Status bar at top** so the phone keyboard doesn't cover it
- **Mouse enabled** — tap any pane or window tab to focus it
- **`Alt` + Arrow** navigates panes without the prefix, which matters when `Ctrl` is tucked away

---

## Troubleshooting

**Sessions are gone after a reboot.**
tmux sessions don't survive a server restart. Re-run:
```bash
tsm
```
Or install [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) for automatic persistence.

**The menu loop isn't running in `main`.**
```bash
tmux send-keys -t main "tsm" Enter
```

**SSH login drops to a plain shell instead of tmux.**
Check that `~/.bashrc` contains the hook (search for `# tsm: SSH auto-attach`) and that your SSH client starts an interactive login shell.

**`~/.tmux.conf` changes aren't reflected.**
```bash
tmux source-file ~/.tmux.conf
```

**A session won't start.**
```bash
# Kill and recreate a single session
tmux kill-session -t <name>
bash scripts/start-sessions.sh <name>
```
