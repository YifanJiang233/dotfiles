#!/bin/bash

# Define the "launch new" option text
LAUNCH_NEW="[+] Launch New Instance"

# Get running instances using swaymsg and jq
# We look for containers whose class is "maplelegends.exe" or name contains "MapleLegends"
# We extract their ID and their first mark (or "Unmarked")
instances_json=$(swaymsg -t get_tree | jq -r '
  .. | select(.window_properties?) | 
  select(.window_properties.class == "maplelegends.exe" or (.name | test("MapleLegends"; "i"))) | 
  "\(.id)|\(.marks[0] // "Unmarked")"
')

# Prepare the options for Tofi
options="$LAUNCH_NEW"
while IFS="|" read -r id mark; do
    if [ -n "$id" ]; then
        options="$options\nInstance: $mark (ID: $id)"
    fi
done <<< "$instances_json"

# Show Tofi menu
selected=$(echo -e "$options" | tofi --prompt-text="MapleLegends: ")

if [ -z "$selected" ]; then
    exit 0
fi

if [ "$selected" = "$LAUNCH_NEW" ]; then
    # Prompt for instance name
    instance_name=$(echo "" | tofi --require-match=false --prompt-text="Instance Name: ")
    
    if [ -n "$instance_name" ]; then
        # Launch the game in the background
        /home/yifan/Games/MapleLegends/run.sh &
        
        # Start a background process to watch for the new window and mark it
        (
            for i in {1..30}; do
                # Find an unmarked MapleLegends window
                unmarked_id=$(swaymsg -t get_tree | jq -r '
                  .. | select(.window_properties?) | 
                  select((.window_properties.class == "maplelegends.exe" or (.name | test("MapleLegends"; "i"))) and .marks == []) | 
                  .id
                ' | head -n 1)
                
                if [ -n "$unmarked_id" ] && [ "$unmarked_id" != "null" ]; then
                    swaymsg "[con_id=$unmarked_id] mark \"$instance_name\""
                    break
                fi
                sleep 1
            done
        ) &
    fi
else
    # Extract the ID from the selected string (e.g. "Instance: MyName (ID: 123)")
    window_id=$(echo "$selected" | grep -oP '\(ID: \K\d+(?=\))')
    if [ -n "$window_id" ]; then
        # If it is unmarked, offer to name it now
        if [[ "$selected" == *"Instance: Unmarked "* ]]; then
            new_name=$(echo "" | tofi --require-match=false --prompt-text="Name this instance (or press Enter to skip): ")
            if [ -n "$new_name" ]; then
                swaymsg "[con_id=$window_id] mark \"$new_name\""
            fi
        fi
        swaymsg "[con_id=$window_id] focus"
    fi
fi
