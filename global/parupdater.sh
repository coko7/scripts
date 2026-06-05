#!/usr/bin/env bash

echo "parUpdater.sh" | figlet | lolcat
echo

echo -n "✨ Command to run:"

echo "paru -Syu --noconfirm" |
  gum style --foreground=75 --border-foreground=212 \
    --border double --width 25 \
    --padding "1 2" --margin "1 0"

if ! gum confirm "Do you want to update your system now?" --default="yes"; then
  echo "Update cancelled."
  exit 0
fi

paru -Syu --noconfirm

# ask for input before exit
read -n 1 -s -r -p "Press any key to continue..." </dev/tty
