#!/usr/bin/env fish
# Per-power lid handler. A user service holds logind's handle-lid-switch inhibitor while
# this session is running, so this script is the single owner of close-lid behaviour.
# Docked sessions keep running and only blank eDP; undocked sessions use the action chosen
# in Caelestia's Power & Sleep settings.

set -l event $argv[1]
set -l external (hyprctl monitors -j | jq -r '.[] | select(.name != "eDP-1") | .name' | head -n1)

switch $event
    case close
        if test -n "$external"
            hyprctl keyword monitor "eDP-1, disable"
            return
        end

        set -l power_state (busctl --system get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null)
        set -l pref_key acLidAction
        if string match -q '*true' -- "$power_state"
            set pref_key batLidAction
        end

        set -l lid_action suspend
        set -l prefs "$HOME/.config/caelestia/power-prefs.json"
        if test -r "$prefs"
            set -l configured (jq -r --arg key "$pref_key" '.[$key] // empty' "$prefs" 2>/dev/null)
            if test "$configured" = suspend -o "$configured" = hibernate
                set lid_action "$configured"
            end
        end

        systemctl "$lid_action"
    case open
        sleep 1
        hyprctl dispatch dpms on
        hyprctl reload
end
