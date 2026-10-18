#!/usr/bin/env bash

# page=$(rustup doc --path "$1") || return 1
# w3m "$page"

PORT=8000
DIR="$(rustc --print sysroot)/share/doc/rust/html"

python -m http.server "$PORT" --bind 127.0.0.1 --directory "$DIR" &
pid=$!

trap 'kill "$pid" 2>/dev/null' INT TERM
sleep 0.5

xdg-open "http://127.0.0.1:${PORT}/${1:-std}/"
wait "$pid"
trap - INT TERM
