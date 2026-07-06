#!/usr/bin/env bash

CSV_FILE="$HOME/.local/scripts/data/private/secret_terms.csv"

awk -F',' '
BEGIN {
    IGNORECASE = 1
}

NR==FNR {
    if (FNR == 1) next  # skip header
    map[$1] = $2
    next
}

{
    line = $0
    for (k in map) {
        gsub(k, map[k], line)
    }
    print line
}
' "$CSV_FILE" -
