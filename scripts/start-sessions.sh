#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# start-sessions.sh — Create tmux sessions from sessions.conf
# Usage:
#   start-sessions.sh          → ensure all sessions exist
#   start-sessions.sh all      → same as above
#   start-sessions.sh <name>   → ensure only that session exists
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_SCRIPT="$SCRIPT_DIR/session-menu.sh"

# ── Load config ───────────────────────────────────────────────────────────────
# Defaults first; config overrides them.
SESSIONS=( code dev codex relay share other )
LABELS=( "Project workspace" "Claude" "Codex" "Relay" "Share" "General shell" )
DIRS=( "$HOME/Projects" "$HOME/Projects" "$HOME/Projects" "$HOME" "$HOME" "$HOME" )
INIT_CMDS=( "" "claude" "codex" "" "" "" )
SESSION_ENVS=( "" "" "CODEX_DISABLE_SANDBOX=1" "" "" "" )

_conf_user="$HOME/.config/tsm/sessions.conf"
_conf_proj="$(dirname "$SCRIPT_DIR")/conf/sessions.conf"

if [ -f "$_conf_user" ]; then
    # shellcheck source=/dev/null
    source "$_conf_user"
elif [ -f "$_conf_proj" ]; then
    # shellcheck source=/dev/null
    source "$_conf_proj"
fi

# ── AI tool detection ─────────────────────────────────────────────────────────
detect_ai_cmd() {
    if [ -n "${DEV_AI_CMD:-}" ]; then
        echo "$DEV_AI_CMD"
    elif command -v claude &>/dev/null; then
        echo "claude"
    elif command -v aider &>/dev/null; then
        echo "aider"
    else
        echo ""
    fi
}

# ── Session creation ──────────────────────────────────────────────────────────
create_main_session() {
    tmux has-session -t main 2>/dev/null && return 0
    # Persistent shell window keeps the session alive when the menu window exits
    tmux new-session -d -s main -n "shell"
    tmux new-window -t main: -n "menu" "$MENU_SCRIPT"
    tmux select-window -t main:menu
}

# create_session NAME DIR INIT_CMD [ENV_VARS]
create_session() {
    local name="$1"
    local dir="${2:-$HOME}"
    local init_cmd="${3:-}"
    local env_vars="${4:-}"

    tmux has-session -t "$name" 2>/dev/null && return 0

    [ -d "$dir" ] || dir="$HOME"
    tmux new-session -d -s "$name" -n "$name" -c "$dir"

    # Apply per-session environment variables (in tmux's env table and the shell)
    if [ -n "$env_vars" ]; then
        for kv in $env_vars; do
            local key="${kv%%=*}"
            local val="${kv#*=}"
            tmux set-environment -t "$name" "$key" "$val"
            tmux send-keys -t "$name:$name" "export $kv" Enter
        done
    fi

    case "$init_cmd" in
        "auto")
            local ai_cmd
            ai_cmd="$(detect_ai_cmd)"
            if [ -n "$ai_cmd" ]; then
                tmux send-keys -t "$name:$name" "$ai_cmd" Enter
            else
                tmux send-keys -t "$name:$name" \
                    'echo "No AI tool found. Install claude or aider, or set DEV_AI_CMD."' Enter
            fi
            tmux new-window -t "${name}:" -n "scratch" -c "$dir"
            tmux select-window -t "$name:$name"
            ;;
        "")
            tmux new-window -t "${name}:" -n "shell" -c "$dir"
            tmux select-window -t "$name:$name"
            ;;
        *)
            tmux send-keys -t "$name:$name" "$init_cmd" Enter
            tmux new-window -t "${name}:" -n "shell" -c "$dir"
            tmux select-window -t "$name:$name"
            ;;
    esac
}

# Find session by name and create it
create_named_session() {
    local target="$1"
    local i
    for i in "${!SESSIONS[@]}"; do
        if [[ "${SESSIONS[$i]}" == "$target" ]]; then
            create_session "$target" "${DIRS[$i]:-$HOME}" "${INIT_CMDS[$i]:-}" "${SESSION_ENVS[$i]:-}"
            return 0
        fi
    done
    echo "Unknown session: $target" >&2
    echo "Configured sessions: ${SESSIONS[*]}" >&2
    exit 1
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
TARGET="${1:-all}"

case "$TARGET" in
    main)
        create_main_session
        ;;
    all)
        for i in "${!SESSIONS[@]}"; do
            create_session "${SESSIONS[$i]}" "${DIRS[$i]:-$HOME}" "${INIT_CMDS[$i]:-}" "${SESSION_ENVS[$i]:-}"
        done
        create_main_session   # main last so its menu can reference the others
        ;;
    *)
        create_named_session "$TARGET"
        ;;
esac
