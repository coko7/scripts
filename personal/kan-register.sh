#!/usr/bin/env bash

PREVIEW_CMD='fzf-super-preview.sh'
metadatas_path=$(kanumi config show --json | jq --raw-output '.meta_path')

while true; do
  pick=$(kanumi scan --json | jq --raw-output '.new[]' | fzf \
    --border-label ' Kanumi Interactive Register ' --input-label ' Input ' \
    --list-label ' Unregistered Images ' --preview-label ' Image Preview ' \
    --preview="$PREVIEW_CMD {}" --height 80% \
    --preview-window=down:40%)
  [[ -z "$pick" ]] && exit 1

  # kitten icat "$pick"
  score=$(seq 0 10 | fzf \
    --border-label ' Kanumi Register ' --input-label ' Input ' \
    --list-label ' Boxa Scores ' --preview-label ' Image Preview ' \
    --preview="$PREVIEW_CMD $pick" --height 80%)
  [[ -z "$score" ]] && exit 1

  all_metas=$(cat "$metadatas_path")
  if raw_json=$(kanumi meta gen "$pick"); then
    new_json=$(echo "$raw_json" |
      jq --argjson val "$score" '.scores += [{"name":"boxa", "value": $val}]')

    echo "$all_metas" | jq --argjson obj "$new_json" '. += [$obj]' >"$metadatas_path"
  fi
done
