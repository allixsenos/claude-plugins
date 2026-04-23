#!/usr/bin/env bash
# Claude Code status line script
input=$(cat)

CONFIG_FILE="${CLAUDE_STATUSLINE_CONFIG:-$HOME/.claude/statusline-config.json}"

# Default config if no file exists
if [ -f "$CONFIG_FILE" ]; then
  config=$(cat "$CONFIG_FILE")
else
  config='{"lines":[["ps1","git","update"],["model","ctx_bar","5h_bar","7d_bar","cost","lines"]]}'
fi

# Config: threshold for showing reset countdown (default 0 = always show)
show_reset_at=$(echo "$config" | jq -r '.show_reset_at // 0')

# Config: percentage-point gap above elapsed time to flag as "burning hot"
# in short meter variants (default 10). The flag only fires once elapsed >= 20%
# to avoid false alarms right after a window resets.
burn_threshold=$(echo "$config" | jq -r '.burn_threshold // 10')

# Hardcoded window durations in seconds. The statusline JSON only exposes
# used_percentage and resets_at per window (see code.claude.com/docs/en/statusline),
# so the window size itself has to be hardcoded. If Anthropic ever changes tier
# durations or introduces new windows, these constants go stale silently.
WINDOW_5H_SECS=18000
WINDOW_7D_SECS=604800

# Helper: render a 10-step progress bar with percentage inside
make_bar() {
  local label="$1"
  local pct_raw="$2"
  local pct_int=$(printf '%.0f' "$pct_raw")
  local filled=$(echo "$pct_raw" | awk '{n=int($1/10+0.5); if(n>10) n=10; if(n<0) n=0; print n}')
  local text="${pct_int}%"
  local text_len=${#text}
  local width=10
  local text_start

  if [ "$filled" -eq 0 ]; then
    text_start=0
  else
    text_start=$((filled + 1))
  fi

  if [ $((text_start + text_len)) -gt "$width" ]; then
    text_start=$((filled - text_len - 1))
    [ "$text_start" -lt 0 ] && text_start=0
  fi

  local text_end=$((text_start + text_len))
  local fill_color
  fill_color=$(echo "$pct_raw" | awk '{if($1>=80) print "\033[31m"; else if($1>=60) print "\033[33m"; else print "\033[32m"}')
  local dim='\033[37m'
  local reset='\033[0m'

  local bar=""
  local i
  for ((i=0; i<width; i++)); do
    local ch
    if [ "$i" -ge "$text_start" ] && [ "$i" -lt "$text_end" ]; then
      ch="${text:$((i - text_start)):1}"
    elif [ "$i" -lt "$filled" ]; then
      ch="█"
    else
      ch="░"
    fi
    local is_text=0
    [ "$i" -ge "$text_start" ] && [ "$i" -lt "$text_end" ] && is_text=1
    if [ "$i" -lt "$filled" ]; then
      if [ "$is_text" -eq 1 ]; then
        bar="${bar}\033[48;5;236;37m${ch}${reset}"
      else
        bar="${bar}${fill_color}${ch}${reset}"
      fi
    else
      if [ "$is_text" -eq 1 ]; then
        bar="${bar}\033[48;5;236;37m${ch}${reset}"
      else
        bar="${bar}${dim}${ch}${reset}"
      fi
    fi
  done

  printf "%s [%b]" "$label" "$bar"
}

# --- Component functions (only called if in config) ---

component_ps1() {
  local cwd
  cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
  local user_host="$(whoami)@$(hostname -s)"
  if [ -n "$cwd" ]; then
    _tilde='~'; cwd="${cwd/#"$HOME"/$_tilde}"
    printf '\033[1;32m%s\033[0m:\033[1;34m%s\033[0m' "$user_host" "$cwd"
  else
    printf '\033[1;32m%s\033[0m' "$user_host"
  fi
}

component_git() {
  local cwd
  cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
  [ -z "$cwd" ] && return
  local branch
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -z "$branch" ] && return
  local raw_status flags=""
  raw_status=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  echo "$raw_status" | grep -q '^[MADRCU]' && flags="${flags}S"
  echo "$raw_status" | grep -q '^ [MD]'    && flags="${flags}M"
  echo "$raw_status" | grep -q '^??' && flags="${flags}?"
  printf '\033[33m%s\033[0m' "$branch"
  [ -n "$flags" ] && printf '\033[31m %s\033[0m' "$flags"
}

component_user() {
  printf '\033[1;32m%s\033[0m' "$(whoami)"
}

component_host_short() {
  printf '\033[1;32m%s\033[0m' "$(hostname -s)"
}

component_host_long() {
  printf '\033[1;32m%s\033[0m' "$(hostname -f 2>/dev/null || hostname)"
}

component_cwd() {
  local cwd
  cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
  [ -z "$cwd" ] && return
  _tilde='~'; cwd="${cwd/#"$HOME"/$_tilde}"
  printf '\033[1;34m%s\033[0m' "$cwd"
}

component_model() {
  local model
  model=$(echo "$input" | jq -r '.model.display_name // empty')
  [ -z "$model" ] && return
  printf '\033[36m%s\033[0m' "$model"
}

# Helper: format seconds until reset as the coarsest nonzero unit, rounded up.
# Examples: 4h30m -> 5h, 4h15m -> 5h, 4h exactly -> 4h, 3d15h -> 4d, 45s -> 1m.
format_remaining() {
  local secs="$1"
  [ "$secs" -le 0 ] && echo "now" && return
  if [ "$secs" -ge 86400 ]; then
    printf '%dd' "$(( (secs + 86399) / 86400 ))"
  elif [ "$secs" -ge 3600 ]; then
    printf '%dh' "$(( (secs + 3599) / 3600 ))"
  else
    printf '%dm' "$(( (secs + 59) / 60 ))"
  fi
}

# Helper: compute elapsed percentage of a rate-limit window from resets_at.
# Echoes an integer 0-100, or "-1" if resets_at is unusable.
elapsed_pct_from_reset() {
  local window_secs="$1" resets_at="$2"
  if [ -z "$resets_at" ] || [ "$resets_at" = "null" ]; then
    echo "-1"
    return
  fi
  local now elapsed_secs
  now=$(date +%s)
  elapsed_secs=$((window_secs - (resets_at - now)))
  [ "$elapsed_secs" -lt 0 ] && elapsed_secs=0
  [ "$elapsed_secs" -gt "$window_secs" ] && elapsed_secs="$window_secs"
  echo "$((elapsed_secs * 100 / window_secs))"
}

# Helper: append reset countdown if usage >= show_reset_at threshold
maybe_reset_suffix() {
  local pct_raw="$1" resets_at="$2"
  [ -z "$resets_at" ] && return
  local above
  above=$(echo "$pct_raw $show_reset_at" | awk '{print ($1 >= $2) ? 1 : 0}')
  [ "$above" -eq 1 ] || return
  local remaining=$(( resets_at - $(date +%s) ))
  printf ' \033[90m%s\033[0m' "$(format_remaining "$remaining")"
}

# Helper: colored "label NN%" string with threshold coloring
make_short() {
  local label="$1" pct_raw="$2"
  local pct_int=$(printf '%.0f' "$pct_raw")
  local color
  color=$(echo "$pct_raw" | awk '{if($1>=80) print "\033[31m"; else if($1>=60) print "\033[33m"; else print "\033[32m"}')
  printf '\033[90m[\033[0m%b%s %s%%\033[0m\033[90m]\033[0m' "$color" "$label" "$pct_int"
}

# Helper: rate-limit bar with outside percentage, in-bar elapsed-time marker,
# and trailing countdown. Format: "LABEL NN% [bar_with_marker] COUNTDOWN"
make_meter_bar() {
  local label="$1" pct_raw="$2" window_secs="$3" resets_at="$4"
  local pct_int=$(printf '%.0f' "$pct_raw")
  local filled
  filled=$(echo "$pct_raw" | awk '{n=int($1/10+0.5); if(n>10) n=10; if(n<0) n=0; print n}')
  local width=10

  # Compute elapsed-time marker position (-1 when we can't)
  local marker_pos=-1
  local elapsed_pct
  elapsed_pct=$(elapsed_pct_from_reset "$window_secs" "$resets_at")
  if [ "$elapsed_pct" -ge 0 ]; then
    marker_pos=$((elapsed_pct * width / 100))
    [ "$marker_pos" -gt $((width - 1)) ] && marker_pos=$((width - 1))
  fi

  local fill_color
  fill_color=$(echo "$pct_raw" | awk '{if($1>=80) print "\033[31m"; else if($1>=60) print "\033[33m"; else print "\033[32m"}')
  local dim='\033[37m'
  local marker_color='\033[1;91m'
  local reset='\033[0m'

  local bar="" i
  for ((i=0; i<width; i++)); do
    if [ "$i" -eq "$marker_pos" ]; then
      bar="${bar}${marker_color}|${reset}"
    elif [ "$i" -lt "$filled" ]; then
      bar="${bar}${fill_color}█${reset}"
    else
      bar="${bar}${dim}░${reset}"
    fi
  done

  printf "%s %2d%% [%b]" "$label" "$pct_int" "$bar"

  # Countdown when usage >= show_reset_at (default 0 = always) and we have a reset time
  if [ "$elapsed_pct" -ge 0 ]; then
    local above
    above=$(echo "$pct_raw $show_reset_at" | awk '{print ($1 >= $2) ? 1 : 0}')
    if [ "$above" -eq 1 ]; then
      local remaining=$(( resets_at - $(date +%s) ))
      printf ' \033[90m%s\033[0m' "$(format_remaining "$remaining")"
    fi
  fi
}

# Helper: short rate-limit meter with in-bracket burn icon and trailing countdown.
# Burn icon fires when usage is pulling ahead of the clock by more than
# burn_threshold percentage points, gated by elapsed >= 20% to avoid noise at
# window start.
make_meter_short() {
  local label="$1" pct_raw="$2" window_secs="$3" resets_at="$4"
  local pct_int=$(printf '%.0f' "$pct_raw")
  local color
  color=$(echo "$pct_raw" | awk '{if($1>=80) print "\033[31m"; else if($1>=60) print "\033[33m"; else print "\033[32m"}')

  local burn_icon=""
  local elapsed_pct
  elapsed_pct=$(elapsed_pct_from_reset "$window_secs" "$resets_at")
  if [ "$elapsed_pct" -ge 0 ]; then
    local burn
    burn=$(echo "$pct_raw $elapsed_pct $burn_threshold" | awk '{print ($2 >= 20 && $1 > $2 + $3) ? 1 : 0}')
    [ "$burn" -eq 1 ] && burn_icon='\033[1;91m↑\033[0m'
  fi

  printf '\033[90m[\033[0m%b%s %s%%\033[0m%b\033[90m]\033[0m' "$color" "$label" "$pct_int" "$burn_icon"

  if [ "$elapsed_pct" -ge 0 ]; then
    local above
    above=$(echo "$pct_raw $show_reset_at" | awk '{print ($1 >= $2) ? 1 : 0}')
    if [ "$above" -eq 1 ]; then
      local remaining=$(( resets_at - $(date +%s) ))
      printf ' \033[90m%s\033[0m' "$(format_remaining "$remaining")"
    fi
  fi
}

component_ctx_bar() {
  local pct
  pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
  [ -z "$pct" ] && return
  make_bar "ctx" "$pct"
}

component_ctx_short() {
  local pct
  pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
  [ -z "$pct" ] && return
  make_short "ctx" "$pct"
}

component_5h_bar() {
  local pct
  pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  [ -z "$pct" ] && return
  make_meter_bar "5h" "$pct" "$WINDOW_5H_SECS" \
    "$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')"
}

component_5h_short() {
  local pct
  pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  [ -z "$pct" ] && return
  make_meter_short "5h" "$pct" "$WINDOW_5H_SECS" \
    "$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')"
}

component_7d_bar() {
  local pct
  pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  [ -z "$pct" ] && return
  make_meter_bar "7d" "$pct" "$WINDOW_7D_SECS" \
    "$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')"
}

component_7d_short() {
  local pct
  pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  [ -z "$pct" ] && return
  make_meter_short "7d" "$pct" "$WINDOW_7D_SECS" \
    "$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')"
}

component_cost() {
  local cost
  cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
  [ -z "$cost" ] || [ "$cost" = "0" ] && return
  printf '\033[33m$%.2f\033[0m' "$cost"
}

component_lines() {
  local added removed delta=""
  added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
  removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')
  [ -n "$added" ] && [ "$added" != "0" ] && delta="$(printf '\033[32m+%s\033[0m' "$added")"
  if [ -n "$removed" ] && [ "$removed" != "0" ]; then
    [ -n "$delta" ] && delta="${delta} "
    delta="${delta}$(printf '\033[31m-%s\033[0m' "$removed")"
  fi
  [ -n "$delta" ] && printf '%b' "$delta"
}

component_update() {
  local cache="/tmp/redline-claude-version"
  local ttl=14400  # 4 hours in seconds
  local now latest cached_at=0

  now=$(date +%s)

  # Read cache
  if [ -f "$cache" ]; then
    cached_at=$(sed -n '1p' "$cache")
    latest=$(sed -n '2p' "$cache")
  fi

  # Refresh if stale or empty
  if [ $((now - cached_at)) -ge $ttl ] || [ -z "$latest" ]; then
    local fetched
    fetched=$(npm view @anthropic-ai/claude-code version 2>/dev/null)
    if [ -n "$fetched" ]; then
      latest="$fetched"
      printf '%s\n%s\n' "$now" "$latest" > "$cache"
    fi
  fi

  [ -z "$latest" ] && return

  # Session version. Must come from CLAUDE_CODE_EXECPATH (the binary that
  # launched THIS session), NOT `claude --version` on PATH. Claude self-updates
  # in the background, so the PATH binary is usually newer than the running
  # session — comparing against it silences the prompt exactly when the user
  # most needs it (the session is stale and should be restarted to pick up
  # whatever's on disk). Path format: .../versions/X.Y.Z
  local current=""
  if [ -n "$CLAUDE_CODE_EXECPATH" ]; then
    current=$(basename "$CLAUDE_CODE_EXECPATH" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  fi
  [ -z "$current" ] && return

  # If latest > current, show both so the user knows what a session restart
  # would gain. Intentionally ignores whatever is on disk — the signal is
  # "restart THIS session", not "run the installer".
  local newer
  newer=$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)
  if [ "$newer" = "$latest" ] && [ "$latest" != "$current" ]; then
    printf '\033[1;33m↑ claude code %s → %s\033[0m' "$current" "$latest"
  fi
}

# --- Render a line from config ---

render_line() {
  local line_index="$1"
  local components
  components=$(echo "$config" | jq -r ".lines[${line_index}][]?" 2>/dev/null)
  [ -z "$components" ] && return

  local output="" fragment
  while IFS= read -r name; do
    if declare -f "component_${name}" > /dev/null 2>&1; then
      fragment=$(component_"${name}")
      if [ -n "$fragment" ]; then
        [ -n "$output" ] && output="${output}  "
        output="${output}${fragment}"
      fi
    fi
  done <<< "$components"
  printf '%b' "$output"
}

# --- Output ---

num_lines=$(echo "$config" | jq '.lines | length' 2>/dev/null)
output=""
for ((i=0; i<num_lines; i++)); do
  line=$(render_line "$i")
  if [ -n "$line" ]; then
    [ -n "$output" ] && output="${output}\n"
    output="${output}${line}"
  fi
done
[ -n "$output" ] && printf '%b' "$output"
