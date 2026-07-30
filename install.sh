#!/bin/bash
# Installs the statusline script and wires it into ~/.claude/settings.json
set -euo pipefail

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
  BOLD=''; RED=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
fi

step() { printf '%s\n' "${CYAN}··${RESET} $*"; }
ok()   { printf '%s\n' "${GREEN}✓${RESET} $*"; }
fail() { printf '%s\n' "${RED}✗${RESET} $*" >&2; exit 1; }

printf '%s\n\n' "${BOLD}Installing claude-statusline${RESET}"

step "Checking for jq"
if command -v jq >/dev/null; then
  ok "jq found"
else
  command -v brew >/dev/null || \
    fail "jq is required and Homebrew is not installed. Install Homebrew from https://brew.sh, then re-run."

  # Read from /dev/tty: stdin is the script itself under `curl ... | bash`.
  answer=""
  if ( : < /dev/tty ) 2>/dev/null; then
    printf '%s' "${YELLOW}?${RESET} jq is required. Install it now via Homebrew? [y/N] "
    read -r answer < /dev/tty 2>/dev/null || { answer=""; printf '\n'; }
  fi

  case "$answer" in
    y|Y|yes|Yes|YES) ;;
    *) fail "jq not installed. Install it manually with: brew install jq" ;;
  esac

  step "Installing jq via Homebrew"
  brew install jq || fail "brew install jq failed"
  ok "jq installed"
fi

mkdir -p "$HOME/.claude"

# Local copy when run from a clone; otherwise fetch (e.g. curl ... | bash).
src="$(dirname "$0")/statusline-command.sh"
if [ -f "$src" ]; then
  step "Copying statusline-command.sh"
  cp "$src" "$HOME/.claude/statusline-command.sh" || fail "Could not copy $src"
  ok "Copied to ~/.claude/statusline-command.sh"
else
  step "Fetching statusline-command.sh"
  curl -fsSL https://raw.githubusercontent.com/thawinwats/claude-statusline/master/statusline-command.sh \
    -o "$HOME/.claude/statusline-command.sh" || fail "Download failed"
  ok "Fetched to ~/.claude/statusline-command.sh"
fi
chmod +x "$HOME/.claude/statusline-command.sh"

SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

step "Updating settings.json"
tmp=$(mktemp)
jq '.statusLine = {"type": "command", "command": "bash \"$HOME/.claude/statusline-command.sh\""}' "$SETTINGS" > "$tmp" \
  || { rm -f "$tmp"; fail "Could not update $SETTINGS (is it valid JSON?)"; }
mv "$tmp" "$SETTINGS"
ok "statusLine set in ~/.claude/settings.json"

printf '\n%s\n' "${GREEN}✓${RESET} ${BOLD}Done.${RESET} Restart Claude Code to see the new statusline."
