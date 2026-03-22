#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# session-menu.sh — Interactive tmux session switcher with arrow-key navigation
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/start-sessions.sh"

# ── Load config ───────────────────────────────────────────────────────────────
# Defaults first; config overrides them.
SESSIONS=( code dev codex relay share other )
LABELS=( "Project workspace" "Claude" "Codex" "Relay" "Share" "General shell" )
KEYS=( e d x r h o )
SHOW_IPS=()

_conf_user="$HOME/.config/tsm/sessions.conf"
_conf_proj="$(dirname "$SCRIPT_DIR")/conf/sessions.conf"

if [ -f "$_conf_user" ]; then
    # shellcheck source=/dev/null
    source "$_conf_user"
elif [ -f "$_conf_proj" ]; then
    # shellcheck source=/dev/null
    source "$_conf_proj"
fi

# ── IP address display ────────────────────────────────────────────────────────
# Returns a formatted string of "iface IP" pairs for each interface in SHOW_IPS.
# Interfaces without an IPv4 address are shown as "down".
get_ip_addresses() {
    local parts=() iface ip
    for iface in "${SHOW_IPS[@]}"; do
        ip=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]; exit}')
        if [ -n "$ip" ]; then
            parts+=( "$(printf '\033[1;36m%s\033[0m \033[0;37m%s\033[0m' "$iface" "$ip")" )
        else
            parts+=( "$(printf '\033[1;36m%s\033[0m \033[1;31mdown\033[0m' "$iface")" )
        fi
    done
    local result="" part
    for part in "${parts[@]}"; do
        [ -n "$result" ] && result+="  \033[90m·\033[0m  "
        result+="$part"
    done
    printf '%s' "$result"
}

# ── Key reading (arrow-key aware) ─────────────────────────────────────────────
read_key() {
    local key seq1 seq2
    # 30-second timeout → auto-refresh to keep status current
    if ! IFS= read -rsn1 -t 30 key; then
        printf 'TIMEOUT'
        return
    fi
    if [[ "$key" == $'\x1b' ]]; then
        IFS= read -rsn1 -t 0.1 seq1 2>/dev/null || true
        IFS= read -rsn1 -t 0.1 seq2 2>/dev/null || true
        case "${seq1}${seq2}" in
            '[A') printf 'UP'   ;;
            '[B') printf 'DOWN' ;;
            '')   printf 'ESC'  ;;
            *)    printf ''     ;;
        esac
    elif [[ "$key" == '' ]]; then
        printf 'ENTER'
    else
        printf '%s' "$key"
    fi
}

# ── Session status helper ─────────────────────────────────────────────────────
session_status() {
    local name="$1"
    if ! tmux has-session -t "$name" 2>/dev/null; then
        printf '\033[1;31mstopped\033[0m'
        return
    fi
    local clients
    clients=$(tmux list-clients -t "$name" 2>/dev/null | wc -l)
    if [ "$clients" -gt 0 ]; then
        printf '\033[1;32mactive (%s)\033[0m' "$clients"
    else
        printf '\033[1;33midle\033[0m'
    fi
}

# ── Menu renderer ─────────────────────────────────────────────────────────────
draw_menu() {
    local selected="$1"
    clear
    printf '\033[1;34m'
    printf '┌──────────────────────────────────────────┐\n'
    printf '│         TMUX SESSION MANAGER             │\n'
    printf '└──────────────────────────────────────────┘\n'
    printf '\033[0m'
    printf '\033[90m  current: \033[1;36mmain\033[90m  %s\033[0m\n' "$(date '+%H:%M')"
    if [ ${#SHOW_IPS[@]} -gt 0 ]; then
        printf '  %b\n' "$(get_ip_addresses)"
    fi
    printf '\n'

    local i
    for i in "${!SESSIONS[@]}"; do
        local name="${SESSIONS[$i]}"
        local label="${LABELS[$i]:-$name}"
        local key_hint="${KEYS[$i]:- }"
        local status
        status="$(session_status "$name")"

        if [[ "$i" -eq "$selected" ]]; then
            printf '  \033[1;33m▶\033[0m \033[7m\033[1;37m [%d] %-7s ^a·%-1s  %-19s \033[0m  %b\n' \
                   "$((i+1))" "$name" "$key_hint" "$label" "$status"
        else
            printf '    \033[1;37m[%d]\033[0m \033[1;36m%-7s\033[0m \033[90m^a·%-1s\033[0m  %-19s  %b\n' \
                   "$((i+1))" "$name" "$key_hint" "$label" "$status"
        fi
    done

    printf '\n'
    printf '  \033[90m──────────────────────────────────────────\033[0m\n'
    printf '  \033[90m↑/↓  navigate     Enter/[num]  select\033[0m\n'
    printf '  \033[90m[r]  refresh  [s] start all  [q]  quit\033[0m\n'
    printf '  \033[90m[k]  kill ALL sessions and exit\033[0m\n'
    printf '\n'
    printf '  \033[90m──────────────────────────────────────────\033[0m\n'
    printf '  \033[1;34mtmux cheat sheet\033[90m  prefix: \033[1;33m^a\033[90m (C-a)\033[0m\n'
    printf '  \033[90m^a n  next window  ^a l  last window\033[0m\n'
    printf '  \033[90m^a |  split →      ^a -  split ↓\033[0m\n'
    printf '  \033[90m^a c  new window   ^a d  detach\033[0m\n'
    printf '  \033[90mAlt+↑↓←→ pane nav  ^a [  copy mode\033[0m\n'
    printf '\n'
}

# ── Actions ───────────────────────────────────────────────────────────────────
switch_to() {
    local target="$1"
    if ! tmux has-session -t "$target" 2>/dev/null; then
        tput cnorm 2>/dev/null
        printf '\n\033[33mStarting session "%s"...\033[0m\n' "$target"
        bash "$START_SCRIPT" "$target"
        sleep 0.5
        tput civis 2>/dev/null
    fi
    tmux switch-client -t "$target"
}

start_all_stopped() {
    tput cnorm 2>/dev/null
    printf '\n\033[33mStarting all sessions...\033[0m\n'
    bash "$START_SCRIPT" all
    sleep 0.8
    tput civis 2>/dev/null
}

kill_all_sessions() {
    tput cnorm 2>/dev/null
    clear
    printf '\033[1;31m'
    printf '┌──────────────────────────────────────────┐\n'
    printf '│           ⚠  KILL ALL SESSIONS           │\n'
    printf '└──────────────────────────────────────────┘\n'
    printf '\033[0m\n'

    # List running sessions
    local running=()
    local s
    for s in main "${SESSIONS[@]}"; do
        tmux has-session -t "$s" 2>/dev/null && running+=( "$s" )
    done

    if [ ${#running[@]} -eq 0 ]; then
        printf '  No sessions are running.\n\n'
        printf 'Press any key...'
        read -rsn1
        tput civis 2>/dev/null
        return
    fi

    printf '  This will kill the following tmux sessions:\n\n'
    for s in "${running[@]}"; do
        printf '    \033[1;31m✗\033[0m  %s\n' "$s"
    done
    printf '\n'
    printf '  \033[1;33mAll tmux panes, windows, and processes in\033[0m\n'
    printf '  \033[1;33mthese sessions will be terminated.\033[0m\n'
    printf '\n'
    printf '  Type \033[1;31mYES\033[0m and Enter to confirm, or anything else to cancel: '

    local confirm
    IFS= read -r confirm
    if [[ "$confirm" == "YES" ]]; then
        for s in "${SESSIONS[@]}"; do
            tmux kill-session -t "$s" 2>/dev/null || true
        done
        # Kill main last (we're in it) — tmux will drop us to the shell
        tmux kill-session -t main 2>/dev/null || true
        # If still alive, just exit
        exit 0
    else
        printf '\n  \033[90mCancelled.\033[0m\n'
        sleep 1
        tput civis 2>/dev/null
    fi
}

# ── Main loop ─────────────────────────────────────────────────────────────────
trap 'tput cnorm 2>/dev/null; printf "\n\033[90mExiting menu.\033[0m\n"' EXIT

tput civis 2>/dev/null   # hide cursor during menu

SELECTED=0

while true; do
    draw_menu "$SELECTED"
    key="$(read_key)"

    case "$key" in
        UP)
            (( SELECTED = (SELECTED - 1 + ${#SESSIONS[@]}) % ${#SESSIONS[@]} ))
            ;;
        DOWN)
            (( SELECTED = (SELECTED + 1) % ${#SESSIONS[@]} ))
            ;;
        ENTER)
            switch_to "${SESSIONS[$SELECTED]}"
            ;;
        [1-9])
            _idx=$((key - 1))
            if [[ $_idx -lt ${#SESSIONS[@]} ]]; then
                SELECTED=$_idx
                switch_to "${SESSIONS[$SELECTED]}"
            fi
            ;;
        r|R) continue ;;
        s|S) start_all_stopped ;;
        k|K) kill_all_sessions ;;
        q|Q) break ;;
        TIMEOUT|ESC|'') continue ;;
    esac
done
