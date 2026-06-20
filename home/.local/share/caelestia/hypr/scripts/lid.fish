#!/usr/bin/env fish
# Lid handler. close: if external monitor present blank eDP, else suspend. open: re-enable eDP.

set action $argv[1]
set external (hyprctl monitors -j | jq -r '.[] | select(.name != "eDP-1") | .name' | head -n1)

switch $action
    case close
        if test -n "$external"
            hyprctl keyword monitor "eDP-1, disable"
        else
            systemctl suspend
        end
    case open
        sleep 1
        hyprctl dispatch dpms on
        hyprctl reload
end
