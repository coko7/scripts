#!/usr/bin/env bash

ICONS_DIR="$HOME/Pictures/icons/"
DEFAULT_ICON="$ICONS_DIR/navi.png"
MISSING_ICON="$ICONS_DIR/missing_texture.png"

title="$1"
body="$2"
img_path="${3:-$DEFAULT_ICON}"
hint="${4:-'misc-ntfy'}"
sound_file="${5-/usr/share/sounds/freedesktop/stereo/bell.oga}"

if [ -z "$body" ]; then
  body="$1"
  title="Hey listen!"
fi

# check if absolute path (starts with root)
if [[ "$img_path" == /* ]]; then

  # if exists
  if [ -f "$img_path" ]; then
    img_path_abs="$img_path"
  else
    img_path_abs="$MISSING_ICON"
  fi
else

  # search in icons dir
  search_result=$(fd "$img_path" "$ICONS_DIR")

  if [ -f "$search_result" ]; then
    img_path_abs="$search_result"
  else
    img_path_abs="$MISSING_ICON"
  fi
fi

notify-send --urgency=low "$title" "$body" \
  --icon="$img_path_abs" --expire-time=2000 \
  --hint="string:x-canonical-private-synchronous:$hint" \
  --transient
paplay "$sound_file"
