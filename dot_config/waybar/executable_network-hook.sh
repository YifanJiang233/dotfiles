#!/usr/bin/env bash

# Keep track of last trigger timestamp to enforce a cooldown (60 seconds)
last_trigger=0
cooldown=60

# When starting up, run an initial check in case network is coming online
sleep 3
if python3 "$HOME/.config/weather/weather.py" --refresh >/dev/null 2>&1; then
    pkill -RTMIN+8 waybar || true
fi
last_trigger=$(date +%s)

# Listen to Netlink events for interface address or routing changes
ip monitor address route | while read -r line; do
    # Only react to relevant network additions (default routes, assigned IPs, link up)
    if [[ "$line" =~ (default|inet|UP|Reachable|REACHABLE) ]]; then
        now=$(date +%s)
        elapsed=$((now - last_trigger))
        
        # Check if cooldown has elapsed
        if (( elapsed >= cooldown )); then
            # Pause briefly to allow DNS/routing to stabilize
            sleep 3
            if python3 "$HOME/.config/weather/weather.py" --refresh >/dev/null 2>&1; then
                pkill -RTMIN+8 waybar || true
                last_trigger=$(date +%s)
            fi
        fi
    fi
done
