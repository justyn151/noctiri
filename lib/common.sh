#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/niri-noctalia-installer-backup"
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$RUN_STAMP"

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
