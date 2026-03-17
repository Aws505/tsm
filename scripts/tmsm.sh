#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# tmsm — tmux session manager launcher
#
# Works from anywhere: inside or outside an existing tmux session.
# Installed as ~/.local/bin/tmsm by install.sh.
# ─────────────────────────────────────────────────────────────────────────────

# Resolve real path even when invoked through a symlink
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/start-sessions.sh"
MENU_SCRIPT="$SCRIPT_DIR/session-menu.sh"

if [ -n "${TMUX:-}" ]; then
    # Ensure main session exists
    if ! tmux has-session -t main 2>/dev/null; then
        bash "$START_SCRIPT" main
    fi
    # Ensure menu window exists; open it if it previously exited
    if ! tmux list-windows -t main -F '#{window_name}' 2>/dev/null | grep -q '^menu$'; then
        tmux new-window -t main: -n "menu" "$MENU_SCRIPT"
    fi
    tmux switch-client -t main:menu
else
    # Outside tmux — bootstrap all sessions and attach to main
    bash "$START_SCRIPT" all
    exec tmux attach-session -t main
fi
