#!/bin/bash

print_error() {
    cat <<"HELP"
Usage: ./volume-control.sh <action>
Actions:
    i   -- increase volume [+5%]
    d   -- decrease volume [-5%]
    m   -- toggle mute
HELP
    exit 1
}

notify_mute() {
    mute=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')
    if [ "${mute}" = "yes" ]; then
        swayosd-client --output-volume mute
    else
        swayosd-client --output-volume unmute
    fi
}

action_volume() {
    current_vol=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -m1 'Volume:' | awk '{print $5}' | sed 's/%//')

    case "${1}" in
    i)
        if [ "$current_vol" -lt 100 ]; then
            new_vol=$((current_vol + 5))
            [ "$new_vol" -gt 100 ] && new_vol=100
            pactl set-sink-volume @DEFAULT_SINK@ "${new_vol}%"
            swayosd-client --output-volume raise
        fi
        ;;
    d)
        new_vol=$((current_vol - 5))
        [ "$new_vol" -lt 0 ] && new_vol=0
        pactl set-sink-volume @DEFAULT_SINK@ "${new_vol}%"
        swayosd-client --output-volume lower
        ;;
    esac
}

case "${1}" in
i) action_volume i ;;
d) action_volume d ;;
m) pactl set-sink-mute @DEFAULT_SINK@ toggle && notify_mute ;;
*) print_error ;;
esac
