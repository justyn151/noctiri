#!/bin/sh
set -u

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/noctiri"
mkdir -p "$state_dir"

start_once() {
    process="$1"
    log_file="$2"
    shift 2
    if ! pgrep -u "$(id -u)" -x "$process" >/dev/null 2>&1; then
        "$@" >> "$state_dir/$log_file" 2>&1 &
    fi
}

# Make the compositor environment visible to portals, keyrings and desktop apps.
dbus-update-activation-environment --systemd \
    DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP \
    XDG_SESSION_TYPE >/dev/null 2>&1 || \
dbus-update-activation-environment \
    DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP \
    XDG_SESSION_TYPE >/dev/null 2>&1 || true

start_once swaync swaync.log swaync
start_once waybar waybar.log waybar \
    --config "$HOME/.config/waybar/config.jsonc" \
    --style "$HOME/.config/waybar/style.css"
start_once swayidle swayidle.log swayidle -w \
    timeout 600 'swaylock -f -c 151c1e' \
    before-sleep 'swaylock -f -c 151c1e'

if ! pgrep -u "$(id -u)" -f 'wl-paste.*cliphist store' >/dev/null 2>&1; then
    wl-paste --type text --watch cliphist store >> "$state_dir/cliphist.log" 2>&1 &
fi

if ! pgrep -u "$(id -u)" -f 'polkit-gnome-authentication-agent-1' >/dev/null 2>&1; then
    for agent in \
        /usr/libexec/polkit-gnome-authentication-agent-1 \
        /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1; do
        if [ -x "$agent" ]; then
            "$agent" >> "$state_dir/polkit-agent.log" 2>&1 &
            break
        fi
    done
fi

if ! awww query >/dev/null 2>&1; then
    awww-daemon >> "$state_dir/awww.log" 2>&1 &
    attempts=0
    while ! awww query >/dev/null 2>&1 && [ "$attempts" -lt 30 ]; do
        sleep 0.1
        attempts=$((attempts + 1))
    done
fi

if ! awww restore >/dev/null 2>&1; then
    wallpaper="$(cat "$HOME/.config/noctiri/tatami-wallpaper" 2>/dev/null || true)"
    if [ ! -f "$wallpaper" ]; then
        wallpaper="$(find "$HOME/Pictures/Wallpapers" -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            2>/dev/null | sort | head -n 1)"
    fi
    if [ -n "$wallpaper" ]; then
        "$HOME/.local/bin/noctiri-wallpaper" "$wallpaper" >/dev/null 2>&1 || true
    fi
fi
