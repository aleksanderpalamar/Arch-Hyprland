#!/bin/bash

# Kill running waybar instances
killall waybar

# Wait for process to end
while pgrep -x waybar >/dev/null; do sleep 0.1; done

# Start waybar
waybar &

# Send notification
notify-send "Waybar" "Reloaded successfully" -i waybar
