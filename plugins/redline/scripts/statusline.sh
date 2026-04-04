#!/usr/bin/env bash
# Claude Code status line script
input=$(cat)

CONFIG_FILE="${CLAUDE_STATUSLINE_CONFIG:-$HOME/.claude/statusline-config.json}"

# Default config if no file exists
if [ -f "$CONFIG_FILE" ]; then
  config=$(cat "$CONFIG_FILE")
else
  config='{"lines":[["ps1","git"],["model","ctx_bar","5h_bar","7d_bar","cost","lines"]]}'
fi

# Config: threshold for showing reset countdown (default 70%)
show_reset_at=$(echo "$config" | jq -r '.show_reset_at // 70')

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
    cwd="${cwd/#"$HOME"/\~}"
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
  cwd="${cwd/#"$HOME"/\~}"
  printf '\033[1;34m%s\033[0m' "$cwd"
}

component_model() {
  local model
  model=$(echo "$input" | jq -r '.model.display_name // empty')
  [ -z "$model" ] && return
  printf '\033[36m%s\033[0m' "$model"
}

# Helper: format seconds until reset as compact duration (e.g. "2h31m", "4d12h")
format_remaining() {
  local secs="$1"
  [ "$secs" -le 0 ] && echo "now" && return
  local days=$((secs / 86400))
  local hours=$(((secs % 86400) / 3600))
  local mins=$(((secs % 3600) / 60))
  if [ "$days" -gt 0 ]; then
    printf '%dd%dh' "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf '%dh%dm' "$hours" "$mins"
  else
    printf '%dm' "$mins"
  fi
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
  make_bar "5h" "$pct"
  maybe_reset_suffix "$pct" "$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')"
}

component_5h_short() {
  local pct
  pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  [ -z "$pct" ] && return
  make_short "5h" "$pct"
  maybe_reset_suffix "$pct" "$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')"
}

component_7d_bar() {
  local pct
  pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  [ -z "$pct" ] && return
  make_bar "7d" "$pct"
  maybe_reset_suffix "$pct" "$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')"
}

component_7d_short() {
  local pct
  pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  [ -z "$pct" ] && return
  make_short "7d" "$pct"
  maybe_reset_suffix "$pct" "$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')"
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
