#!/usr/bin/env bash

fd --follow --extension sh . "$HOME/.local/scripts" |
  fzf --preview 'bat --force-colorization {}' \
    --bind 'enter:become(nvim {})'
