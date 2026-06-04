#!/usr/bin/env bash

input="${1:-curry}"
entries=$(cat "$HOME/.local/scripts/data/geo-locations.json")

detailed=0
if [[ "$input" == *+ ]]; then
  input="${input%+}"
  detailed=1
fi

entry=$(jq --raw-output --arg input "$input" \
  '.[] | select(.name == $input or (.aliases[]? == $input))' <<<"$entries")

if [[ -z "$entry" ]]; then
  echo "Error: location '$input' not found in geo-locations.json" >&2
  exit 1
fi

name=$(jq --raw-output '.name' <<<"$entry")
latitude=$(jq --raw-output '.lat' <<<"$entry")
longitude=$(jq --raw-output '.lon' <<<"$entry")

gum style \
  --foreground 212 --border-foreground 212 --border double \
  --align center --width 30 --margin "1 2" --padding "1 2" \
  'Showing weather for' "$name"

if [[ $detailed -eq 1 ]]; then
  curl "https://wttr.in/${latitude},${longitude}?1"
else
  curl "https://wttr.in/${latitude},${longitude}?0"
fi
