#!/usr/bin/env fish

# wsaction.fish [-g] <dispatcher> <workspace>
#
# In "separate" workspace mode (per-monitor), a plain Super+N targets the FOCUSED MONITOR's
# block: base comes from ~/.config/caelestia/workspace-monitors (monitor -> base), written by
# workspace-mode.fish. This is robust regardless of which workspace the monitor currently shows
# (the old "base from active workspace" math jumped focus to the other monitor). Otherwise the
# original caelestia group-of-10 behaviour is used.

if test "$argv[1]" = '-g'
    set group
    set -e $argv[1]
end

if test (count $argv) -ne 2
    echo 'Wrong number of arguments. Usage: ./wsaction.fish [-g] <dispatcher> <workspace>'
    exit 1
end

set -l map $HOME/.config/caelestia/workspace-monitors
set -l mode (cat $HOME/.config/caelestia/workspace-mode 2>/dev/null)

if not set -q group; and test "$mode" = separate; and test -s $map
    set -l mon (hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    set -l base (awk -v m="$mon" '$1==m {print $2}' $map)
    test -z "$base"; and set base 0
    hyprctl dispatch $argv[1] (math "$base + $argv[2]")
else
    set -l active_ws (hyprctl activeworkspace -j | jq -r '.id')
    if set -q group
        hyprctl dispatch $argv[1] (math "($argv[2] - 1) * 10 + $active_ws % 10")
    else
        hyprctl dispatch $argv[1] (math "floor(($active_ws - 1) / 10) * 10 + $argv[2]")
    end
end
