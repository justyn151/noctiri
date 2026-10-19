#!/usr/bin/env bash
install_configs() {
    log "Installing Niri, Noctalia, Kitty, Qt and portal configuration"

    render_home_template "$ROOT_DIR/configs/niri/config.kdl.in" "$HOME/.config/niri/config.kdl"
    # Niri's config already includes this generated Noctalia theme fragment. Keep an empty
    # placeholder valid until Noctalia's template renderer writes the real one.
    mkdir -p "$HOME/.config/niri"
    [[ -f "$HOME/.config/niri/noctalia.kdl" ]] || : > "$HOME/.config/niri/noctalia.kdl"
    [[ -f "$HOME/.config/niri/noctiri-hardware.kdl" ]] || : > "$HOME/.config/niri/noctiri-hardware.kdl"
    configure_niri_gpu_override

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
    ensure_btop_theme_selected
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

repair_theme_sync() {
    log "Repairing Noctalia application color synchronization"

    local config_path="$HOME/.config/noctalia/config.toml"
    if [[ ! -f "$config_path" ]]; then
        mkdir -p "$(dirname "$config_path")"
        sed "s|@@HOME@@|$HOME|g" "$ROOT_DIR/configs/noctalia/config.toml.in" > "$config_path"
    else
        add_noctalia_builtin_template "$config_path" qt
    fi

    render_home_template "$ROOT_DIR/configs/qt6ct/qt6ct.conf.in" "$HOME/.config/qt6ct/qt6ct.conf"
    ensure_btop_theme_selected

    if pgrep -x noctalia >/dev/null 2>&1; then
        noctalia msg config-reload >/dev/null
        noctalia msg templates-apply >/dev/null
        wait_for_theme_outputs
    else
        warn "Noctalia is not running; templates will render after the next login or color change."
    fi

    ok "Enabled Noctalia Qt/KDE and btop color synchronization"
}

add_noctalia_builtin_template() {
    local config_path="$1" template_id="$2" tmp
    if python3 - "$config_path" "$template_id" <<'PY'
import re
import sys

path, wanted = sys.argv[1:]
text = open(path, encoding="utf-8").read()
pattern = re.compile(r'(?ms)^(\s*builtin_ids\s*=\s*)\[(.*?)\]')
match = pattern.search(text)
if match is None:
    raise SystemExit(2)
items = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', match.group(2))
raise SystemExit(0 if wanted in items else 1)
PY
    then
        return 0
    else
        local status=$?
        (( status == 1 )) || die "Could not find theme.templates.builtin_ids in $config_path"
    fi

    backup_path "$config_path"
    tmp="$(mktemp)"
    python3 - "$config_path" "$tmp" "$template_id" <<'PY'
import re
import sys

source, destination, wanted = sys.argv[1:]
text = open(source, encoding="utf-8").read()
pattern = re.compile(r'(?ms)^(\s*builtin_ids\s*=\s*)\[(.*?)\]')
match = pattern.search(text)
if match is None:
    raise SystemExit(f"Could not find theme.templates.builtin_ids in {source}")
items = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', match.group(2))
if wanted not in items:
    items.append(wanted)
replacement = match.group(1) + "[ " + ", ".join(f'\"{item}\"' for item in items) + " ]"
text = text[:match.start()] + replacement + text[match.end():]
with open(destination, "w", encoding="utf-8") as stream:
    stream.write(text)
PY
    install -m 0644 "$tmp" "$config_path"
    rm -f "$tmp"
}

ensure_btop_theme_selected() {
    local config_path="$HOME/.config/btop/btop.conf" tmp
    mkdir -p "$(dirname "$config_path")"
    if [[ ! -f "$config_path" ]]; then
        printf 'color_theme = "noctalia"\n' > "$config_path"
        return 0
    fi
    if grep -qE '^color_theme[[:space:]]*=[[:space:]]*"noctalia"' "$config_path"; then
        return 0
    fi

    backup_path "$config_path"
    tmp="$(mktemp)"
    if grep -qE '^color_theme[[:space:]]*=' "$config_path"; then
        sed -E 's/^color_theme[[:space:]]*=.*/color_theme = "noctalia"/' "$config_path" > "$tmp"
    else
        cp "$config_path" "$tmp"
        [[ ! -s "$tmp" || -z "$(tail -c1 "$tmp")" ]] || printf '\n' >> "$tmp"
        printf 'color_theme = "noctalia"\n' >> "$tmp"
    fi
    install -m 0644 "$tmp" "$config_path"
    rm -f "$tmp"
}

wait_for_theme_outputs() {
    local attempts=0
    local expected=(
        "$HOME/.config/btop/themes/noctalia.theme"
        "$HOME/.config/qt6ct/colors/noctalia.conf"
        "$HOME/.local/share/color-schemes/noctalia.colors"
    )
    while (( attempts < 50 )); do
        local missing=false path
        for path in "${expected[@]}"; do
            [[ -s "$path" ]] || missing=true
        done
        [[ "$missing" == false ]] && {
            ok "Rendered btop, Qt, and KDE color files"
            return 0
        }
        sleep 0.1
        ((attempts += 1))
    done
    warn "Noctalia accepted the refresh, but one or more theme files were not rendered yet."
    warn "Run 'noctalia msg templates-apply' once Noctalia has fully started."
}

configure_niri_gpu_override() {
    [[ "$DISTRO_ID" == "void" ]] || return 0

    local render_path device driver_path driver
    local intel_render="" nouveau_render=""
    for render_path in /dev/dri/by-path/pci-*-render; do
        [[ -L "$render_path" ]] || continue
        device="${render_path##*/pci-}"
        device="${device%-render}"
        driver_path="/sys/bus/pci/devices/$device/driver"
        [[ -L "$driver_path" ]] || continue
        driver="$(basename "$(readlink -f "$driver_path")")"
        case "$driver" in
            i915) intel_render="$render_path" ;;
            nouveau) nouveau_render="$render_path" ;;
        esac
    done

    [[ -n "$intel_render" && -n "$nouveau_render" ]] || return 0

    local config_path="$HOME/.config/niri/config.kdl"
    local hardware_path="$HOME/.config/niri/noctiri-hardware.kdl"
    local tmp
    mkdir -p "$(dirname "$hardware_path")"

    if [[ ! -f "$config_path" ]]; then
        warn "Cannot install the Niri hybrid-GPU override because $config_path is missing"
        return 0
    fi
    if ! grep -Fxq 'include "noctiri-hardware.kdl"' "$config_path"; then
        backup_path "$config_path"
        printf '\ninclude "noctiri-hardware.kdl"\n' >> "$config_path"
    fi

    tmp="$(mktemp)"
    printf '%s\n' \
        '// Generated by Noctiri for an Intel + nouveau hybrid laptop.' \
        '// The nouveau render node can hang Niri during compositor initialization.' \
        'debug {' \
        "    render-drm-device \"$intel_render\"" \
        "    ignore-drm-device \"$nouveau_render\"" \
        '}' > "$tmp"
    install_file "$tmp" "$hardware_path"
    rm -f "$tmp"
    ok "Pinned Niri to Intel graphics and ignored the nouveau render device"
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
