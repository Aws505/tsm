#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# tsm — tmux session manager launcher
#
# Installed as ~/.local/bin/tsm by install.sh.
# Works both inside and outside an existing tmux client.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Resolve real path even when invoked through a symlink
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
START_SCRIPT="$SCRIPT_DIR/start-sessions.sh"
MENU_SCRIPT="$SCRIPT_DIR/session-menu.sh"

# Defaults first; config overrides them.
SESSIONS=( code dev codex relay share other )
LABELS=( "Project workspace" "Claude" "Codex" "Relay" "Share" "General shell" )
KEYS=( e d x r h o )
DIRS=( "$HOME/Projects" "$HOME/Projects" "$HOME/Projects" "$HOME" "$HOME" "$HOME" )
INIT_CMDS=( "" "claude" "codex" "" "" "" )
SESSION_ENVS=( "" "" "CODEX_DISABLE_SANDBOX=1" "" "" "" )
SHOW_IPS=()
MENU_KEY=m
CONFIG_SOURCE="$REPO_DIR/conf/sessions.conf (defaults only)"

load_config() {
    local user_conf="$HOME/.config/tsm/sessions.conf"
    local project_conf="$REPO_DIR/conf/sessions.conf"

    if [ -f "$user_conf" ]; then
        # shellcheck source=/dev/null
        source "$user_conf"
        CONFIG_SOURCE="$user_conf"
    elif [ -f "$project_conf" ]; then
        # shellcheck source=/dev/null
        source "$project_conf"
        CONFIG_SOURCE="$project_conf"
    fi
}

print_session_table() {
    local i init env_summary
    printf 'Configured sessions:\n'
    printf '  %-8s %-4s %-20s %-20s %s\n' "name" "key" "label" "init" "dir"
    for i in "${!SESSIONS[@]}"; do
        init="${INIT_CMDS[$i]:-}"
        [ -n "$init" ] || init="shell"
        env_summary="${SESSION_ENVS[$i]:-}"
        printf '  %-8s %-4s %-20s %-20s %s\n' \
            "${SESSIONS[$i]}" \
            "${KEYS[$i]:--}" \
            "${LABELS[$i]:-${SESSIONS[$i]}}" \
            "$init" \
            "${DIRS[$i]:-$HOME}"
        if [ -n "$env_summary" ]; then
            printf '  %-8s %-4s %-20s %-20s %s\n' "" "" "" "env" "$env_summary"
        fi
    done
}

print_help() {
    load_config
    cat <<EOF
Usage:
  tsm
  tsm menu
  tsm start [all|main|SESSION]
  tsm attach [SESSION]
  tsm list
  tsm help

Commands:
  menu     Ensure the menu session exists, then switch/attach to main:menu.
           This is the default command when no arguments are provided.
  start    Create missing sessions without attaching. Targets the same names
           accepted by scripts/start-sessions.sh: all, main, or one session.
  attach   Attach or switch directly to a tmux session. If the target session
           does not exist yet, tsm creates it first.
  list     Print the configured sessions, key bindings, startup commands, and
           working directories from the active sessions config.
  help     Show this help text.

Behavior:
  Inside tmux:
    tsm/menu ensures main exists, recreates the menu window if needed, then
    runs "tmux switch-client -t main:menu".
  Outside tmux:
    tsm/menu bootstraps all configured sessions and runs
    "tmux attach-session -t main".
  Session startup:
    INIT_CMDS="" creates a plain shell window.
    INIT_CMDS="auto" launches DEV_AI_CMD, claude, or aider if found.
    INIT_CMDS="claude" or "codex" launches that command explicitly.
    Any other INIT_CMD is sent verbatim to the first shell window.
  Environment:
    SESSION_ENVS values are applied to tmux's per-session environment and
    exported into the initial shell before INIT_CMDS runs.

Files:
  repo:          $REPO_DIR
  sessions:      $CONFIG_SOURCE
  tmux config:   $REPO_DIR/conf/tmux.conf
  launcher:      $START_SCRIPT
  menu:          $MENU_SCRIPT

Dependencies:
  Required: bash, tmux, and standard shell utilities used by the scripts
            (awk, grep, sed, readlink, date, wc, chmod, ln, cp).
  Optional: ip (for SHOW_IPS in the menu), claude/aider (for INIT_CMDS=auto),
            codex (for INIT_CMDS=codex).
  Assumptions: Linux-style userland; install.sh uses readlink -f, sed -i, and iproute2 tooling.

EOF
    print_session_table
}

ensure_main_menu() {
    if ! tmux has-session -t main 2>/dev/null; then
        bash "$START_SCRIPT" main
    fi
    if ! tmux list-windows -t main -F '#{window_name}' 2>/dev/null | grep -q '^menu$'; then
        tmux new-window -t main: -n "menu" "$MENU_SCRIPT"
    fi
}

cmd_menu() {
    if [ -n "${TMUX:-}" ]; then
        ensure_main_menu
        tmux switch-client -t main:menu
    else
        bash "$START_SCRIPT" all
        exec tmux attach-session -t main
    fi
}

cmd_start() {
    local target="${1:-all}"
    bash "$START_SCRIPT" "$target"
}

cmd_attach() {
    local target="${1:-main}"

    if ! tmux has-session -t "$target" 2>/dev/null; then
        if [ "$target" = "main" ]; then
            bash "$START_SCRIPT" main
        else
            bash "$START_SCRIPT" "$target"
        fi
    fi

    if [ -n "${TMUX:-}" ]; then
        tmux switch-client -t "$target"
    else
        exec tmux attach-session -t "$target"
    fi
}

cmd_list() {
    load_config
    printf 'Active config: %s\n\n' "$CONFIG_SOURCE"
    print_session_table
}

main() {
    local command="${1:-menu}"

    case "$command" in
        menu)
            cmd_menu
            ;;
        start)
            cmd_start "${2:-all}"
            ;;
        attach)
            cmd_attach "${2:-main}"
            ;;
        list|ls)
            cmd_list
            ;;
        help|-h|--help)
            print_help
            ;;
        *)
            printf 'Unknown command: %s\n\n' "$command" >&2
            print_help >&2
            exit 1
            ;;
    esac
}

main "$@"
