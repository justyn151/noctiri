#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/niri-noctalia-installer-backup"
INSTALL_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/noctiri-installer/completed"
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$RUN_STAMP"
DISTRO_ID=""
DISTRO_NAME=""
GREETER_USER=""
STEP_DEFERRED=75

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

ask_yes_no() {
    local prompt="$1" default="${2:-y}" reply
    if [[ "$default" == "y" ]]; then
        read -r -p "$prompt [Y/n] " reply || true
        reply="${reply:-y}"
    else
        read -r -p "$prompt [y/N] " reply || true
        reply="${reply:-n}"
    fi
    [[ "$reply" =~ ^[Yy]$ ]]
}

backup_path() {
    local path="$1"
    [[ -e "$path" || -L "$path" ]] || return 0
    mkdir -p "$BACKUP_DIR"
    local rel="${path#/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a -- "$path" "$BACKUP_DIR/$rel"
}

install_file() {
    local src="$1" dst="$2" mode="${3:-0644}"
    backup_path "$dst"
    mkdir -p "$(dirname "$dst")"
    install -m "$mode" "$src" "$dst"
}

render_home_template() {
    local src="$1" dst="$2"
    backup_path "$dst"
    mkdir -p "$(dirname "$dst")"
    sed "s|@@HOME@@|$HOME|g" "$src" > "$dst"
}

have() { command -v "$1" >/dev/null 2>&1; }

import_graphical_session_environment() {
    local process_id name value

    # SSH and TTY shells do not inherit the environment of the running desktop.
    # Noctalia is a reliable child of the Niri session and carries the variables
    # needed to launch graphical applications into that session.
    process_id="$(pgrep -u "$(id -u)" -xo noctalia 2>/dev/null || true)"
    [[ -n "$process_id" && -r "/proc/$process_id/environ" ]] || return 0

    for name in XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY NIRI_SOCKET; do
        value="$(tr '\0' '\n' < "/proc/$process_id/environ" \
            | sed -n "s/^${name}=//p" | head -n 1)"
        [[ -n "$value" ]] || continue
        printf -v "$name" '%s' "$value"
        export "$name"
    done
}

step_is_complete() {
    [[ -f "$INSTALL_STATE_DIR/$1" ]]
}

mark_step_complete() {
    mkdir -p "$INSTALL_STATE_DIR"
    touch "$INSTALL_STATE_DIR/$1"
}

run_stateful_step() {
    local step_id="$1" label="$2" function_name="$3" force="${4:-false}" status
    if [[ "$force" != "true" ]] && step_is_complete "$step_id"; then
        if ask_yes_no "$label was completed previously. Skip it?" y; then
            ok "Skipping $label"
            return 0
        fi
    fi

    status=0
    "$function_name" || status=$?
    if (( status == STEP_DEFERRED )); then
        warn "$label was deferred and was not marked complete"
        return 0
    fi
    (( status == 0 )) || return "$status"
    mark_step_complete "$step_id"
}

clone_latest_release() {
    local repo="$1" dest="$2" tag
    tag="$({ git ls-remote --refs --tags "$repo" 2>/dev/null || true; } \
        | awk '{sub("refs/tags/", "", $2); if ($2 ~ /^v?[0-9]+\.[0-9]+\.[0-9]+$/) print $2}' \
        | sort -V \
        | tail -n 1)"
    if [[ -n "$tag" ]]; then
        git clone --depth 1 --branch "$tag" "$repo" "$dest"
    else
        warn "Could not determine the latest release tag for $repo; using its default branch."
        git clone --depth 1 "$repo" "$dest"
    fi
}
