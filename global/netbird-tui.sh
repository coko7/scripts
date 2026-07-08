#!/usr/bin/env bash

# nb — fzf-driven NetBird helper
#
# Fuzzy-pick an action (profile select / connect|disconnect / status),
# with a live preview pane showing connection state + netbird version.
#
# Requirements: netbird, fzf
# Usage: just run `nb`

set -euo pipefail

NB="${NB:-netbird}"
VPN_STATE_FILE="${VPN_STATE_FILE:-$HOME/.cache/vpn-state}"

# If the daemon socket needs root and we aren't, prefix with sudo.
if ! "$NB" status &>/dev/null && command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
  NB="sudo $NB"
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

connected() {
  # "Management: Connected" is the most reliable signal across versions
  $NB status 2>/dev/null |
    grep --quiet --ignore-case --extended-regexp '^\s*Management:\s*Connected'
}

current_profile() {
  # Active profile is usually marked with a '*'; fall back to 'default'
  $NB profile list 2>/dev/null |
    awk '/✓/ {gsub(/✓/,""); print $1; found=1} END {if (!found) print "default"}'
}

notify() {
  # notify up|down — desktop toast via ntfy-toast.sh + waybar state file
  local verb sound
  if [[ "$1" == "up" ]]; then
    verb="Connected to"
    sound="service-login"
    current_profile >"$VPN_STATE_FILE" # <-- new
  else
    verb="Disconnected from"
    sound="service-logout"
    rm --force "$VPN_STATE_FILE" # <-- new
  fi
  pkill -RTMIN+8 waybar || true # <-- new
  ntfy-toast.sh Netbird \
    "${verb} Netbird — \"$(current_profile)\" 👋" \
    netbird.png \
    'ntfy-netbird-sig-down' \
    "/usr/share/sounds/freedesktop/stereo/${sound}.oga" || true
}

# ---------------------------------------------------------------------------
# Preview pane (invoked by fzf as: $0 --preview <highlighted-action>)
# ---------------------------------------------------------------------------

if [[ "${1:-}" == "--preview" ]]; then
  action="${2:-}"

  echo "┌─ NetBird ─────────────────────────"
  echo "│ version : $($NB version 2>/dev/null || echo 'n/a')"
  echo "│ profile : $(current_profile)"
  if connected; then
    echo "│ state   : 🟢 connected"
  else
    echo "│ state   : 🔴 disconnected"
  fi
  echo "└───────────────────────────────────"
  echo

  case "$action" in
  profile*)
    echo "Available profiles:"
    $NB profile list 2>/dev/null || echo "  (profile support requires netbird >= 0.52)"
    ;;
  *)
    $NB status 2>/dev/null | head -20 || echo "daemon not reachable"
    ;;
  esac
  exit 0
fi

# ---------------------------------------------------------------------------
# Build the menu based on current state
# ---------------------------------------------------------------------------

if connected; then
  toggle_label="disconnect  (netbird down)"
  toggle_cmd="down"
else
  toggle_label="connect     (netbird up)"
  toggle_cmd="up"
fi

menu=$(printf '%s\n' \
  "$toggle_label" \
  "profile     (switch profile)" \
  "status      (detailed status)")

choice=$(printf '%s\n' "$menu" | fzf-rofi.sh \
  --prompt="netbird > " \
  --layout=reverse \
  --preview="'$0' --preview {}" \
  --preview-window=right,55%,wrap) || exit 0

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------

case "$choice" in
connect* | disconnect*)
  $NB "$toggle_cmd"
  notify "$toggle_cmd" # <-- new
  echo
  $NB status | head -10
  ;;

profile*)
  profile=$($NB profile list 2>/dev/null |
    tail -n +2 |
    sed 's/✓//g' |
    awk 'NF {print $1}' |
    fzf-rofi.sh --prompt="profile > " \
      --layout=reverse \
      --preview="'$0' --preview profile" \
      --preview-window=right,55%,wrap) || exit 0

  was_connected=false
  connected && was_connected=true

  $NB down 2>/dev/null || true
  $NB profile select "$profile"
  echo "Switched to profile: $profile"

  if $was_connected; then
    $NB up
    notify up # <-- new
    echo
    $NB status | head -10
  fi
  ;;

status*)
  $NB status --detail
  ;;
esac
