#!/usr/bin/env fish
# Watch for monitor events; apply nwg-displays layout on connect, reset eDP on disconnect.

set runtime_dir (set -q XDG_RUNTIME_DIR; and echo $XDG_RUNTIME_DIR; or echo /run/user/(id -u))
set instance_signature $HYPRLAND_INSTANCE_SIGNATURE

if test -z "$instance_signature"
    set instance_signature (hyprctl instances -j | jq -r '.[0].instance')
end

set socket $runtime_dir/hypr/$instance_signature/.socket2.sock
set monitors_conf ~/.config/hypr/monitors.conf

function apply_monitors_conf
    grep -v '^#' $monitors_conf | grep -v '^$' | while read -l line
        set keyword (string split -m1 '=' $line)
        hyprctl keyword $keyword[1] $keyword[2]
    end
end

function reset_edp_to_origin
    hyprctl keyword monitor "eDP-1, 1920x1080@144.0, 0x0, 1.0"
end

function reset_monitor_to_origin
    set monitor_name $argv[1]

    if test "$monitor_name" = "eDP-1"
        reset_edp_to_origin
    else
        hyprctl keyword monitor "$monitor_name, preferred, 0x0, 1.0"
    end
end

function reconcile_monitors
    hyprctl dispatch dpms on

    set monitors (hyprctl monitors -j | jq -r '.[].name')

    if test (count $monitors) -gt 1
        apply_monitors_conf
    else if test (count $monitors) -eq 1
        reset_monitor_to_origin $monitors[1]
    end
end

# Boot check: fix stale nwg-displays coordinates before the first manual reload.
sleep 1
reconcile_monitors

socat -u UNIX-CONNECT:$socket - | while read -l event
    if string match -q "monitorremoved>>*" $event
        sleep 0.5
        reconcile_monitors
    else if string match -q "monitoradded>>*" $event
        # Re-apply saved nwg-displays layout immediately on hotplug
        sleep 0.8
        reconcile_monitors
    end
end
