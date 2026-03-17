#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — Wire up the tmux session manager
# Safe to run multiple times (idempotent).
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[  ok  ]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[ warn ]\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31m[ ERR  ]\033[0m %s\n' "$*" >&2; exit 1; }

# ── 1. Check dependencies ─────────────────────────────────────────────────────
info "Checking dependencies..."
command -v tmux &>/dev/null || die "tmux is not installed. Run: sudo apt install tmux"
ok "tmux $(tmux -V | awk '{print $2}')"

# ── 2. Make scripts executable ────────────────────────────────────────────────
info "Setting script permissions..."
chmod +x "$SCRIPT_DIR/scripts/start-sessions.sh"
chmod +x "$SCRIPT_DIR/scripts/session-menu.sh"
chmod +x "$SCRIPT_DIR/scripts/ssh-attach.sh"
chmod +x "$SCRIPT_DIR/scripts/tmsm.sh"
ok "Scripts are executable."

# ── 3. Install tmux.conf ──────────────────────────────────────────────────────
info "Installing tmux configuration..."
TMUX_CONF="$HOME/.tmux.conf"
CONF_SRC="$SCRIPT_DIR/conf/tmux.conf"

if [ -f "$TMUX_CONF" ] && ! grep -q "Phone-friendly tmux" "$TMUX_CONF" 2>/dev/null; then
    # Back up existing config
    cp "$TMUX_CONF" "$TMUX_CONF.bak.$(date +%Y%m%d%H%M%S)"
    warn "Existing ~/.tmux.conf backed up."
fi

# Use a source directive so the original file is not duplicated
MARKER="# managed by ~/Projects/tmux"
if ! grep -q "$MARKER" "$TMUX_CONF" 2>/dev/null; then
    cat > "$TMUX_CONF" <<EOF
$MARKER
source-file $CONF_SRC
EOF
    ok "~/.tmux.conf now sources $CONF_SRC"
else
    ok "~/.tmux.conf already configured."
fi

# ── 4. Reload live tmux server (if running) ───────────────────────────────────
if tmux list-sessions &>/dev/null 2>&1; then
    info "Reloading live tmux configuration..."
    tmux source-file "$HOME/.tmux.conf" && ok "tmux config reloaded." || warn "Reload failed (check config syntax)."
fi

# ── 5. Install tsm command ────────────────────────────────────────────────────
info "Installing tsm command..."
TSM_BIN="$HOME/.local/bin"
mkdir -p "$TSM_BIN"
ln -sf "$SCRIPT_DIR/scripts/tmsm.sh" "$TSM_BIN/tsm"
ok "tsm → $TSM_BIN/tsm"

# Remove old tmsm symlink if present
if [ -L "$TSM_BIN/tmsm" ]; then
    rm "$TSM_BIN/tmsm"
    ok "Removed old tmsm symlink."
fi

# Ensure ~/.local/bin is on PATH in ~/.bashrc
PATH_MARKER="# tsm: ~/.local/bin on PATH"
if ! grep -qF "# tsm: ~/.local/bin on PATH" "$HOME/.bashrc" 2>/dev/null; then
    printf '\n%s\nexport PATH="$HOME/.local/bin:$PATH"\n' "$PATH_MARKER" >> "$HOME/.bashrc"
    ok "~/.local/bin added to PATH in ~/.bashrc"
else
    ok "~/.local/bin already in PATH."
fi

# ── 6. Patch ~/.bashrc for SSH auto-attach ────────────────────────────────────
info "Checking ~/.bashrc for SSH auto-attach hook..."
BASHRC="$HOME/.bashrc"
BASH_MARKER="# tsm: SSH auto-attach"

# Migrate old tmsm references to tsm in-place
if grep -q "tmsm" "$BASHRC" 2>/dev/null; then
    sed -i \
        -e 's/# tmsm: SSH auto-attach/# tsm: SSH auto-attach/g' \
        -e 's/# tmsm: ~\/.local\/bin on PATH/# tsm: ~\/.local\/bin on PATH/g' \
        -e 's/command -v tmsm/command -v tsm/g' \
        -e 's/\.local\/bin\/tmsm/.local\/bin\/tsm/g' \
        -e '/tmsm$/s/tmsm/tsm/g' \
        "$BASHRC"
    ok "Migrated old tmsm references to tsm in ~/.bashrc"
fi

if grep -q "$BASH_MARKER" "$BASHRC" 2>/dev/null; then
    ok "~/.bashrc already has SSH auto-attach."
else
    cat >> "$BASHRC" <<'SNIPPET'

# tsm: SSH auto-attach
# On every SSH login: ensure all tmux sessions exist and attach to main.
if [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ]; then
    if command -v tsm &>/dev/null; then
        tsm
    elif [ -x "$HOME/.local/bin/tsm" ]; then
        "$HOME/.local/bin/tsm"
    fi
fi
SNIPPET
    ok "SSH auto-attach hook appended to ~/.bashrc."
fi

# ── 7. Bootstrap all sessions ─────────────────────────────────────────────────
info "Starting all tmux sessions..."
bash "$SCRIPT_DIR/scripts/start-sessions.sh" all
ok "All sessions running."

# ── 8. Summary ────────────────────────────────────────────────────────────────
printf '\n'
printf '\033[1;32m══════════════════════════════════════════════\033[0m\n'
printf '\033[1;32m  Installation complete!\033[0m\n'
printf '\033[1;32m══════════════════════════════════════════════\033[0m\n'
printf '\n'
printf '  Sessions created:\n'
tmux list-sessions -F "    #[bold]#{session_name}#[none]  #{?session_attached,(attached),(detached)}" 2>/dev/null || true
printf '\n'
printf '  Launch session manager:  \033[1mtsm\033[0m\n'
printf '  (reload shell first:     \033[1msource ~/.bashrc\033[0m)\n'
printf '\n'
printf '  Direct attach:           \033[1mtmux attach -t main\033[0m\n'
printf '  Jump sessions (tmux):    \033[1mPrefix + m/e/d/o\033[0m\n'
printf '  Visual chooser:          \033[1mPrefix + s\033[0m\n'
printf '  Configure sessions:      \033[1m%s/conf/sessions.conf\033[0m\n' "$SCRIPT_DIR"
printf '\n'
printf '  On next SSH login the shell will auto-attach to \033[1mmain\033[0m.\n'
printf '\n'
