#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ssh-attach.sh
# Called by .bashrc when a new SSH session arrives and no tmux is running.
# • Ensures all sessions exist (creating them if absent).
# • Attaches the terminal to the 'main' session.
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/start-sessions.sh"

# Guard: don't nest tmux inside tmux
[ -n "$TMUX" ] && return 0

# Guard: only run for interactive SSH logins
[ -z "$SSH_CONNECTION" ] && return 0

# Ensure tmux server is running and all sessions exist
bash "$START_SCRIPT" all 2>/dev/null

# Attach to main.  'tmux attach' exits cleanly when the session is detached or
# the user types 'exit', returning the user to the SSH shell (which then closes).
exec tmux attach-session -t main
