TITLE:
TSM – pure-bash tmux session manager: SSH auto-attach + interactive session switcher, zero dependencies

---

BODY:

https://github.com/Aws505/tsm

I got tired of typing `tmux attach` every time I SSH into my server, then hunting for the right session. So I built **tsm** — a self-contained tmux workspace manager.

Every SSH login (including from a phone) automatically attaches to a dedicated "main" session that runs an interactive menu. Pick a workspace, switch to it. `Prefix+m` brings you back to the menu from anywhere.

The menu looks like this:

    ┌──────────────────────────────────────────┐
    │         TMUX SESSION MANAGER             │
    └──────────────────────────────────────────┘
      current: main  14:32  ^a·m
      wlan0 192.168.1.42  ·  tailscale0 100.100.0.1

      ▶ [1] code      Project workspace        idle
        [2] dev        Claude                   active (1)
        [3] codex      Codex                    active (1)
        [4] other      General shell            stopped

      ──────────────────────────────────────────
      ↑/↓  navigate     Enter/[num]  select
      [r]  refresh  [s] start all  [q]  quit

Arrow keys or number keys to navigate. Selecting a stopped session starts it then switches. No fzf, no fuzzy search — just a fixed set of named workspaces that are always running.

**Key features:**

- Auto-attaches on every SSH login — no manual `tmux attach` ever
- All sessions defined in one config file (bash arrays, no YAML/Ruby/Python)
- Sessions can auto-run a command on start — I have one that launches Claude Code, one that launches Codex, just by setting `INIT_CMDS=( "" "claude" "codex" "" )`
- Per-session env vars injected before the startup command, inherited by every pane
- Zero dependencies — pure bash + tmux

**How it compares:**

|  | TSM | tmuxinator/tmuxp | tmux-sessionizer | tmux-resurrect |
|--|-----|-----------------|-----------------|----------------|
| SSH auto-attach | ✓ built-in | ✗ | ✗ | ✗ |
| Interactive menu | ✓ built-in | ✗ | ✓ needs fzf | ✗ |
| Single config file | ✓ | ✗ per-project | ✗ | ✗ |
| Zero dependencies | ✓ pure bash | ✗ Ruby/Python | ✗ needs fzf | ✓ |
| Per-session env vars | ✓ | partial | ✗ | ✗ |

It doesn't do multi-pane layouts (use tmuxinator for that) or fuzzy project search (use tmux-sessionizer). Pair with tmux-resurrect if you need sessions to survive reboots.

**Quick start:**

    git clone https://github.com/Aws505/tsm ~/tsm
    cd ~/tsm
    cp conf/sessions.conf.example conf/sessions.conf
    $EDITOR conf/sessions.conf
    bash install.sh

Works well from iOS/Android terminal apps (Terminus, Blink) — `Ctrl+a` prefix and mouse support make it usable on a phone keyboard.

Happy to answer questions or take feedback!
