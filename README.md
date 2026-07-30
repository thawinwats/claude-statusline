# claude-statusline

Claude Code statusline: model name, context usage bar, and 5h/7d rate-limit countdowns.

## Install

```bash
git clone https://github.com/YOUR_USERNAME/claude-statusline.git
cd claude-statusline
./install.sh
```

Requires `jq`. Merges `statusLine` into `~/.claude/settings.json` (creates the file if missing) and copies the script to `~/.claude/statusline-command.sh`.

## Update

Pull latest and re-run `./install.sh`.
