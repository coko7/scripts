#!/usr/bin/env bash

function ensure_installed() {
  if ! command -v "$1" &>/dev/null; then
    echo "This script requires '$1' to be installed." >&2
    exit 1
  fi
}

ensure_installed gh
ensure_installed gum
ensure_installed date

TOPICS="${1:-all}"
LANGS="${2:-all}"
LIMIT="${3:-20}"

[[ "$TOPICS" == "all" ]] && [[ "$LANGS" == "all" ]] && {
  echo "You cannot specify 'ALL' for TOPICS and LANGS at the same time"
  exit 1
}

# NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
WEEK=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)
MONTH=$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)
YEAR=$(date -u -d '365 days ago' +%Y-%m-%dT%H:%M:%SZ)

TEMPLATE="
{{tablerow \"NAME\" \"DESCRIPTION\" \"LAST PUSH\" \"STARS\" \"FORKS\"}}
{{range .}}
  {{- \$desc := .description -}}
  {{- if gt (len \$desc) 100 -}}
    {{- \$desc = printf \"%.100s…\" \$desc -}}
  {{- end -}}

  {{- \$p := .pushedAt -}}

  {{- if ge \$p \"$WEEK\" -}}
    {{- \$p = color \"green\" \$p -}}
  {{- else if ge \$p \"$MONTH\" -}}
    {{- \$p = color \"blue\" \$p -}}
  {{- else if ge \$p \"$YEAR\" -}}
    {{- \$p = color \"yellow\" \$p -}}
  {{- else -}}
    {{- \$p = color \"red\" \$p -}}
  {{- end -}}

  {{tablerow .fullName \$desc \$p .stargazersCount .forksCount}}
{{end}}
{{tablerender}}
"

args=(
  --sort stars
  --order desc
  --json fullName,description,pushedAt,stargazersCount,forksCount
  --template "$TEMPLATE"
  --limit "$LIMIT"
)

[[ "$TOPICS" != "all" ]] && args+=(--topic "$TOPICS")
[[ "$LANGS" != "all" ]] && args+=(--language "$LANGS")

gh search repos "${args[@]}"

echo 'Searched with:' | gum style --foreground=212 --underline

echo -n "  - topics: "
echo "$TOPICS" | gum style --foreground=177 --bold

echo -n "  - langs: "
echo "$LANGS" | gum style --foreground=177 --bold
