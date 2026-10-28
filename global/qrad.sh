#!/usr/bin/env bash

URL=${1:-https://coko7.fr}

seed=$((1 + RANDOM % 725))
echo -e "\n      $URL" |
  lolcat --seed=$seed --force
echo -e '\n        * Portfolio *'

echo "$URL" |
  qrencode --type=utf8i |
  lolcat --seed=$seed --force

read -rp "         󰐳  Scan it!"
