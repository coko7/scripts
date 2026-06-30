#!/usr/bin/env bash
#
# temp_monitor.sh - Poll temperature for a named location every 5 min,
# send a desktop notification (notify-send) if it exceeds a threshold.
#
# Looks up lat/lon from $HOME/.local/scripts/data/geo-locations.json,
# matching on "name" or "aliases". Uses Open-Meteo (no API key) for
# current temperature, and notify-send for desktop notifications.
#
# Usage:
#   ./temp_monitor.sh <location> <threshold_celsius> [+]
#
# The trailing "+" enables detailed/verbose logging each poll.
#
# Example:
#   ./temp_monitor.sh curry 30
#   ./temp_monitor.sh curry+ 30

set -euo pipefail

default='curry'
input="${1:-}"
threshold="${2:?Usage: $0 <location> <threshold_celsius> [+]}"

entries=$(cat "$HOME/.local/scripts/data/geo-locations.json")

detailed=0
if [[ "$input" == *+ ]]; then
  detailed=1
  input="${input%+}"
fi

input="${input:-$default}"

entry=$(jq --raw-output --arg input "$input" '
  limit(1; .[] | select(.name == $input or (.aliases[]? == $input)))
' <<<"$entries")

if [[ -z "$entry" ]]; then
  echo "Error: location '$input' not found in geo-locations.json" >&2
  exit 1
fi

name=$(jq --raw-output '.name' <<<"$entry")
latitude=$(jq --raw-output '.lat' <<<"$entry")
longitude=$(jq --raw-output '.lon' <<<"$entry")

interval=300 # 5 minutes

echo "Monitoring '${name}' (${latitude}, ${longitude}) every $((interval / 60)) min, threshold ${threshold}°C"

while true; do
  temp=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current=temperature_2m" |
    jq --raw-output '.current.temperature_2m')

  if [[ -z "$temp" || "$temp" == "null" ]]; then
    echo "$(date): failed to fetch temperature for '${name}'" >&2
  else
    if [[ "$detailed" -eq 1 ]]; then
      echo "$(date): ${name} -> ${temp}°C (threshold ${threshold}°C, lat=${latitude}, lon=${longitude})"
    else
      echo "$(date): ${name} -> ${temp}°C"
    fi

    if (($(echo "$temp > $threshold" | bc -l))); then
      notify-send --urgency=critical "Temperature Alert" "${name} is ${temp}°C, above threshold of ${threshold}°C."
    fi
  fi

  sleep "$interval"
done
