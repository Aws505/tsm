#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# tests/test_install.sh — Verify the tsm installation
#
# Run from anywhere:
#   bash ~/Projects/tmux/tests/test_install.sh
#
# Exit code 0 = all tests passed; non-zero = failures.
# ─────────────────────────────────────────────────────────────────────────────

PASS=0
FAIL=0

pass() { printf '\033[1;32m  PASS\033[0m  %s\n' "$1"; (( PASS++ )); }
fail() { printf '\033[1;31m  FAIL\033[0m  %s\n' "$1"; (( FAIL++ )); }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo
echo "=== tsm installation tests ==="
echo

# ── 1. Symlink exists at the right path ──────────────────────────────────────
TSM_LINK="$HOME/.local/bin/tsm"
if [ -L "$TSM_LINK" ]; then
    pass "~/.local/bin/tsm symlink exists"
else
    fail "~/.local/bin/tsm symlink missing (run install.sh)"
fi

# ── 2. Symlink points to tmsm.sh ─────────────────────────────────────────────
EXPECTED_TARGET="$SCRIPT_DIR/scripts/tmsm.sh"
ACTUAL_TARGET="$(readlink -f "$TSM_LINK" 2>/dev/null)"
if [ "$ACTUAL_TARGET" = "$EXPECTED_TARGET" ]; then
    pass "tsm symlink points to scripts/tmsm.sh"
else
    fail "tsm symlink target wrong: expected '$EXPECTED_TARGET', got '$ACTUAL_TARGET'"
fi

# ── 3. tmsm.sh is executable ─────────────────────────────────────────────────
if [ -x "$SCRIPT_DIR/scripts/tmsm.sh" ]; then
    pass "scripts/tmsm.sh is executable"
else
    fail "scripts/tmsm.sh is not executable"
fi

# ── 4. tsm command is resolvable on PATH ─────────────────────────────────────
if command -v tsm &>/dev/null; then
    pass "'tsm' is on PATH ($(command -v tsm))"
else
    fail "'tsm' not found on PATH — ensure ~/.local/bin is in PATH (source ~/.bashrc)"
fi

# ── 5. Old tmsm symlink has been removed ─────────────────────────────────────
if [ ! -e "$HOME/.local/bin/tmsm" ]; then
    pass "old 'tmsm' symlink is gone"
else
    fail "old 'tmsm' symlink still exists at ~/.local/bin/tmsm"
fi

# ── 6. ~/.bashrc contains SSH auto-attach block using tsm ────────────────────
BASHRC="$HOME/.bashrc"
if grep -q "tsm: SSH auto-attach" "$BASHRC" 2>/dev/null; then
    pass "~/.bashrc has tsm SSH auto-attach block"
else
    fail "~/.bashrc missing tsm SSH auto-attach block"
fi

if grep -qE "command -v tsm|/.local/bin/tsm" "$BASHRC" 2>/dev/null; then
    pass "~/.bashrc auto-attach block references 'tsm'"
else
    fail "~/.bashrc auto-attach block does not reference 'tsm'"
fi

# ── 7. ~/.local/bin is on PATH in ~/.bashrc ───────────────────────────────────
if grep -q '.local/bin' "$BASHRC" 2>/dev/null; then
    pass "~/.bashrc adds ~/.local/bin to PATH"
else
    fail "~/.bashrc does not add ~/.local/bin to PATH"
fi

# ── 8. All scripts are executable ────────────────────────────────────────────
for script in start-sessions.sh session-menu.sh ssh-attach.sh tmsm.sh; do
    path="$SCRIPT_DIR/scripts/$script"
    if [ -x "$path" ]; then
        pass "scripts/$script is executable"
    else
        fail "scripts/$script is not executable"
    fi
done

# ── 9. ~/.tmux.conf sources our config ───────────────────────────────────────
TMUX_CONF="$HOME/.tmux.conf"
if grep -q "managed by ~/Projects/tmux" "$TMUX_CONF" 2>/dev/null; then
    pass "~/.tmux.conf is managed by this project"
else
    fail "~/.tmux.conf not set up (run install.sh)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo
TOTAL=$(( PASS + FAIL ))
printf '%d/%d tests passed\n' "$PASS" "$TOTAL"
echo

if [ "$FAIL" -gt 0 ]; then
    printf '\033[1;31mSome tests failed. Run:\033[0m  bash %s/install.sh\n\n' "$SCRIPT_DIR"
    exit 1
fi
printf '\033[1;32mAll tests passed.\033[0m\n\n'
