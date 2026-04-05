#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# session-menu.sh — Interactive tmux session switcher with session management
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/start-sessions.sh"

# ── Load config ───────────────────────────────────────────────────────────────
# Defaults first; config overrides them.
SESSIONS=( code dev codex relay share other )
LABELS=( "Project workspace" "Claude" "Codex" "Relay" "Share" "General shell" )
KEYS=( e d x r h o )
DIRS=( "$HOME/Projects" "$HOME/Projects" "$HOME/Projects" "$HOME" "$HOME" "$HOME" )
INIT_CMDS=( "" "claude" "codex" "" "" "" )
SESSION_ENVS=( "" "" "CODEX_DISABLE_SANDBOX=1" "" "" "" )
SHOW_IPS=()
MENU_KEY=m

# Track which file to persist changes to.  Defaults to the user conf so we
# never auto-write to the git-tracked project conf; updated if the user conf
# is the one that was actually sourced.
CONF_FILE="$HOME/.config/tsm/sessions.conf"

_conf_user="$HOME/.config/tsm/sessions.conf"
_conf_proj="$(dirname "$SCRIPT_DIR")/conf/sessions.conf"

if [ -f "$_conf_user" ]; then
    # shellcheck source=/dev/null
    source "$_conf_user"
    CONF_FILE="$_conf_user"
elif [ -f "$_conf_proj" ]; then
    # shellcheck source=/dev/null
    source "$_conf_proj"
    CONF_FILE="$_conf_proj"
fi

# ── Detect menu session key from tmux config ──────────────────────────────────
# Finds the prefix+key bound to 'switch-client -t main' (simple switch, not the
# send-Enter variant).  Resolution order:
#   1. ~/.tmux.conf and any source-file it includes (one level deep) — file-based,
#      works offline, authoritative for most setups
#   2. tmux list-keys — live config, picks up runtime overrides and %include'd files
#   3. MENU_KEY from sessions.conf (default: m) — explicit override / last resort
_resolve_menu_key() {
    local key cfg="${HOME}/.tmux.conf"
    # awk program shared for both the top-level file and any source-file targets:
    # Matches: bind-key [-r] KEY run-shell '... switch-client -t main ... tmux display ...'
    # Extracts: first single-character, non-flag token after "bind-key".
    local awk_prog='
        /bind-key/ && /switch-client/ && /-t main/ && /tmux display/ {
            for (i = 2; i <= NF; i++) {
                if ($i !~ /^-/ && length($i) == 1) { print $i; exit }
            }
        }'

    # 1. Parse ~/.tmux.conf; follow source-file / source directives one level deep.
    if [ -f "$cfg" ]; then
        key=$(awk "$awk_prog" "$cfg")
        if [ -z "$key" ]; then
            local src_path
            while IFS= read -r src_path; do
                src_path="${src_path/#\~/$HOME}"          # expand leading ~
                [ -f "$src_path" ] || continue
                key=$(awk "$awk_prog" "$src_path")
                [ -n "$key" ] && break
            done < <(awk '/^source(-file)?[[:space:]]/ {
                             gsub(/["\x27]/, "", $NF); print $NF }' "$cfg")
        fi
    fi

    # 2. Fall back to live tmux key table (handles %include and runtime overrides).
    #    Line form: bind-key -T prefix KEY run-shell ...
    if [ -z "$key" ]; then
        key=$(tmux list-keys 2>/dev/null | \
              awk '$3 == "prefix" && /switch-client/ && /-t main/ && /tmux display/ \
                   { print $4; exit }')
    fi

    # 3. Fall back to sessions.conf MENU_KEY, then hard-coded default.
    printf '%s' "${key:-${MENU_KEY:-m}}"
}
MENU_KEY=$(_resolve_menu_key)
unset -f _resolve_menu_key

# ── Config persistence ────────────────────────────────────────────────────────
# Serialises the current in-memory session arrays back to CONF_FILE.
# Called after every add / edit / delete so changes survive restarts.
write_config() {
    mkdir -p "$(dirname "$CONF_FILE")"
    local tmp
    tmp="$(mktemp)"
    {
        printf '# sessions.conf — managed by tsm (updated %s)\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf '# Edit directly or via: tsm menu → [e] Manage sessions\n\n'

        printf 'SESSIONS=('
        local s; for s in "${SESSIONS[@]}"; do printf ' %s' "$s"; done
        printf ' )\n\n'

        printf 'LABELS=('
        local l; for l in "${LABELS[@]}"; do printf ' "%s"' "${l//\"/\\\"}"; done
        printf ' )\n\n'

        printf 'KEYS=('
        local k; for k in "${KEYS[@]}"; do printf ' %s' "${k:- }"; done
        printf ' )\n\n'

        printf 'DIRS=('
        local d; for d in "${DIRS[@]}"; do printf ' "%s"' "${d//\"/\\\"}"; done
        printf ' )\n\n'

        printf 'INIT_CMDS=('
        local c; for c in "${INIT_CMDS[@]}"; do printf ' "%s"' "${c//\"/\\\"}"; done
        printf ' )\n\n'

        printf 'SESSION_ENVS=('
        local e; for e in "${SESSION_ENVS[@]}"; do printf ' "%s"' "${e//\"/\\\"}"; done
        printf ' )\n\n'

        printf 'SHOW_IPS=('
        local f; for f in "${SHOW_IPS[@]}"; do printf ' %s' "$f"; done
        printf ' )\n\n'

        printf 'MENU_KEY=%s\n' "$MENU_KEY"
    } > "$tmp"
    mv "$tmp" "$CONF_FILE"
}

# ── Live tmux binding sync ────────────────────────────────────────────────────
# Pushes the current SESSIONS / KEYS arrays into the live tmux server so that
# Prefix+key shortcuts and the status-bar hints are immediately correct.
# Does NOT modify any file — operates only on the running server.
apply_live_tmux_bindings() {
    tmux list-sessions &>/dev/null || return 0   # no server running — nothing to do

    local i name key hints=""
    for i in "${!SESSIONS[@]}"; do
        name="${SESSIONS[$i]}"
        key="${KEYS[$i]:-}"
        [ -z "$key" ] && continue
        tmux bind-key "$key" run-shell \
            "tmux switch-client -t ${name} 2>/dev/null || tmux display '${name} not running'" \
            2>/dev/null || true
        [ -n "$hints" ] && hints+=" "
        hints+="${key}:${name}"
    done

    # Rebuild the status-right hint string
    tmux set-option -g status-right "#[fg=#636da6]${hints}  #[fg=#82aaff]%H:%M" 2>/dev/null || true
}

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
    printf '\033[90m  current: \033[1;36mmain\033[90m  ^a·\033[1;33m%s\033[90m  %s\033[0m\n' "$MENU_KEY" "$(date '+%H:%M')"
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
    printf '  \033[90m[e]  manage sessions  [k]  kill ALL\033[0m\n'
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

# ── Session management sub-menu ───────────────────────────────────────────────

draw_manage_menu() {
    local selected="$1"
    local n="${#SESSIONS[@]}"
    clear
    printf '\033[1;34m┌──────────────────────────────────────────┐\n'
    printf '│         MANAGE SESSIONS                  │\n'
    printf '└──────────────────────────────────────────┘\033[0m\n'
    printf '  \033[90mConfig: %s\033[0m\n\n' "$CONF_FILE"

    local i
    for i in "${!SESSIONS[@]}"; do
        local name="${SESSIONS[$i]}"
        local label="${LABELS[$i]:-$name}"
        local key="${KEYS[$i]:- }"
        local status
        status="$(session_status "$name")"
        if [[ "$i" -eq "$selected" ]]; then
            printf '  \033[1;33m▶\033[0m \033[7m [%d] %-8s ^a·%-1s  %-20s \033[0m  %b\n' \
                   "$((i+1))" "$name" "$key" "$label" "$status"
        else
            printf '    \033[0;37m[%d]\033[0m \033[1;36m%-8s\033[0m \033[90m^a·%-1s\033[0m  %-20s  %b\n' \
                   "$((i+1))" "$name" "$key" "$label" "$status"
        fi
    done

    if [[ "$selected" -eq "$n" ]]; then
        printf '  \033[1;33m▶\033[0m \033[7m  + Add new session                               \033[0m\n'
    else
        printf '    \033[1;32m+\033[0m \033[90mAdd new session\033[0m\n'
    fi

    printf '\n  \033[90m──────────────────────────────────────────\033[0m\n'
    printf '  \033[90m↑/↓  navigate  Enter  edit/add  [d]  delete\033[0m\n'
    printf '  \033[90m[a]  add new session   [q]  back to menu\033[0m\n\n'
}

# edit_session_dialog IDX
# IDX = array index to edit, or -1 to add a new session.
# Returns 0 on save, 1 on cancel.
edit_session_dialog() {
    local idx="$1"
    local adding=false
    [[ "$idx" -lt 0 ]] && adding=true

    tput cnorm 2>/dev/null
    clear

    if $adding; then
        printf '\033[1;34m┌──────────────────────────────────────────┐\n'
        printf '│           ADD NEW SESSION                │\n'
        printf '└──────────────────────────────────────────┘\033[0m\n'
    else
        printf '\033[1;34m┌──────────────────────────────────────────┐\n'
        printf '│  EDIT SESSION: %-26s│\n' "${SESSIONS[$idx]}"
        printf '└──────────────────────────────────────────┘\033[0m\n'
    fi
    printf '\n  \033[90mEdit each field and press Enter to confirm it.\033[0m\n'
    printf '  \033[90mDelete the prefilled text to clear a field. Ctrl+C to cancel.\033[0m\n\n'

    local cur_name="${SESSIONS[$idx]:-}"
    local cur_label="${LABELS[$idx]:-}"
    local cur_key="${KEYS[$idx]:-}"
    local cur_dir="${DIRS[$idx]:-$HOME}"
    local cur_init="${INIT_CMDS[$idx]:-}"
    local cur_env="${SESSION_ENVS[$idx]:-}"
    local new_name new_label new_key new_dir new_init new_env

    # ── Session name ──────────────────────────────────────────────────────────
    while true; do
        printf '  \033[1;37mSession name\033[0m \033[90m(letters/digits/-/_)\033[0m: '
        read -r -e -i "$cur_name" new_name
        [ -z "$new_name" ] && new_name="$cur_name"
        if [[ -z "$new_name" ]]; then
            printf '  \033[33mName is required.\033[0m\n'; continue
        fi
        if [[ ! "$new_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            printf '  \033[33mUse only letters, digits, hyphens, underscores.\033[0m\n'; continue
        fi
        local dup=false j
        for j in "${!SESSIONS[@]}"; do
            if ! $adding && [[ "$j" -eq "$idx" ]]; then continue; fi
            if [[ "${SESSIONS[$j]}" == "$new_name" ]]; then dup=true; break; fi
        done
        if $dup; then
            printf '  \033[33mSession "%s" already exists.\033[0m\n' "$new_name"; continue
        fi
        break
    done

    # ── Display label ─────────────────────────────────────────────────────────
    printf '  \033[1;37mDisplay label\033[0m: '
    read -r -e -i "$cur_label" new_label
    [ -z "$new_label" ] && new_label="$cur_label"

    # ── Quick-switch key ──────────────────────────────────────────────────────
    while true; do
        printf '  \033[1;37mQuick-switch key\033[0m \033[90m(single char, Prefix+key; blank=none)\033[0m: '
        read -r -e -i "$cur_key" new_key
        if [[ -n "$new_key" ]] && [[ ${#new_key} -gt 1 ]]; then
            printf '  \033[33mMust be a single character (or blank for none).\033[0m\n'; continue
        fi
        if [[ -n "$new_key" ]]; then
            local conflict=false
            for j in "${!SESSIONS[@]}"; do
                if ! $adding && [[ "$j" -eq "$idx" ]]; then continue; fi
                if [[ "${KEYS[$j]}" == "$new_key" ]]; then conflict=true; break; fi
            done
            if $conflict; then
                printf '  \033[33mKey "%s" is already used by another session.\033[0m\n' "$new_key"
                continue
            fi
        fi
        break
    done

    # ── Working directory ─────────────────────────────────────────────────────
    printf '  \033[1;37mWorking directory\033[0m: '
    read -r -e -i "$cur_dir" new_dir
    [ -z "$new_dir" ] && new_dir="$cur_dir"
    new_dir="${new_dir/#\~/$HOME}"   # expand leading ~

    # ── Init command ──────────────────────────────────────────────────────────
    printf '  \033[1;37mInit command\033[0m \033[90m(empty=shell · auto · claude · codex · any cmd)\033[0m: '
    read -r -e -i "$cur_init" new_init
    # Empty is valid — means "plain shell"; keep whatever the user typed.

    # ── Environment vars ──────────────────────────────────────────────────────
    printf '  \033[1;37mEnvironment vars\033[0m \033[90m(KEY=VAL KEY2=VAL2 …  or empty)\033[0m: '
    read -r -e -i "$cur_env" new_env

    # ── Confirm ───────────────────────────────────────────────────────────────
    printf '\n  \033[1;37mSave?\033[0m [Y/n]: '
    local confirm
    read -r confirm
    case "${confirm:-Y}" in
        [Nn]*)
            printf '  \033[90mCancelled.\033[0m\n'; sleep 0.8
            tput civis 2>/dev/null
            return 1
            ;;
    esac

    # ── Apply to arrays ───────────────────────────────────────────────────────
    local old_key="$cur_key"
    if $adding; then
        SESSIONS+=( "$new_name" )
        LABELS+=( "$new_label" )
        KEYS+=( "$new_key" )
        DIRS+=( "$new_dir" )
        INIT_CMDS+=( "$new_init" )
        SESSION_ENVS+=( "$new_env" )
    else
        # Rename live tmux session if it exists
        if [[ "$new_name" != "$cur_name" ]] && tmux has-session -t "$cur_name" 2>/dev/null; then
            tmux rename-session -t "$cur_name" "$new_name" 2>/dev/null || true
        fi
        SESSIONS[$idx]="$new_name"
        LABELS[$idx]="$new_label"
        KEYS[$idx]="$new_key"
        DIRS[$idx]="$new_dir"
        INIT_CMDS[$idx]="$new_init"
        SESSION_ENVS[$idx]="$new_env"
    fi

    # Unbind stale key from live tmux when the key was changed or cleared
    if [[ -n "$old_key" ]] && [[ "$old_key" != "$new_key" ]]; then
        tmux unbind-key "$old_key" 2>/dev/null || true
    fi

    write_config
    apply_live_tmux_bindings

    if $adding; then
        printf '\n  \033[1;32mSession "%s" added.\033[0m\n' "$new_name"
        printf '  Start it now? [Y/n]: '
        local start_now
        read -r start_now
        case "${start_now:-Y}" in
            [Yy]*|"")
                printf '  \033[33mStarting "%s"...\033[0m\n' "$new_name"
                bash "$START_SCRIPT" "$new_name" 2>&1 || true
                sleep 0.5
                ;;
        esac
    else
        printf '\n  \033[1;32mSession "%s" updated.\033[0m\n' "$new_name"
        sleep 0.8
    fi

    tput civis 2>/dev/null
    return 0
}

# delete_session_confirm IDX
# Prompts for confirmation then removes the session from all arrays.
# Returns 0 if deleted, 1 if cancelled.
delete_session_confirm() {
    local idx="$1"
    local name="${SESSIONS[$idx]}"

    tput cnorm 2>/dev/null
    clear
    printf '\033[1;31m┌──────────────────────────────────────────┐\n'
    printf '│  DELETE SESSION: %-24s│\n' "$name"
    printf '└──────────────────────────────────────────┘\033[0m\n\n'

    printf '  Name:    \033[1;36m%s\033[0m\n'  "$name"
    printf '  Label:   %s\n'  "${LABELS[$idx]:-$name}"
    printf '  Key:     ^a·%s\n' "${KEYS[$idx]:--}"
    printf '  Dir:     %s\n'  "${DIRS[$idx]:-$HOME}"
    printf '  Init:    %s\n'  "${INIT_CMDS[$idx]:-(shell)}"
    printf '\n'

    if tmux has-session -t "$name" 2>/dev/null; then
        printf '  \033[1;33mNote: session is currently running. It will NOT be\033[0m\n'
        printf '  \033[1;33mkilled — only removed from tsm management.\033[0m\n\n'
    fi

    printf '  Type \033[1;31mYES\033[0m and Enter to confirm, anything else to cancel: '
    local confirm
    IFS= read -r confirm

    if [[ "$confirm" == "YES" ]]; then
        local old_key="${KEYS[$idx]:-}"

        # Remove index from every array
        SESSIONS=(     "${SESSIONS[@]:0:$idx}"     "${SESSIONS[@]:$(( idx + 1 ))}" )
        LABELS=(       "${LABELS[@]:0:$idx}"       "${LABELS[@]:$(( idx + 1 ))}" )
        KEYS=(         "${KEYS[@]:0:$idx}"         "${KEYS[@]:$(( idx + 1 ))}" )
        DIRS=(         "${DIRS[@]:0:$idx}"         "${DIRS[@]:$(( idx + 1 ))}" )
        INIT_CMDS=(    "${INIT_CMDS[@]:0:$idx}"    "${INIT_CMDS[@]:$(( idx + 1 ))}" )
        SESSION_ENVS=( "${SESSION_ENVS[@]:0:$idx}" "${SESSION_ENVS[@]:$(( idx + 1 ))}" )

        [ -n "$old_key" ] && tmux unbind-key "$old_key" 2>/dev/null || true

        write_config
        apply_live_tmux_bindings

        printf '\n  \033[1;32mSession "%s" removed from tsm.\033[0m\n' "$name"
        sleep 1
        tput civis 2>/dev/null
        return 0
    else
        printf '\n  \033[90mCancelled.\033[0m\n'
        sleep 0.8
        tput civis 2>/dev/null
        return 1
    fi
}

# manage_sessions_menu — interactive sub-menu for adding, editing, and removing sessions
manage_sessions_menu() {
    local mgmt_sel=0

    while true; do
        local n="${#SESSIONS[@]}"
        # Guard: clamp selection within [0, n] (n = "Add new" slot)
        (( mgmt_sel > n )) && mgmt_sel=$n

        draw_manage_menu "$mgmt_sel"
        local key
        key="$(read_key)"

        case "$key" in
            UP)
                (( mgmt_sel = (mgmt_sel - 1 + n + 1) % (n + 1) ))
                ;;
            DOWN)
                (( mgmt_sel = (mgmt_sel + 1) % (n + 1) ))
                ;;
            ENTER)
                if [[ "$mgmt_sel" -eq "$n" ]]; then
                    edit_session_dialog -1 || true
                    mgmt_sel=$n   # land on "Add new" so the user can keep adding
                else
                    edit_session_dialog "$mgmt_sel" || true
                fi
                ;;
            d|D)
                if [[ "$mgmt_sel" -lt "$n" ]] && [[ "$n" -gt 0 ]]; then
                    if delete_session_confirm "$mgmt_sel"; then
                        local new_n="${#SESSIONS[@]}"
                        (( mgmt_sel >= new_n && new_n > 0 )) && mgmt_sel=$(( new_n - 1 ))
                        (( new_n == 0 )) && mgmt_sel=0
                    fi
                fi
                ;;
            a|A)
                edit_session_dialog -1 || true
                mgmt_sel="${#SESSIONS[@]}"   # land after the newly added entry
                (( mgmt_sel > 0 )) && mgmt_sel=$(( mgmt_sel - 1 ))
                ;;
            [1-9])
                local _idx=$(( key - 1 ))
                (( _idx < n )) && mgmt_sel=$_idx
                ;;
            q|Q|ESC)
                return
                ;;
            TIMEOUT|'') continue ;;
        esac
    done
}

# ── Main loop ─────────────────────────────────────────────────────────────────
trap 'tput cnorm 2>/dev/null; printf "\n\033[90mExiting menu.\033[0m\n"' EXIT

tput civis 2>/dev/null   # hide cursor during menu navigation

# Sync live tmux bindings at startup so Prefix+key shortcuts match sessions.conf
apply_live_tmux_bindings

SELECTED=0

while true; do
    # Guard against empty sessions list (all deleted)
    if [[ "${#SESSIONS[@]}" -eq 0 ]]; then
        SELECTED=0
    elif (( SELECTED >= ${#SESSIONS[@]} )); then
        SELECTED=$(( ${#SESSIONS[@]} - 1 ))
    fi

    draw_menu "$SELECTED"
    key="$(read_key)"

    case "$key" in
        UP)
            [[ "${#SESSIONS[@]}" -gt 0 ]] && \
                (( SELECTED = (SELECTED - 1 + ${#SESSIONS[@]}) % ${#SESSIONS[@]} ))
            ;;
        DOWN)
            [[ "${#SESSIONS[@]}" -gt 0 ]] && \
                (( SELECTED = (SELECTED + 1) % ${#SESSIONS[@]} ))
            ;;
        ENTER)
            [[ "${#SESSIONS[@]}" -gt 0 ]] && switch_to "${SESSIONS[$SELECTED]}"
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
        e|E) manage_sessions_menu ;;
        k|K) kill_all_sessions ;;
        q|Q) break ;;
        TIMEOUT|ESC|'') continue ;;
    esac
done
