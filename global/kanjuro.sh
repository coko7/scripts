#!/usr/bin/env bash

# ================================ WARNING ==================================== #
#                                                                               #
# This script only works with Hyprland compositor / Window manager for Wayland. #
#                                                                               #
# ================================ WARNING ==================================== #

set -euo pipefail

# Skip kanjuro if lock file exists
LOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wallpaper.lock"
[ -e "$LOCK" ] && exit 0

monitor_names=$(hyprctl monitors all -j | jq --raw-output '.[].name')

for monitor in $monitor_names; do
  if ! img=$(kanumi list | shuf --head-count=1); then
    ntfy-toast.sh Kanumi \
      "Failed to switch wallpaper. Check your kanumi cfg" \
      art.png \
      'ntfy-kanumi-failed' \
      "/usr/share/sounds/freedesktop/stereo/dialog-information.oga" || true
  fi
  awww img --outputs "$monitor" "$img" --transition-type outer
done
