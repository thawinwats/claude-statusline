# claude-statusline

A statusline for Claude Code: model name, context-usage bar, token count, and 5h/7d rate-limit countdowns.

```
Opus 5 | [████████░░░░░░░░░░░░] 38% | 76k/200k tokens | 5h:42% (↺ 2h ~ 4:15pm) | 7d:18% (↺ 5d ~ Sat)
```

- Model name in magenta.
- Context bar + percentage: green under 60%, yellow 60-85%, red above 85%.
- Tokens used / context window size.
- `5h` and `7d` rate-limit usage, same color thresholds, with a `↺` countdown to the next reset (the countdown turns yellow, then red, as the reset nears). The 5h entry also shows the wall-clock reset time; the 7d entry shows the weekday it rolls over on.
- The countdown rounds to the nearest unit, so a reset 1d23h away reads `2d`, not `1d`.

## Prerequisites

`jq`. Check with `jq --version`. If it's missing, the installer offers to install it for you via Homebrew (it asks first, and defaults to no) — or install it yourself:

```bash
brew install jq
```

(No Homebrew? Install it from https://brew.sh first — the installer won't install Homebrew for you.)

## Install

One-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/thawinwats/claude-statusline/master/install.sh | bash
```

Or from a clone:

```bash
git clone https://github.com/thawinwats/claude-statusline.git
cd claude-statusline
./install.sh
```

Then restart Claude Code.

The installer copies the script to `~/.claude/statusline-command.sh` and sets `statusLine` in `~/.claude/settings.json` (creating that file if it doesn't exist). Nothing else in your settings is touched, and re-running is safe — it overwrites the same two things.

## Update

Re-run the one-liner, or `git pull && ./install.sh`.

## Uninstall

```bash
jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
rm ~/.claude/statusline-command.sh
```

Restart Claude Code.
