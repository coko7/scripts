#!/usr/bin/env bash

SWWW_ANIM="random"

WP_LOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wallpaper.lock"
SOUND_FILE="$HOME/Music/sounds/quest_pluck.wav"

function choice_prompt() {
  local prompt="  Kanumi "
  local choice

  if [ -e "$WP_LOCK" ]; then
    LOCK_TG_OPT=' Unlock'
  else
    LOCK_TG_OPT=' Lock'
  fi

  choice=$(echo -e " Random\n󰥨 Directory\n󰥷 Image\n Identify\n󰒓 Configure\n${LOCK_TG_OPT}" |
    rofi -dmenu -p "$prompt" -i \
      -theme-str 'window {width: 280px; height: 330px;}')

  echo "$choice" | cut --delimiter=' ' --fields='2-' | tr '[:upper:]' '[:lower:]'
}

function pick_random() {
  monitor_names=$(hyprctl monitors all -j | jq --raw-output '.[].name')
  for monitor in $monitor_names; do
    img=$(kanumi list | shuf --head-count=1)
    awww img --outputs "$monitor" "$img" --transition-type $SWWW_ANIM
  done
}

function toggle_wp_lock() {
  if [ -e "$WP_LOCK" ]; then
    rm "$XDG_RUNTIME_DIR/wallpaper.lock"
    ntfy-toast.sh Kanumi "🔓 Unlocked wallpaper" ~/Pictures/icons/unlocked.png 'kanumi-lock' "$SOUND_FILE"
  else
    touch "$XDG_RUNTIME_DIR/wallpaper.lock"
    ntfy-toast.sh Kanumi "🔒 Locked wallpaper" ~/Pictures/icons/locked.png 'kanumi-lock' "$SOUND_FILE"
  fi
}

mode=$(choice_prompt)
case "$mode" in
random)
  pick_random
  ;;
directory)
  floatty.sh 'kanumi' fzf-awww-kanumi-dir.sh
  ;;
image)
  floatty.sh 'kanumi' fzf-awww-kanumi-img.sh
  ;;
identify)
  floatty.sh 'kanumi' fzf-awww-kanumi-identify.sh
  ;;
configure)
  floating-neovide.sh "kanumi-cfg" "$XDG_CONFIG_HOME/kanumi/config.toml"
  ;;
lock | unlock)
  toggle_wp_lock
  ;;
*)
  exit 1
  ;;
esac
