#!/usr/bin/env bash
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

clone_wall_repo() {
    local url="$1" dir="$2"
    local dest="$WALLPAPER_DIR/$dir"
    if [[ -d "$dest/.git" ]]; then
        log "Updating wallpaper repo: $dir"
        git -C "$dest" pull --ff-only || warn "Could not update $dir; keeping existing files."
    elif [[ -e "$dest" ]]; then
        warn "$dest already exists but is not a Git checkout; skipping it."
    else
        log "Cloning wallpaper repo: $dir"
        git clone --depth 1 "$url" "$dest"
    fi
}

configure_wallpapers() {
    mkdir -p "$WALLPAPER_DIR"
    printf '\nWallpaper collections are optional.\n'
    printf '  1) sewergweller/walls\n'
    printf '  2) AbegAshford/rice-walls\n'
    printf '  3) na-ive/wallpapers\n'
    printf '  4) makccr/wallpapers\n'
    printf '  a) all four\n'
    printf '  s) skip wallpapers\n\n'
    read -r -p 'Select any combination (example: 1 3 4), or s to skip: ' choices || true
    choices="${choices:-s}"

    rm -f "$HOME/.config/noctalia/99-wallpaper.toml"
    [[ "$choices" != "s" && "$choices" != "S" ]] || { ok "Skipping wallpaper downloads"; return; }

    local nums=()
    if [[ "$choices" =~ ^[Aa]$ ]]; then
        nums=(1 2 3 4)
    else
        read -r -a nums <<< "$choices"
    fi

    local picked=0 n
    for n in "${nums[@]}"; do
        case "$n" in
            1) clone_wall_repo https://github.com/sewergweller/walls.git sewer-walls; picked=1 ;;
            2) clone_wall_repo https://github.com/AbegAshford/rice-walls.git rice-walls; picked=1 ;;
            3) clone_wall_repo https://github.com/na-ive/wallpapers.git na-ive; picked=1 ;;
            4) clone_wall_repo https://github.com/makccr/wallpapers.git makccr; picked=1 ;;
            *) warn "Ignoring unknown wallpaper choice: $n" ;;
        esac
    done
    (( picked == 1 )) || { warn "No valid wallpaper repositories selected."; return; }

    local initial=""
    if [[ -f "$WALLPAPER_DIR/na-ive/1351102.jpg" ]]; then
        initial="$WALLPAPER_DIR/na-ive/1351102.jpg"
    else
        initial="$(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print | sort | head -n 1 || true)"
    fi

    if [[ -n "$initial" ]] && ask_yes_no "Use an installed wallpaper as the initial Noctalia background?" y; then
        cat > "$HOME/.config/noctalia/99-wallpaper.toml" <<EOF2
[theme]
source = "wallpaper"

[wallpaper.default]
path = "$initial"

[wallpaper.last]
path = "$initial"
EOF2
        ok "Initial wallpaper: $initial"
    else
        ok "Wallpapers installed; Noctalia will stay on its built-in palette until you choose one."
    fi
}
