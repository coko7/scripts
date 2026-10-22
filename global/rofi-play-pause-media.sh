#!/usr/bin/env bash

get_summary() {
  local player=$1
  local status label title artist res

  status=$(playerctl --player="$player" status 2>/dev/null)
  case $status in
  Playing) label="" ;;
  Paused) label="" ;;
  *) label="" ;;
  esac

  title=$(playerctl --player="$player" metadata --format '{{title}}' 2>/dev/null)
  artist=$(playerctl --player="$player" metadata --format '{{artist}}' 2>/dev/null)

  res="$label $player: $title"
  [[ -n "$artist" ]] && res+=" ($artist)"
  printf '%s\n' "$res"
}

mapfile -t players < <(
  playerctl --list-all 2>/dev/null | while IFS= read -r player; do
    [[ "$player" == "playerctld" ]] && continue

    status=$(playerctl --player="$player" status 2>/dev/null)
    if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
      printf '%s\n' "$player"
    fi
  done
)

case ${#players[@]} in
0) exit 0 ;;
1) target=${players[0]} ;;
*)
  pick=$(
    for player in "${players[@]}"; do get_summary "$player"; done |
      rofi -dmenu -i -format i -p " 󰐎 Play/Pause " -theme-str 'window {width: 800px;}'
  ) || exit 0
  [[ "$pick" =~ ^[0-9]+$ ]] && ((pick < ${#players[@]})) || exit 1
  target=${players[$pick]}
  ;;
esac

playerctl --player="$target" play-pause && bash notify-media.sh "$target"
