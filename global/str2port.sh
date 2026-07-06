#!/usr/bin/env bash
#
# port-from-name -- deterministically map a string to a port in [1024, 49151]
#
# Usage: port-from-name <string>
#        port-from-name --min 20000 --max 29999 <string>

set -euo pipefail

min=1024
max=49151

usage() {
  printf 'Usage: %s [--min PORT] [--max PORT] <string>\n' "${0##*/}" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --min)
    min="${2:?--min requires a value}"
    shift 2
    ;;
  --max)
    max="${2:?--max requires a value}"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  -*) usage ;;
  *) break ;;
  esac
done

[[ $# -eq 1 ]] || usage
input="$1"

if ((min < 1 || max > 65535 || min > max)); then
  printf 'Error: invalid port range %d-%d\n' "$min" "$max" >&2
  exit 1
fi

# Prefer sha256sum, fall back to shasum (macOS), then md5sum.
if command -v sha256sum >/dev/null 2>&1; then
  hash=$(printf '%s' "$input" | sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  hash=$(printf '%s' "$input" | shasum -a 256)
elif command -v md5sum >/dev/null 2>&1; then
  hash=$(printf '%s' "$input" | md5sum)
else
  printf 'Error: no hash utility found (sha256sum/shasum/md5sum)\n' >&2
  exit 1
fi
hash=${hash%% *} # strip filename column

num=$((16#${hash:0:8})) # first 32 bits of the hash
range=$((max - min + 1))
port=$((min + num % range))

printf '%d\n' "$port"
