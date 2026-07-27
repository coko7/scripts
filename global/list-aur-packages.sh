#!/usr/bin/env bash
#
# list-aur-packages.sh
#
# Lists all foreign (AUR / manually-installed) packages on the system
# along with their description, upstream URL, and what (if anything) on
# the system depends on them (via pactree -r), sorted by install date
# (oldest first). Useful for spotting old/forgotten/orphaned packages
# during cleanup.
#
# Usage:
#   ./list-aur-packages.sh              # table view, sorted oldest -> newest
#   ./list-aur-packages.sh --reverse    # newest -> oldest
#   ./list-aur-packages.sh --csv        # CSV output (for spreadsheets/scripts)
#   ./list-aur-packages.sh --no-deps    # skip pactree lookups (much faster)
#   ./list-aur-packages.sh --orphans-only  # only show packages nothing depends on
#   ./list-aur-packages.sh --no-color   # disable colored output

set -euo pipefail

REVERSE=false
CSV=false
NO_DEPS=false
ORPHANS_ONLY=false
NO_COLOR_FLAG=false

for arg in "$@"; do
  case "$arg" in
  --reverse) REVERSE=true ;;
  --csv) CSV=true ;;
  --no-deps) NO_DEPS=true ;;
  --orphans-only) ORPHANS_ONLY=true ;;
  --no-color) NO_COLOR_FLAG=true ;;
  -h | --help)
    echo "Usage: $0 [--reverse] [--csv] [--no-deps] [--orphans-only] [--no-color]"
    exit 0
    ;;
  esac
done

# Colors: only enabled for the table view, on a real terminal, unless
# disabled via --no-color or the NO_COLOR env var (see no-color.org).
if ! $CSV && [ -t 1 ] && ! $NO_COLOR_FLAG && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_SEP=$'\033[90m'      # grey
  C_NAME=$'\033[1;36m'   # bold cyan
  C_VER=$'\033[36m'      # cyan
  C_LABEL=$'\033[34m'    # blue
  C_URL=$'\033[4;34m'    # underline blue
  C_ORPHAN=$'\033[1;33m' # bold yellow
  C_OK=$'\033[32m'       # green
else
  C_RESET=""
  C_SEP=""
  C_NAME=""
  C_VER=""
  C_LABEL=""
  C_URL=""
  C_ORPHAN=""
  C_OK=""
fi

if ! $NO_DEPS && ! command -v pactree &>/dev/null; then
  echo "Warning: pactree not found (install 'pacman-contrib') -- falling back to --no-deps" >&2
  NO_DEPS=true
fi

# Tab-separated intermediate format:
#   date_epoch<TAB>date_human<TAB>name<TAB>version<TAB>url<TAB>description<TAB>required_by
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

for pkg in $(pacman -Qmq); do
  info=$(pacman -Qi "$pkg")

  ver=$(echo "$info" | awk -F': ' '/^Version/{print $2; exit}')
  url=$(echo "$info" | awk -F': ' '/^URL/{print $2; exit}')
  desc=$(echo "$info" | awk -F': ' '/^Description/{ $1=""; sub(/^: /,""); print; exit}')
  idate=$(echo "$info" | awk -F': ' '/^Install Date/{ $1=""; sub(/^: /,""); print; exit}')

  epoch=$(date -d "$idate" +%s 2>/dev/null || echo 0)

  if $NO_DEPS; then
    reqby="(skipped)"
  else
    reqby=$(pactree -r "$pkg" 2>/dev/null | tail -n +2 | paste -sd'; ' -)
    [ -z "$reqby" ] && reqby="ORPHAN (nothing depends on it)"
  fi

  if $ORPHANS_ONLY && [ "$reqby" != "ORPHAN (nothing depends on it)" ]; then
    continue
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$epoch" "$idate" "$pkg" "$ver" "${url:-N/A}" "${desc:-N/A}" "$reqby" >>"$tmpfile"
done

if $REVERSE; then
  sort -t$'\t' -k1,1nr "$tmpfile" -o "$tmpfile"
else
  sort -t$'\t' -k1,1n "$tmpfile" -o "$tmpfile"
fi

if $CSV; then
  echo "install_date,name,version,url,description,required_by"
  while IFS=$'\t' read -r _ idate name ver url desc reqby; do
    # basic CSV escaping (wrap fields in quotes, escape internal quotes)
    esc() { printf '"%s"' "$(echo "$1" | sed 's/"/""/g')"; }
    printf '%s,%s,%s,%s,%s,%s\n' "$(esc "$idate")" "$(esc "$name")" "$(esc "$ver")" "$(esc "$url")" "$(esc "$desc")" "$(esc "$reqby")"
  done <"$tmpfile"
else
  orphan_count=0
  while IFS=$'\t' read -r _ idate name ver url desc reqby; do
    echo "${C_SEP}─────────────────────────────────────────────────────────${C_RESET}"
    echo "${C_LABEL}Package     :${C_RESET} ${C_NAME}${name}${C_RESET} (${C_VER}${ver}${C_RESET})"
    echo "${C_LABEL}Installed   :${C_RESET} $idate"
    echo "${C_LABEL}URL         :${C_RESET} ${C_URL}${url}${C_RESET}"
    echo "${C_LABEL}Description :${C_RESET} $desc"
    if [ "$reqby" = "ORPHAN (nothing depends on it)" ]; then
      echo "${C_LABEL}Required by :${C_RESET} ${C_ORPHAN}${reqby}${C_RESET}"
      orphan_count=$((orphan_count + 1))
    else
      echo "${C_LABEL}Required by :${C_RESET} ${C_OK}${reqby}${C_RESET}"
    fi
  done <"$tmpfile"
  echo "${C_SEP}─────────────────────────────────────────────────────────${C_RESET}"
  echo "${C_LABEL}Total foreign packages:${C_RESET} $(wc -l <"$tmpfile")"
  if ! $NO_DEPS; then
    echo "${C_ORPHAN}Orphans (nothing depends on them): ${orphan_count}${C_RESET}"
  fi
fi
