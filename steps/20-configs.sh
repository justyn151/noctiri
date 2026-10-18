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
    install_file "$ROOT_DIR/configs/vim/vimrc" "$HOME/.vimrc"
    render_home_template "$ROOT_DIR/configs/qt6ct/qt6ct.conf.in" "$HOME/.config/qt6ct/qt6ct.conf"
    install_file "$ROOT_DIR/configs/kde/kdeglobals" "$HOME/.config/kdeglobals"
    install_file "$ROOT_DIR/configs/portals/niri-portals.conf" "$HOME/.config/xdg-desktop-portal/niri-portals.conf"
    if [[ "$DISTRO_ID" == "fedora" ]]; then
        install_file "$ROOT_DIR/configs/systemd/kde-portal-override.conf" \
            "$HOME/.config/systemd/user/plasma-xdg-desktop-portal-kde.service.d/override.conf"
    fi

    mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"

    # Reload user systemd if this shell currently has a user manager; harmless on a TTY.
    if have systemctl; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi
}

merge_firefox_policy() {
    log "Configuring Firefox to use the XDG portal file picker"
    local policy_path
    case "$DISTRO_ID" in
        fedora) policy_path=/etc/firefox/policies/policies.json ;;
        void) policy_path=/usr/lib/firefox/distribution/policies.json ;;
        *) die "No Firefox policy path for $DISTRO_ID" ;;
    esac
    merge_firefox_policy_at_path "$policy_path"
}

merge_firefox_policy_at_path() {
    local policy_path="$1" tmp_dir input_file output_file backup_file
    tmp_dir="$(mktemp -d)"
    input_file="$tmp_dir/policies.json"
    output_file="$tmp_dir/policies.updated.json"

    if sudo test -e "$policy_path"; then
        # Redirection is performed by the normal-user shell. sudo is used only to
        # read the protected source, avoiding root-owned temporary files.
        if ! sudo cat -- "$policy_path" > "$input_file"; then
            rm -rf "$tmp_dir"
            return 1
        fi
        backup_file="$BACKUP_DIR/${policy_path#/}"
        mkdir -p "$(dirname "$backup_file")"
        if ! sudo cat -- "$policy_path" > "$backup_file"; then
            rm -rf "$tmp_dir"
            return 1
        fi
    else
        printf '{}\n' > "$input_file"
    fi

    if ! python3 - "$input_file" "$output_file" "$policy_path" <<'PY'
import json
import sys

source, destination, policy_path = sys.argv[1:]
try:
    with open(source, encoding='utf-8') as stream:
        data = json.load(stream)
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"Cannot parse existing Firefox policy {policy_path}: {error}")

if not isinstance(data, dict):
    raise SystemExit(f"Existing Firefox policy {policy_path} must contain a JSON object")
policies = data.setdefault('policies', {})
if not isinstance(policies, dict):
    raise SystemExit(f"The 'policies' value in {policy_path} must be a JSON object")
prefs = policies.setdefault('Preferences', {})
if not isinstance(prefs, dict):
    raise SystemExit(f"The 'Preferences' value in {policy_path} must be a JSON object")
prefs['widget.use-xdg-desktop-portal.file-picker']={
    'Value': 1,
    'Status': 'user',
    'Type': 'number'
}
with open(destination, 'w', encoding='utf-8') as stream:
    json.dump(data, stream, indent=2)
    stream.write('\n')
PY
    then
        rm -rf "$tmp_dir"
        return 1
    fi
    if ! sudo mkdir -p "$(dirname "$policy_path")" \
        || ! sudo install -m 0644 "$output_file" "$policy_path"; then
        rm -rf "$tmp_dir"
        return 1
    fi
    rm -rf "$tmp_dir"
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
