#!/usr/bin/env bash

function confirm_prompt() {
  prompt=$1
  choice=$(echo -e " Yes\n No" |
    rofi -dmenu -p "$prompt" \
      -i -theme-str 'window {width: 250px; height: 150px;}')

  if [ "$choice" != " Yes" ]; then
    return 1
  fi

  return 0
}

function system_update_prompt() {
  choice=$(echo -e " Yes\n No" |
    rofi -dmenu -p "󰒓 Update system now? " \
      -i -theme-str 'window {width: 250px; height: 150px;}')

  if [ "$choice" != " Yes" ]; then
    return 1
  fi

  floatty.sh 'parupdater.sh' parupdater.sh
  return 0
}

# options="󰐥 Power off\n󰜉 Reboot\n󰒲 Suspend\n󰍃 Logout\n󰌾 Lock\n󰸉 Wallpaper"
options=" Install\n󰍹 Display\n󰐥 Power off\n󰜉 Reboot\n󰒲 Suspend\n󰌾 Lock\n Kanumi\n󰃬 Calculator\n󰛨 Backlight\n󰞋 Keybinds"
# pick=$(echo -e $options | rofi -dmenu -p "󰒓 Action" -i -theme-str 'window {width: 15%; height: 30%;}')
# pick=$(echo -e $options | rofi -dmenu -p "󰒓 Action" -i -theme-str 'window {width: 10%; height: 22%;}')
pick=$(echo -e "$options" | rofi -dmenu -p "   Action " -i -theme-str 'window {width: 450px; height: 300px;}')
formatted_pick=$(echo "$pick" | cut -d' ' -f2-)

case $formatted_pick in
"Power off")
  confirm_prompt "󰋣 Bed time? " || exit 0
  lp-ping.sh
  system_update_prompt
  ntfy-toast.sh 'System' "🫡 System will power off very soon..." o7_goodbye system-poweroff "$HOME/Music/sounds/snore_mimimi.wav"
  sleep 2s
  systemctl poweroff
  ;;
"Reboot")
  confirm_prompt "󰜉 Reboot? " || exit 0
  lp-ping.sh
  system_update_prompt
  ntfy-toast.sh 'System' "🫡 System will reboot very soon..." o7_goodbye system-poweroff "$HOME/Music/sounds/snore_mimimi.wav"
  sleep 2s
  systemctl reboot
  ;;
"Suspend") systemctl suspend ;;
# "Logout") confirm_prompt "U sure about logging out?" && loginctl terminate-session ;;
"Lock") loginctl lock-session ;;
"Kanumi") bash "rofi-kanumi.sh" ;;
"Calculator") bash "rofi-calc.sh" ;;
"Backlight") bash "rofi-man-backlight.sh" ;;
"Keybinds") bash "rofi-binds-help.sh" ;;
"Install") bash "rofi-pkg-install.sh" ;;
"Display") floatty.sh 'monzet' monzet.sh ;;
esac
