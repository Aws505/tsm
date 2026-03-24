# TSM — a pure-bash tmux session manager that auto-attaches SSH logins and shows an interactive menu

**GitHub:** https://github.com/Aws505/tsm

I got tired of typing `tmux attach` every time I SSH into my server, then hunting for the right session. So I built **tsm** — a self-contained tmux workspace manager that:

- **Auto-attaches on every SSH login** (including from a phone) — no manual attach ever
- **Drops you straight into an interactive session menu** as your home base
- **All sessions defined in a single config file** — just bash arrays, no YAML, no Ruby, no Python
- **Starts sessions with commands** — I have one session that auto-launches Claude Code, another that runs Codex, just by setting `INIT_CMDS=( "" "claude" "codex" "" )`
- **Per-session env vars** — inject `KEY=VALUE` pairs before the startup command, inherited by every pane in the session
- **Zero dependencies** — pure bash + tmux, works on any minimal SSH box

The interactive menu looks like this:

```
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
```

Arrow keys or number keys to navigate. Selecting a stopped session starts it then switches to it. `Prefix+m` jumps back to the menu from any session.

---

**How it differs from the usual suspects:**

| | TSM | tmuxinator/tmuxp | tmux-sessionizer | tmux-resurrect |
|---|---|---|---|---|
| SSH auto-attach | ✓ built-in | ✗ | ✗ | ✗ |
| Interactive menu | ✓ built-in | ✗ | ✓ (needs fzf) | ✗ |
| Single config file | ✓ | ✗ per-project | ✗ | ✗ |
| Zero dependencies | ✓ pure bash | ✗ Ruby/Python | ✗ needs fzf | ✓ |
| Per-session env vars | ✓ | partial | ✗ | ✗ |

It's not trying to replace tmuxinator (no multi-pane layout support) or tmux-sessionizer (no fuzzy project search). The goal is simple: **a fixed set of named workspaces that are always running and always reachable in one keypress from any SSH client**.

---

**Quick start:**

```bash
git clone https://github.com/Aws505/tsm ~/tsm
cd ~/tsm
cp conf/sessions.conf.example conf/sessions.conf
$EDITOR conf/sessions.conf   # define your sessions
bash install.sh
```

Then every SSH login auto-drops you into the menu. Works great from iOS/Android terminal apps (Terminus, Blink) — designed with `Ctrl+a` prefix and mouse support so it's usable on a phone keyboard.

Happy to answer questions or take feedback!
