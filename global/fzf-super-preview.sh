#!/usr/bin/env bash

TREE_CMD='eza --color=always --icons --group-directories-first --tree --level=3'

if [[ -d "$1" ]]; then
    $TREE_CMD "$1"
elif [[ -f "$1" ]]; then
    fzf-preview.sh "$1"
else
    echo "$1 is not valid"
    exit 1
fi
