#!/usr/bin/env bash
install_configs() {
    log "Installing Niri, Noctalia, Kitty, Qt and portal configuration"

    render_home_template "$ROOT_DIR/configs/niri/config.kdl.in" "$HOME/.config/niri/config.kdl"
    # Niri's config already includes this generated Noctalia theme fragment. Keep an empty
    # placeholder valid until Noctalia's template renderer writes the real one.
    mkdir -p "$HOME/.config/niri"
    [[ -f "$HOME/.config/niri/noctalia.kdl" ]] || : > "$HOME/.config/niri/noctalia.kdl"

    mkdir -p "$HOME/.config/noctalia"
    backup_path "$HOME/.config/noctalia/config.toml"
    sed "s|@@HOME@@|$HOME|g" "$ROOT_DIR/configs/noctalia/config.toml.in" > "$HOME/.config/noctalia/config.toml"

    # GUI/runtime state overrides declarative config. Back it up and clear it so the
    # installer config is authoritative on first start.
    if [[ -f "$HOME/.local/state/noctalia/settings.toml" ]]; then
        backup_path "$HOME/.local/state/noctalia/settings.toml"
        rm -f "$HOME/.local/state/noctalia/settings.toml"
    fi

    install_file "$ROOT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    render_home_template "$ROOT_DIR/configs/qt6ct/qt6ct.conf.in" "$HOME/.config/qt6ct/qt6ct.conf"
    install_file "$ROOT_DIR/configs/kde/kdeglobals" "$HOME/.config/kdeglobals"
    install_file "$ROOT_DIR/configs/portals/niri-portals.conf" "$HOME/.config/xdg-desktop-portal/niri-portals.conf"
    install_file "$ROOT_DIR/configs/systemd/kde-portal-override.conf" \
        "$HOME/.config/systemd/user/plasma-xdg-desktop-portal-kde.service.d/override.conf"

    mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"

    # Reload user systemd if this shell currently has a user manager; harmless on a TTY.
    systemctl --user daemon-reload >/dev/null 2>&1 || true
}

merge_firefox_policy() {
    log "Configuring Firefox to use the XDG portal file picker"
    local tmp
    tmp="$(mktemp)"
    sudo python3 - "$tmp" <<'PY'
import json, os, sys
path='/etc/firefox/policies/policies.json'
out=sys.argv[1]
data={}
if os.path.exists(path):
    try:
        with open(path, encoding='utf-8') as f: data=json.load(f)
    except Exception:
        data={}
policies=data.setdefault('policies', {})
prefs=policies.setdefault('Preferences', {})
prefs['widget.use-xdg-desktop-portal.file-picker']={
    'Value': 1,
    'Status': 'user',
    'Type': 'number'
}
with open(out,'w',encoding='utf-8') as f:
    json.dump(data,f,indent=2)
    f.write('\n')
PY
    if sudo test -e /etc/firefox/policies/policies.json; then
        sudo mkdir -p "$BACKUP_DIR/etc/firefox/policies"
        sudo cp -a /etc/firefox/policies/policies.json "$BACKUP_DIR/etc/firefox/policies/policies.json"
    fi
    sudo mkdir -p /etc/firefox/policies
    sudo install -m 0644 "$tmp" /etc/firefox/policies/policies.json
    rm -f "$tmp"
}

set_default_apps() {
    log "Setting default applications"
    local images=(image/jpeg image/png image/webp image/gif image/bmp image/tiff image/svg+xml image/avif image/heif image/heic)
    local videos=(video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg)
    local audio=(audio/mpeg audio/flac audio/x-flac audio/ogg audio/opus audio/x-wav audio/wav audio/mp4)
    local mime
    for mime in "${images[@]}"; do xdg-mime default qimgv.desktop "$mime" || true; done
    for mime in "${videos[@]}"; do xdg-mime default mpv.desktop "$mime" || true; done
    for mime in "${audio[@]}"; do xdg-mime default org.fooyin.fooyin.desktop "$mime" || true; done
    xdg-mime default org.pwmt.zathura.desktop application/pdf || true
}
