# AGENTS — tmux Session Manager

This repo is a self-contained tmux setup (`tsm`) that auto-attaches SSH sessions to named persistent workspaces and provides an interactive session switcher.

---

## Sessions

| Session | Label           | Key     | Purpose                                      |
|---------|-----------------|---------|----------------------------------------------|
| `code`  | Project workspace | `e`   | Primary coding workspace, opens in `~/Projects` |
| `dev`   | Claude          | `d`     | Claude Code AI agent — auto-launched on start |
| `codex` | Codex           | `x`     | OpenAI Codex agent — auto-launched, internet sandbox disabled |
| `relay` | Relay           | `r`     | Relay / proxy workspace                      |
| `share` | Share           | `h`     | Shared / collaborative shell                 |
| `other` | General shell   | `o`     | General-purpose shell                        |
| `main`  | Menu            | `m`     | Landing screen — runs the session-menu loop  |

Quick-switch: `Prefix + <key>` (prefix is `Ctrl+a`).

---

## Configuration

All session definitions live in **`conf/sessions.conf`**. The arrays are index-aligned — the same index across all arrays defines one session.

```bash
SESSIONS=( ... )      # internal tmux session names
LABELS=( ... )        # display names shown in the menu
KEYS=( ... )          # tmux prefix+key bindings
DIRS=( ... )          # starting working directory
INIT_CMDS=( ... )     # command to run on session start ("", "auto", or explicit cmd)
SESSION_ENVS=( ... )  # space-separated KEY=VALUE env vars applied at session creation
SHOW_IPS=( ... )      # interface names whose IPv4 addresses appear in the menu header
```

A user override (not tracked in git) can be placed at `~/.config/tsm/sessions.conf`.

### INIT_CMDS values

| Value    | Behaviour |
|----------|-----------|
| `""`     | Plain shell, no command sent |
| `"auto"` | Auto-detects `claude` or `aider` and launches it |
| `"claude"` | Explicitly launches Claude Code |
| `"codex"`  | Explicitly launches OpenAI Codex |
| any string | Sent verbatim to the shell |

### SESSION_ENVS

Space-separated `KEY=VALUE` pairs. Applied via `tmux set-environment` (inherited by all future panes in the session) and also exported into the initial shell window before INIT_CMD runs.

The `codex` session sets `CODEX_DISABLE_SANDBOX=1` so that Codex always has outbound internet access.

---

## Key Files

| File | Role |
|------|------|
| `conf/sessions.conf` | Session definitions (edit this to add/remove sessions) |
| `conf/tmux.conf` | Full tmux configuration |
| `scripts/start-sessions.sh` | Creates any missing sessions; sourced by ssh-attach and tmsm |
| `scripts/session-menu.sh` | Interactive arrow-key menu running in the `main` session |
| `scripts/ssh-attach.sh` | Called from `~/.bashrc` on SSH login to auto-attach tmux |
| `scripts/tmsm.sh` | Installed as `~/.local/bin/tsm`; the user-facing launcher |
| `install.sh` | One-time idempotent setup script |

---

## Adding a New Session

1. Append one entry to each array in `conf/sessions.conf`.
2. Add a `bind-key <letter> run-shell '...'` line in `conf/tmux.conf`.
3. Update the `status-right` string in `conf/tmux.conf` to include the new key hint.
4. Reload tmux config: `tmux source-file ~/.tmux.conf`.
5. Start the session: `bash scripts/start-sessions.sh <name>`.

---

## Installation

```bash
bash ~/Projects/tsm/install.sh
```

Idempotent — safe to re-run. Sets up `~/.tmux.conf`, adds the SSH hook to `~/.bashrc`, starts all sessions, and reloads a live tmux server if present.
