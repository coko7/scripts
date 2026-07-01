#!/usr/bin/env bash

wm_class_suffix="$1"
shift

full_wm_class="floater-kitty-$wm_class_suffix"

# prevent multiple floater-kitty-<FOO> windows to be opened at the same time
hyprctl clients -j |
  jq --exit-status --arg wm_class "$full_wm_class" \
    'any(.[]; .class == $wm_class)' >/dev/null 2>&1 &&
  exit 1

if [[ -n "$FLOATTY_CAPTURE_OUTPUT" ]]; then
  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' EXIT

  kitty --class "$full_wm_class" sh -c "$* > \"$tmpfile\""

  if [[ -s "$tmpfile" ]]; then
    cat "$tmpfile"
  fi
else
  kitty --class "$full_wm_class" sh -c "$*"
fi
