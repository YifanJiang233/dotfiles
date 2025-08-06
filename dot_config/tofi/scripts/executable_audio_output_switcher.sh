#!/bin/bash

# Tofi Audio Output Switcher
#
# This script displays a human-readable list of available audio output
# devices (sinks) using tofi, and allows the user to select one to set
# as the default.
#
# Dependencies:
# - tofi: A dynamic menu for Wayland.
# - pulseaudio-utils: Provides the 'pactl' command.
# - jq: A lightweight and flexible command-line JSON processor.

# Get a list of sinks with their descriptions and names in a "Description\tName" format.
# We use pactl's JSON output and parse it with jq for reliability.
sinks_info=$(pactl -f json list sinks | jq -r '.[] | "\(.description)\t\(.name)"')

# Check if sinks_info is empty (e.g., pactl failed or no sinks found)
if [ -z "$sinks_info" ]; then
  # You can use a notification tool like notify-send here if you have it installed.
  # notify-send "Audio Switcher Error" "Could not find any audio output devices." >/dev/null 2>&1
  exit 1
fi

# Extract just the descriptions to show in tofi.
descriptions=$(echo -e "$sinks_info" | cut -f1)

dmenu=$HOME/.config/tofi/dmenu_config

# Display the list of descriptions in tofi and get the user's selection.
chosen_desc=$(echo -e "$descriptions" | tofi --include="$dmenu" --prompt-text "Select Audio Output: ")

# If the user made a selection (i.e., didn't cancel tofi),
# find the corresponding sink name and set it as the default.
if [ -n "$chosen_desc" ]; then
  # Find the line matching the chosen description, take the first match in case of duplicates,
  # and extract the sink name (the second field).
  chosen_name=$(echo -e "$sinks_info" | grep -F "$chosen_desc" | head -n 1 | cut -f2)

  # Set the chosen sink as the default.
  pactl set-default-sink "$chosen_name"
fi
