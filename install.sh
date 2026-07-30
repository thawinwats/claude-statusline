#!/bin/bash
# Installs the statusline script and wires it into ~/.claude/settings.json
set -euo pipefail

command -v jq >/dev/null || { echo "jq required (brew install jq)"; exit 1; }

mkdir -p "$HOME/.claude"

# Local copy when run from a clone; otherwise fetch (e.g. curl ... | bash).
src="$(dirname "$0")/statusline-command.sh"
if [ -f "$src" ]; then
  cp "$src" "$HOME/.claude/statusline-command.sh"
else
  curl -fsSL https://raw.githubusercontent.com/thawinwats/claude-statusline/master/statusline-command.sh \
    -o "$HOME/.claude/statusline-command.sh"
fi
chmod +x "$HOME/.claude/statusline-command.sh"

SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

tmp=$(mktemp)
jq '.statusLine = {"type": "command", "command": "bash \"$HOME/.claude/statusline-command.sh\""}' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

echo "Installed. Restart Claude Code to see the new statusline."
