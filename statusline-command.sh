#!/bin/bash
# Claude Code status line: model + context bar + token count + 5h/7d rate limits + caveman badge

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

build_bar() {
  local pct="$1"
  local width=20
  local filled=$(( (pct * width + 99) / 100 ))
  [ "$filled" -gt "$width" ] && filled=$width
  local empty=$(( width - filled ))
  local bar=""
  local i=0
  while [ $i -lt $filled ]; do bar="${bar}█"; i=$(( i + 1 )); done
  while [ $i -lt $width ];  do bar="${bar}░"; i=$(( i + 1 )); done
  printf '%s' "$bar"
}

to_k() {
  # round to nearest thousand, print as "Nk"
  awk -v n="$1" 'BEGIN{printf "%dk", (n+500)/1000}'
}

parts=""

if [ -n "$model" ]; then
  parts=$(printf '\033[0;35m%s\033[0m' "$model")
fi

if [ -n "$used" ]; then
  pct=$(printf '%.0f' "$used")
  bar=$(build_bar "$pct")

  if [ "$pct" -ge 85 ]; then
    color='\033[0;31m'
  elif [ "$pct" -ge 60 ]; then
    color='\033[0;33m'
  else
    color='\033[0;32m'
  fi

  ctx_str=$(printf "${color}[%s]\033[0m \033[0;32m%s%%\033[0m" "$bar" "$pct")
  parts="${parts} | ${ctx_str}"
fi

if [ -n "$total_input" ] && [ -n "$window_size" ]; then
  used_k=$(to_k "$total_input")
  win_k=$(to_k "$window_size")
  parts="${parts} | \033[0;37m${used_k}/${win_k} tokens\033[0m"
fi

now=$(date +%s)
JUST_RESET_WINDOW=300  # seconds; treat a reset in the last 5 min as "just happened"

# BSD/macOS date reads an epoch with -r, GNU date with -d @<epoch>. Probe once:
# `date -r 0` succeeds on BSD and fails on GNU (which wants a file named "0").
if date -r 0 +%s >/dev/null 2>&1; then DATE_EPOCH_STYLE=bsd; else DATE_EPOCH_STYLE=gnu; fi

# fmt_epoch <epoch> <date_fmt>
fmt_epoch() {
  if [ "$DATE_EPOCH_STYLE" = bsd ]; then
    date -r "$1" "$2" 2>/dev/null
  else
    date -d "@$1" "$2" 2>/dev/null
  fi
}

rate_color() {
  local pct="$1"
  if [ "$pct" -ge 85 ]; then
    printf '\033[0;31m'
  elif [ "$pct" -ge 60 ]; then
    printf '\033[0;33m'
  else
    printf '\033[0;32m'
  fi
}

# pct_left_color <pct_left> — colors by fraction of the window remaining,
# so it goes red as reset time approaches.
pct_left_color() {
  local pct_left="$1"
  if [ "$pct_left" -le 15 ]; then
    printf '\033[0;31m'
  elif [ "$pct_left" -le 40 ]; then
    printf '\033[0;33m'
  else
    printf '\033[0;32m'
  fi
}

# countdown_str <remaining_seconds> — "in 12m" / "in 1h 40m" / "in 2d 3h"
countdown_str() {
  local rem="$1"
  if [ "$rem" -lt 60 ]; then
    printf 'in %ds' "$rem"
  elif [ "$rem" -lt 3600 ]; then
    printf 'in %dm' $(( rem / 60 ))
  elif [ "$rem" -lt 86400 ]; then
    printf 'in %dh %dm' $(( rem / 3600 )) $(( (rem % 3600) / 60 ))
  else
    printf 'in %dd %dh' $(( rem / 86400 )) $(( (rem % 86400) / 3600 ))
  fi
}

# unit_countdown <remaining_seconds> — single-unit label that shrinks as the
# reset approaches: "6d" -> "2d" -> "23h" -> "1h" -> "45m" -> "1m" -> "30s"
# Rounds to the nearest unit rather than truncating: a reset 1d23h out is "2d",
# not "1d" (which reads as "tomorrow"). Rounding up out of a unit carries into
# the next one, so 23h50m is "1d" rather than "24h".
unit_countdown() {
  local rem="$1"
  [ "$rem" -lt 0 ] && rem=0
  if [ "$rem" -ge 86400 ]; then
    printf '%dd' $(( (rem + 43200) / 86400 ))
  elif [ "$rem" -ge 3600 ]; then
    local hours=$(( (rem + 1800) / 3600 ))
    if [ "$hours" -ge 24 ]; then printf '1d'; else printf '%dh' "$hours"; fi
  elif [ "$rem" -ge 60 ]; then
    local mins=$(( (rem + 30) / 60 ))
    if [ "$mins" -ge 60 ]; then printf '1h'; else printf '%dm' "$mins"; fi
  else
    printf '%ds' "$rem"
  fi
}

# next_reset_remaining <reset_at> <interval_seconds> — seconds until the next
# upcoming reset, rolling forward past any occurrences already in the past.
next_reset_remaining() {
  local reset_at="$1" interval="$2"
  [ -z "$reset_at" ] && return 1
  while [ "$reset_at" -le "$now" ]; do
    reset_at=$(( reset_at + interval ))
  done
  printf '%d' $(( reset_at - now ))
}

# format_reset <resets_at> <pct> <interval_seconds>
# Handles the "just reset" edge case (rolls forward past occurrences, or
# shows "Just now"). Returns "<countdown>\t<color>\t<next_reset_epoch>";
# callers render the epoch into a clock or day label as they see fit.
format_reset() {
  local reset_at="$1" pct="$2" interval="$3"
  [ -z "$reset_at" ] && return 1

  if [ "$reset_at" -le "$now" ]; then
    local age=$(( now - reset_at ))
    if [ "$pct" -eq 0 ] && [ "$age" -le "$JUST_RESET_WINDOW" ]; then
      printf 'Just now\t\033[0;32m'
      return 0
    fi
    # roll forward past occurrences to find the next upcoming reset
    while [ "$reset_at" -le "$now" ]; do
      reset_at=$(( reset_at + interval ))
    done
  fi

  local remaining=$(( reset_at - now ))
  local pct_left=$(( remaining * 100 / interval ))
  local color=$(pct_left_color "$pct_left")

  printf '%s\t%s\t%s' "$(unit_countdown "$remaining")" "$color" "$reset_at"
}

if [ -n "$five_hour" ]; then
  fh_pct=$(printf '%.0f' "$five_hour")
  fh_color=$(rate_color "$fh_pct")
  fh_interval=$((5 * 3600))
  fh_str="5h:${fh_pct}%"
  fh_result=$(format_reset "$five_hour_reset" "$fh_pct" "$fh_interval")
  if [ -n "$fh_result" ]; then
    IFS=$'\t' read -r fh_time fh_rcolor fh_reset_at <<< "$fh_result"
    if [ -n "$fh_reset_at" ]; then
      fh_clock=$(fmt_epoch "$fh_reset_at" '+%-I:%M%p' | tr '[:upper:]' '[:lower:]')
      fh_str="${fh_str} (${fh_rcolor}↺ ${fh_time} ~ ${fh_clock}${fh_color})"
    else
      fh_str="${fh_str} (${fh_rcolor}↺ ${fh_time}${fh_color})"
    fi
  fi
  parts="${parts} | ${fh_color}${fh_str}\033[0m"
fi

if [ -n "$seven_day" ]; then
  sd_pct=$(printf '%.0f' "$seven_day")
  sd_color=$(rate_color "$sd_pct")
  sd_interval=$((7 * 24 * 3600))
  sd_str="7d:${sd_pct}%"
  sd_result=$(format_reset "$seven_day_reset" "$sd_pct" "$sd_interval")
  if [ -n "$sd_result" ]; then
    IFS=$'\t' read -r sd_day sd_rcolor sd_reset_at <<< "$sd_result"
    sd_weekday=""
    [ -n "$sd_reset_at" ] && sd_weekday=$(fmt_epoch "$sd_reset_at" '+%a')
    if [ -n "$sd_weekday" ]; then
      sd_str="${sd_str} (${sd_rcolor}↺ ${sd_day} ~ ${sd_weekday}${sd_color})"
    else
      sd_str="${sd_str} (${sd_rcolor}↺ ${sd_day}${sd_color})"
    fi
  fi
  parts="${parts} | ${sd_color}${sd_str}\033[0m"
fi

# strip a leading " | " if model was empty
parts="${parts# | }"

printf "%b" "$parts"
