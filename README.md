# TSM — TMUX Session Manager

TSM is a tmux launcher for a small, fixed set of persistent named workspaces. It is built for SSH-first use: on login, it can start missing sessions, attach you to a dedicated `main` launcher session, and give you an interactive session menu that works well from a laptop or a phone.

It is intentionally simple. Sessions are defined with Bash arrays in one config file, startup commands are shell strings, and tmux remains the only major runtime dependency.

---

## What TSM Actually Does

TSM is not a project-layout generator. It is a session bootstrapper and switcher for always-on shells.

What it does well:
- Starts a known set of tmux sessions if they do not exist yet
- Auto-attaches SSH logins into tmux through `~/.bashrc`
- Keeps a dedicated `main` session whose `menu` window runs an interactive selector
- Lets each session define a working directory, startup command, and environment variables
- Supports direct key-based switching between sessions with `Prefix + <key>`

What it does not do:
- Define complex pane/window layouts per project
- Restore sessions after a machine reboot
- Generate tmux bindings automatically from `sessions.conf`
- Target non-Linux environments particularly well

If you need multi-pane project layouts, use `tmuxinator` or `tmuxp`. If you need reboot persistence, pair this with `tmux-resurrect`.

---

## Feature Set

These features are implemented in the current repo:

- Dedicated launcher session: `main` is created separately from your work sessions and keeps a persistent shell plus a `menu` window.
- Interactive menu: `scripts/session-menu.sh` renders a full-screen selector with arrow-key navigation, numeric shortcuts, live session status, a tmux cheat sheet, and a destructive `kill all` confirmation flow.
- SSH auto-attach: `install.sh` appends a guarded block to `~/.bashrc` so interactive SSH logins run `tsm`.
- Session bootstrap: `scripts/start-sessions.sh` creates missing sessions from config and leaves existing ones alone.
- Session-local startup behavior: each configured session can start as a plain shell, run `auto`, launch `claude`, launch `codex`, or run an arbitrary shell command.
- Session environment injection: `SESSION_ENVS` values are applied with `tmux set-environment` and exported into the initial shell window before the startup command runs.
- Optional IP display: the menu header can show IPv4 addresses for configured interfaces in `SHOW_IPS`.
- Menu key autodetection: the menu tries to discover the `main` quick-switch key from `~/.tmux.conf`, sourced tmux files, or `tmux list-keys`, then falls back to `MENU_KEY`.
- In-session launcher behavior: running `tsm` inside tmux recreates the `main:menu` window if it was closed and switches the client there.
- Direct session switching bindings: the default tmux config binds `Prefix + m/e/d/x/r/h/o` to named sessions.
- Mobile-oriented tmux defaults: `Ctrl+a` prefix, top status bar, mouse support, `Alt+Arrow` pane navigation, and simple split bindings.
- Installer migration logic: `install.sh` migrates older `tmsm` references in `~/.bashrc` and removes a legacy `~/.local/bin/tmsm` symlink if present.
- CLI help and introspection: `tsm help` and `tsm list` document the active configuration without needing a live tmux connection.

---

## Dependencies

TSM no longer honestly qualifies as "zero dependencies." The dependency footprint is still small, but it is real and worth documenting.

### Required

- `bash`
- `tmux`
- Standard shell utilities used throughout the scripts: `awk`, `grep`, `sed`, `readlink`, `date`, `wc`, `chmod`, `ln`, `cp`, `mkdir`, `rm`

### Optional

- `ip` from `iproute2`
  Used by the menu only when `SHOW_IPS` is configured.
- `claude`
  Used when `INIT_CMDS` is `claude` or when `INIT_CMDS=auto` and `claude` is available.
- `aider`
  Used when `INIT_CMDS=auto` and `claude` is not available.
- `codex`
  Used when `INIT_CMDS` is `codex`.

### Platform assumptions

The scripts are Linux-first. Current implementation details rely on:

- `readlink -f`
- `sed -i`
- `ip -4 addr show`
- A typical `~/.bashrc` + SSH login shell flow

That means the repo is well suited to Linux VPS and homelab use, but not currently packaged as a portable cross-platform tmux tool.

---

## Quick Start

```bash
git clone <repo-url> ~/Projects/tsm
cd ~/Projects/tsm
bash install.sh
```

On first run, the installer will offer to copy:

- `conf/sessions.conf.example` -> `conf/sessions.conf`
- `conf/tmux.conf.example` -> `conf/tmux.conf`

Then it:

1. Checks for `tmux`
2. Makes the scripts executable
3. Installs `~/.tmux.conf` as a thin file that sources this repo's `conf/tmux.conf`
4. Installs `tsm` as `~/.local/bin/tsm`
5. Ensures `~/.local/bin` is on your `PATH`
6. Appends the SSH auto-attach hook to `~/.bashrc`
7. Starts all configured sessions
8. Reloads a live tmux server if one is already running

After install:

```bash
source ~/.bashrc
tsm
```

---

## CLI

`tsm` now has a small command surface:

```bash
tsm
tsm menu
tsm start [all|main|SESSION]
tsm attach [SESSION]
tsm list
tsm help
```

Behavior:

- `tsm` or `tsm menu`
  Outside tmux: starts all configured sessions and attaches to `main`
  Inside tmux: ensures `main` and `main:menu` exist, then switches to that window
- `tsm start`
  Creates missing sessions without attaching
- `tsm attach`
  Attaches or switches directly to a named tmux session
- `tsm list`
  Prints the active config source plus session names, keys, labels, startup commands, directories, and environment variables
- `tsm help`
  Shows usage, behavior, dependency notes, and active file paths

---

## Configuration

The main config file is [`conf/sessions.conf`](/mnt/seagate/Projects/2026/tsm/conf/sessions.conf). A user-local override at `~/.config/tsm/sessions.conf` takes precedence if present.

The arrays are index-aligned: entry `i` in each array describes one session.

```bash
SESSIONS=( code dev codex relay share other )
LABELS=( "Project workspace" "Claude" "Codex" "Relay" "Share" "General shell" )
KEYS=( e d x r h o )
DIRS=( "$HOME/Projects" "$HOME/Projects" "$HOME/Projects" "$HOME" "$HOME" "$HOME" )
INIT_CMDS=( "" "claude" "codex" "" "" "" )
SESSION_ENVS=( "" "" "CODEX_DISABLE_SANDBOX=1" "" "" "" )
SHOW_IPS=( wlan0 tailscale0 )
MENU_KEY=m
```

### `INIT_CMDS`

| Value | Behavior |
|---|---|
| `""` | Starts with a plain shell in the first window and creates a second `shell` window |
| `"auto"` | Uses `DEV_AI_CMD` if set, otherwise `claude`, otherwise `aider`, otherwise prints a warning in the window |
| `"claude"` | Sends `claude` into the first window and creates a second `shell` window |
| `"codex"` | Sends `codex` into the first window and creates a second `shell` window |
| any other string | Sends that string verbatim into the first window and creates a second `shell` window |

For `auto`, you can override the detected AI command:

```bash
export DEV_AI_CMD="aider --model gpt-4o"
```

### `SESSION_ENVS`

Each string is split on spaces and treated as `KEY=VALUE` pairs.

Example:

```bash
SESSION_ENVS=(
  ""
  "NODE_ENV=development PORT=3000"
  "CODEX_DISABLE_SANDBOX=1"
  ""
  ""
  ""
)
```

These are applied in two places:

- tmux's session environment table, so future panes and windows inherit them
- the initial shell window, before the startup command runs

### `SHOW_IPS`

If `SHOW_IPS` is non-empty, the menu header prints each interface name and its IPv4 address. Interfaces with no IPv4 address render as `down`.

### Session additions

Adding a session still requires changes in two places:

1. Add entries to every aligned array in [`conf/sessions.conf`](/mnt/seagate/Projects/2026/tsm/conf/sessions.conf)
2. Add a matching `bind-key` line and status hint in [`conf/tmux.conf`](/mnt/seagate/Projects/2026/tsm/conf/tmux.conf)

That manual duplication is one of the clearest future improvement areas.

---

## Interactive Menu

The `main` session's `menu` window runs [`scripts/session-menu.sh`](/mnt/seagate/Projects/2026/tsm/scripts/session-menu.sh).

Implemented menu behavior:

- Arrow keys move the selection
- `Enter` switches to the selected session
- Number keys jump directly to sessions `1-9`
- Selecting a stopped session starts it first through `start-sessions.sh`
- `r` refreshes the display
- `s` starts all configured sessions
- `q` exits the menu loop but leaves the `main` session alive
- `k` opens a typed confirmation flow and can kill `main` plus every configured session
- The display auto-refreshes every 30 seconds by timing out the key read loop
- A tmux cheat sheet is printed at the bottom of the screen

The menu also shows per-session status:

- `stopped`
- `idle`
- `active (N)` where `N` is the number of attached clients in that session

---

## tmux Key Bindings

Defaults from [`conf/tmux.conf`](/mnt/seagate/Projects/2026/tsm/conf/tmux.conf):

| Keys | Action |
|---|---|
| `Ctrl+a` | Prefix |
| `Prefix + m` | Switch to `main` |
| `Prefix + e` | Switch to `code` |
| `Prefix + d` | Switch to `dev` |
| `Prefix + x` | Switch to `codex` |
| `Prefix + r` | Switch to `relay` |
| `Prefix + h` | Switch to `share` |
| `Prefix + o` | Switch to `other` |
| `Prefix + s` | Built-in tmux session/window chooser |
| `Prefix + S` | Jump to the TSM menu in `main` |
| `Alt + Arrow` | Pane navigation without prefix |
| `Prefix + H/J/K/L` | Resize pane |
| `Prefix + |` | Horizontal split |
| `Prefix + -` | Vertical split |
| `Prefix + c` | New window in current path |
| `Prefix + n/l/p` | Next, last, previous window |
| `Prefix + v` | Enter copy mode |
| `v` then `y` in copy mode | Select and yank |

---

## Session Flow

```text
SSH login
  -> ~/.bashrc sees SSH_CONNECTION and no TMUX
  -> tsm
  -> start-sessions.sh all
  -> tmux attach-session -t main
  -> main:menu
  -> switch-client to a work session
```

Inside tmux, `tsm` does not attach again. It repairs `main:menu` if needed and switches the existing client there.

---

## Project Structure

```text
tsm/
├── install.sh
├── conf/
│   ├── sessions.conf
│   ├── sessions.conf.example
│   ├── tmux.conf
│   └── tmux.conf.example
├── scripts/
│   ├── session-menu.sh
│   ├── ssh-attach.sh
│   ├── start-sessions.sh
│   └── tmsm.sh
├── snippets/
│   ├── bashrc.snippet
│   └── terminus-tips.md
└── tests/
    └── test_install.sh
```

Key files:

- [`install.sh`](/mnt/seagate/Projects/2026/tsm/install.sh): idempotent installer and `~/.bashrc` patcher
- [`scripts/tmsm.sh`](/mnt/seagate/Projects/2026/tsm/scripts/tmsm.sh): user-facing `tsm` launcher
- [`scripts/start-sessions.sh`](/mnt/seagate/Projects/2026/tsm/scripts/start-sessions.sh): session creation logic
- [`scripts/session-menu.sh`](/mnt/seagate/Projects/2026/tsm/scripts/session-menu.sh): interactive selector UI
- [`scripts/ssh-attach.sh`](/mnt/seagate/Projects/2026/tsm/scripts/ssh-attach.sh): SSH-only attach wrapper

---

## Testing

Basic validation in this repo is currently shell-script focused:

```bash
bash -n scripts/*.sh install.sh tests/test_install.sh
bash tests/test_install.sh
```

`tests/test_install.sh` checks:

- the `~/.local/bin/tsm` symlink
- script executability
- `.bashrc` markers
- local config files
- `~/.tmux.conf` management markers

It is an install smoke test, not a full behavior test suite.

---

## Known Gaps

- Session bindings are duplicated across `sessions.conf` and `tmux.conf`
- There is no automated check that those two files stay in sync
- The project is Linux-centric and not packaged for macOS or BSD tmux setups
- There are no menu interaction tests or session lifecycle integration tests
- Installer/tests mostly validate file presence and markers, not end-to-end tmux behavior

---

## Highest-Value Expansion Areas

These are the highest opportunity areas I see after exploring the repo:

1. Generate tmux bindings and status hints from `sessions.conf`
   Right now session metadata is declared once in [`conf/sessions.conf`](/mnt/seagate/Projects/2026/tsm/conf/sessions.conf) and again manually in [`conf/tmux.conf`](/mnt/seagate/Projects/2026/tsm/conf/tmux.conf). That is the biggest maintainability risk and the most obvious source of drift.

2. Add real integration tests around tmux behavior
   The current test script mostly verifies install artifacts. The project would benefit from scripted checks for session creation, menu window recreation, env propagation, and config override precedence.

3. Improve portability and dependency hardening
   If you want TSM to be broadly reusable, the next step is either embracing Linux explicitly in the docs and packaging, or abstracting the Linux-specific commands and shell assumptions so the tool works on macOS/BSD too.

4. Expand the CLI into a true control surface
   `tsm help` and `tsm list` now make the launcher easier to understand, but there is room for `tsm status`, `tsm validate`, and `tsm doctor` commands that explain drift, missing binaries, and bad config before a user hits tmux errors.

---

## Troubleshooting

### Sessions disappeared after reboot

tmux sessions do not survive a host restart by themselves.

```bash
tsm
```

If reboot persistence matters, pair this with `tmux-resurrect`.

### The menu window closed

Run:

```bash
tsm
```

Inside tmux, that recreates `main:menu` if needed and switches you back to it.

### SSH logins are not auto-attaching

Check `~/.bashrc` for the `# tsm: SSH auto-attach` block and confirm your SSH session starts an interactive Bash shell.

### A session definition changed but tmux still has the old one

Kill and recreate that session:

```bash
tmux kill-session -t <name>
bash scripts/start-sessions.sh <name>
```

### tmux config edits are not live yet

```bash
tmux source-file ~/.tmux.conf
```
