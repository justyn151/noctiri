#!/usr/bin/env bash
configure_user_directories() {
    log "Creating the standard XDG home folders"

    if ! have xdg-user-dirs-update; then
        case "$DISTRO_ID" in
            fedora) sudo dnf install -y xdg-user-dirs ;;
            void) sudo xbps-install -Sy xdg-user-dirs ;;
            *) die "Cannot install xdg-user-dirs on unsupported distribution: $DISTRO_ID" ;;
        esac
    fi

    xdg-user-dirs-update
    ok "Created or refreshed the standard Desktop, Documents, Downloads, Music, Pictures, Public, Templates, and Videos folders"
}

install_noctiri_doctor() {
    install_file "$ROOT_DIR/configs/bin/noctiri-doctor" \
        "$HOME/.local/bin/noctiri-doctor" 0755
    install_file "$ROOT_DIR/configs/bin/noctiri-doctor-gui" \
        "$HOME/.local/bin/noctiri-doctor-gui" 0755
    install_file "$ROOT_DIR/configs/quickshell/noctiri-doctor/shell.qml" \
        "$HOME/.config/quickshell/noctiri-doctor/shell.qml"
    install_file "$ROOT_DIR/configs/applications/noctiri-doctor.desktop" \
        "$HOME/.local/share/applications/noctiri-doctor.desktop"
    install_file "$ROOT_DIR/configs/icons/noctiri-doctor.svg" \
        "$HOME/.local/share/icons/hicolor/scalable/apps/noctiri-doctor.svg"

    if have update-desktop-database; then
        update-desktop-database "$HOME/.local/share/applications" || true
    fi
}

install_noctiri_commands() {
    local repository_record

    install_file "$ROOT_DIR/configs/bin/noctiri" \
        "$HOME/.local/bin/noctiri" 0755
    install_file "$ROOT_DIR/configs/bin/noctiri-screenshot-ocr" \
        "$HOME/.local/bin/noctiri-screenshot-ocr" 0755
    install_file "$ROOT_DIR/configs/applications/noctiri-update.desktop" \
        "$HOME/.local/share/applications/noctiri-update.desktop"
    install_file "$ROOT_DIR/configs/applications/noctiri-rollback.desktop" \
        "$HOME/.local/share/applications/noctiri-rollback.desktop"

    repository_record="$(mktemp)"
    printf '%s\n' "$ROOT_DIR" > "$repository_record"
    install_file "$repository_record" "$HOME/.config/noctiri/repository"
    rm -f "$repository_record"

    mkdir -p "$HOME/Pictures/Screenshots"
    if have update-desktop-database; then
        update-desktop-database "$HOME/.local/share/applications" || true
    fi
}

install_daily_utilities() {
    install_daily_utility_packages
    remove_unused_void_kde_portal
    if have rmpc \
        && [[ -x "$HOME/.local/bin/noctiri-mpd" ]] \
        && [[ -x "$HOME/.local/bin/noctiri-mpd-mpris" ]]; then
        configure_on_demand_music
    fi
    install_configs true
    merge_firefox_policy
    if pgrep -x noctalia >/dev/null 2>&1; then
        noctalia msg config-reload >/dev/null 2>&1 || true
    fi
    ok "Installed Noctalia daily utilities, OCR, Yazi drive controls, and KeePassXC"
}

install_configs() {
    local preserve_runtime_overrides="${1:-false}"
    log "Installing Niri, Noctalia, Kitty, Qt and portal configuration"

    install_user_path
    install_noctiri_doctor
    install_noctiri_commands
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
    install_noctalia_widget_config
    install_shortcut_window
    install_yazi_integration
    install_neovim_integration

    # GUI/runtime state overrides declarative config. Back it up and clear it so the
    # installer config is authoritative on first start.
    if [[ "$preserve_runtime_overrides" != true \
        && -f "$HOME/.local/state/noctalia/settings.toml" ]]; then
        backup_path "$HOME/.local/state/noctalia/settings.toml"
        rm -f "$HOME/.local/state/noctalia/settings.toml"
    fi

    install_file "$ROOT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
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

install_fantasque_system_font() {
    install_fantasque_nerd_font
    install_cjk_fallback_fonts
    configure_system_fonts
}

configure_system_fonts() {
    log "Making Fantasque Sans Mono the Niri desktop font"

    install_file "$ROOT_DIR/configs/fonts/fonts.conf" \
        "$HOME/.config/fontconfig/fonts.conf"
    install_file "$ROOT_DIR/configs/fonts/gtk-settings.ini" \
        "$HOME/.config/gtk-3.0/settings.ini"
    install_file "$ROOT_DIR/configs/fonts/gtk-settings.ini" \
        "$HOME/.config/gtk-4.0/settings.ini"
    render_home_template "$ROOT_DIR/configs/qt6ct/qt6ct.conf.in" \
        "$HOME/.config/qt6ct/qt6ct.conf"
    install_file "$ROOT_DIR/configs/kitty/kitty.conf" \
        "$HOME/.config/kitty/kitty.conf"

    set_kde_font_preferences
    set_noctalia_font_preference
    fc-cache -f
    if have flatpak && flatpak info com.spotify.Client >/dev/null 2>&1; then
        timeout 30 flatpak run --command=fc-cache com.spotify.Client -f >/dev/null 2>&1 \
            || warn "Spotify will refresh its CJK font cache the next time it starts."
    fi

    discover_niri_environment_for_font_reload

    if have gsettings; then
        gsettings set org.gnome.desktop.interface font-name \
            'FantasqueSansM Nerd Font 10' >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface document-font-name \
            'FantasqueSansM Nerd Font 10' >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface monospace-font-name \
            'FantasqueSansM Nerd Font Mono 10' >/dev/null 2>&1 || true
    fi

    if pgrep -x noctalia >/dev/null 2>&1; then
        noctalia msg config-reload >/dev/null 2>&1 \
            || warn "Noctalia will load Fantasque Sans Mono after the next login."
    fi

    ok "Configured Fantasque Sans Mono with Noto script fallback across the desktop"
}

discover_niri_environment_for_font_reload() {
    import_graphical_session_environment
}

set_kde_font_preferences() {
    local config_path="$HOME/.config/kdeglobals" tmp
    mkdir -p "$(dirname "$config_path")"
    [[ -f "$config_path" ]] || printf '[General]\n' > "$config_path"
    backup_path "$config_path"
    tmp="$(mktemp)"
    python3 - "$config_path" "$tmp" <<'PY'
import re
import sys

source, destination = sys.argv[1:]
text = open(source, encoding="utf-8").read()
values = {
    "font": "FantasqueSansM Nerd Font,10,-1,5,400,0,0,0,0,0",
    "fixed": "FantasqueSansM Nerd Font Mono,10,-1,5,400,0,0,0,0,0",
    "menuFont": "FantasqueSansM Nerd Font,10,-1,5,400,0,0,0,0,0",
    "smallestReadableFont": "FantasqueSansM Nerd Font,8,-1,5,400,0,0,0,0,0",
    "toolBarFont": "FantasqueSansM Nerd Font,10,-1,5,400,0,0,0,0,0",
}
section = re.search(r"(?ms)^\[General\]\n(?P<body>.*?)(?=^\[|\Z)", text)
if section is None:
    text += ("\n" if text and not text.endswith("\n") else "") + "[General]\n"
    text += "".join(f"{key}={value}\n" for key, value in values.items())
else:
    body = section.group("body")
    for key, value in values.items():
        pattern = re.compile(rf"(?m)^{re.escape(key)}=.*$")
        if pattern.search(body):
            body = pattern.sub(f"{key}={value}", body, count=1)
        else:
            body += f"{key}={value}\n"
    text = text[:section.start("body")] + body + text[section.end("body"):]
with open(destination, "w", encoding="utf-8") as stream:
    stream.write(text)
PY
    install -m 0644 "$tmp" "$config_path"
    rm -f "$tmp"
}

set_noctalia_font_preference() {
    local config_path="$HOME/.config/noctalia/config.toml" tmp
    [[ -f "$config_path" ]] || return 0
    backup_path "$config_path"
    tmp="$(mktemp)"
    python3 - "$config_path" "$tmp" <<'PY'
import re
import sys

source, destination = sys.argv[1:]
text = open(source, encoding="utf-8").read()
section = re.search(r"(?ms)^\[shell\]\n(?P<body>.*?)(?=^\[|\Z)", text)
if section is None:
    text += '\n[shell]\nfont_family = "sans-serif"\n'
else:
    body = section.group("body")
    pattern = re.compile(r"(?m)^font_family\s*=.*$")
    # Noctalia renders text with Pango. A generic family preserves Fontconfig's
    # full fallback chain: Fantasque remains first, while Noto supplies CJK.
    value = 'font_family = "sans-serif"'
    body = pattern.sub(value, body, count=1) if pattern.search(body) else body + value + "\n"
    text = text[:section.start("body")] + body + text[section.end("body"):]
with open(destination, "w", encoding="utf-8") as stream:
    stream.write(text)
PY
    install -m 0644 "$tmp" "$config_path"
    rm -f "$tmp"
}

repair_theme_sync() {
    log "Repairing Noctalia application colors and bar widgets"

    install_user_path
    local config_path="$HOME/.config/noctalia/config.toml"
    if [[ ! -f "$config_path" ]]; then
        mkdir -p "$(dirname "$config_path")"
        sed "s|@@HOME@@|$HOME|g" "$ROOT_DIR/configs/noctalia/config.toml.in" > "$config_path"
    else
        add_noctalia_builtin_template "$config_path" qt
    fi
    add_noctalia_community_template "$config_path" pywalfox

    install_noctalia_widget_config
    install_yazi_integration
    install_neovim_integration
    render_home_template "$ROOT_DIR/configs/qt6ct/qt6ct.conf.in" "$HOME/.config/qt6ct/qt6ct.conf"
    ensure_btop_theme_selected

    if pgrep -x noctalia >/dev/null 2>&1; then
        if noctalia msg config-reload >/dev/null 2>&1 \
            && noctalia msg templates-apply >/dev/null 2>&1; then
            wait_for_theme_outputs
        else
            warn "A Noctalia process exists, but its IPC endpoint is not responding."
            warn "Templates will render after the next login or color change."
        fi
    else
        warn "Noctalia is not running; templates will render after the next login or color change."
    fi

    ok "Enabled Noctalia clocks plus Qt/KDE, btop, Yazi, Neovim, and Pywalfox color synchronization"
}

install_user_path() {
    local path_config="$HOME/.config/noctiri/path.sh"
    local loader='[ -r "$HOME/.config/noctiri/path.sh" ] && . "$HOME/.config/noctiri/path.sh"'
    local startup_file

    install_file "$ROOT_DIR/configs/shell/noctiri-path.sh" "$path_config"
    for startup_file in "$HOME/.profile" "$HOME/.bashrc"; do
        add_shell_startup_line "$startup_file" "$loader"
    done
    for startup_file in \
        "$HOME/.bash_profile" "$HOME/.bash_login" \
        "$HOME/.zprofile" "$HOME/.zshrc"; do
        [[ -f "$startup_file" ]] || continue
        add_shell_startup_line "$startup_file" "$loader"
    done

    # Make user executables available to the rest of this installer run too.
    # shellcheck disable=SC1090
    . "$path_config"
}

add_shell_startup_line() {
    local startup_file="$1" line="$2"
    grep -Fqx "$line" "$startup_file" 2>/dev/null && return 0

    backup_path "$startup_file"
    mkdir -p "$(dirname "$startup_file")"
    if [[ -s "$startup_file" && -n "$(tail -c1 "$startup_file")" ]]; then
        printf '\n' >> "$startup_file"
    fi
    printf '%s\n' "$line" >> "$startup_file"
}

install_noctalia_widget_config() {
    install_file "$ROOT_DIR/configs/noctalia/widgets.toml" \
        "$HOME/.config/noctalia/20-noctiri-widgets.toml"
}

install_shortcut_window() {
    local config_dir="$HOME/.config/quickshell/noctiri-shortcuts"

    # A live QML reload can leave the IPC handler running after its native
    # window has been unmapped. Stop only this small helper before replacing
    # its files; the next key press starts a clean instance.
    import_graphical_session_environment
    if have qs; then
        qs kill -p "$config_dir" >/dev/null 2>&1 || true
    fi

    install_file "$ROOT_DIR/configs/quickshell/noctiri-shortcuts/shell.qml" \
        "$config_dir/shell.qml"
    install_file "$ROOT_DIR/configs/bin/noctiri-shortcuts" \
        "$HOME/.local/bin/noctiri-shortcuts" 0755

    # Disable the previous fixed layer-shell implementation when upgrading a
    # running desktop. Its files remain recoverable in the user's data folder.
    if pgrep -x noctalia >/dev/null 2>&1; then
        noctalia msg plugins disable noctiri/shortcuts >/dev/null 2>&1 || true
    fi
}

install_yazi_integration() {
    install_file "$ROOT_DIR/configs/yazi/yazi.toml" \
        "$HOME/.config/yazi/yazi.toml"
    install_file "$ROOT_DIR/configs/yazi/keymap.toml" \
        "$HOME/.config/yazi/keymap.toml"
    install_file "$ROOT_DIR/configs/noctalia/yazi-template.toml" \
        "$HOME/.config/noctalia/30-yazi-template.toml"
    install_file "$ROOT_DIR/configs/noctalia/templates/yazi-theme.toml" \
        "$HOME/.config/noctalia/templates/yazi-theme.toml"

    if have ya; then
        if ya pkg list 2>/dev/null | grep -Fq 'yazi-rs/plugins:mount'; then
            ya pkg upgrade >/dev/null 2>&1 \
                || warn "Yazi's mount plugin could not be refreshed; the installed copy was kept."
        else
            ya pkg add yazi-rs/plugins:mount >/dev/null 2>&1 \
                || warn "Yazi's mount plugin could not be downloaded; rerun --utilities-only when online."
        fi
    else
        warn "The Yazi package manager is unavailable; drive controls were not installed."
    fi
}

install_neovim_integration() {
    install_file "$ROOT_DIR/configs/nvim/init.lua" \
        "$HOME/.config/nvim/init.lua"
    install_file "$ROOT_DIR/configs/nvim/coc-settings.json" \
        "$HOME/.config/nvim/coc-settings.json"
    install_file "$ROOT_DIR/configs/noctalia/nvim-template.toml" \
        "$HOME/.config/noctalia/31-nvim-template.toml"
    install_file "$ROOT_DIR/configs/noctalia/templates/nvim-colors.lua" \
        "$HOME/.config/noctalia/templates/nvim-colors.lua"
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

add_noctalia_community_template() {
    local config_path="$1" template_id="$2" tmp
    tmp="$(mktemp)"
    if ! python3 - "$config_path" "$tmp" "$template_id" <<'PY'
import re
import sys

source, destination, wanted = sys.argv[1:]
text = open(source, encoding="utf-8").read()
section_pattern = re.compile(
    r'(?ms)^(?P<header>\s*\[theme\.templates\]\s*\n)'
    r'(?P<body>.*?)(?=^\s*\[|\Z)'
)
match = section_pattern.search(text)
if match is None:
    raise SystemExit(f"Could not find [theme.templates] in {source}")

body = match.group('body')
enabled_pattern = re.compile(r'(?m)^(\s*enable_community_templates\s*=\s*).*$')
if enabled_pattern.search(body):
    body = enabled_pattern.sub(r'\g<1>true', body, count=1)
else:
    body += '    enable_community_templates = true\n'

ids_pattern = re.compile(r'(?ms)^(\s*community_ids\s*=\s*)\[(.*?)\]')
ids_match = ids_pattern.search(body)
if ids_match:
    items = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', ids_match.group(2))
    if wanted not in items:
        items.append(wanted)
    replacement = ids_match.group(1) + '[ ' + ', '.join(f'"{item}"' for item in items) + ' ]'
    body = body[:ids_match.start()] + replacement + body[ids_match.end():]
else:
    body += f'    community_ids = [ "{wanted}" ]\n'

updated = text[:match.start()] + match.group('header') + body + text[match.end():]
with open(destination, 'w', encoding='utf-8') as stream:
    stream.write(updated)
PY
    then
        rm -f "$tmp"
        return 1
    fi

    if cmp -s "$config_path" "$tmp"; then
        rm -f "$tmp"
        return 0
    fi
    backup_path "$config_path"
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
        "$HOME/.config/yazi/theme.toml"
        "$HOME/.config/nvim/colors/noctalia.lua"
    )
    while (( attempts < 50 )); do
        local missing=false path
        for path in "${expected[@]}"; do
            [[ -s "$path" ]] || missing=true
        done
        [[ "$missing" == false ]] && {
            ok "Rendered btop, Qt, KDE, Yazi, and Neovim color files"
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
    log "Configuring Firefox portal integration and the managed extension set"
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
extension_settings = policies.setdefault('ExtensionSettings', {})
if not isinstance(extension_settings, dict):
    raise SystemExit(f"The 'ExtensionSettings' value in {policy_path} must be a JSON object")
managed_extensions = {
    'pywalfox@frewacom.org': 'https://addons.mozilla.org/firefox/downloads/latest/pywalfox/latest.xpi',
    'uBlock0@raymondhill.net': 'https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi',
    'sponsorBlocker@ajay.app': 'https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi',
    '{84601290-bec9-494a-b11c-1baa897a9683}': 'https://addons.mozilla.org/firefox/downloads/latest/ctrl-number-to-switch-tabs/latest.xpi',
    'keepassxc-browser@keepassxc.org': 'https://addons.mozilla.org/firefox/downloads/latest/keepassxc-browser/latest.xpi',
}
# Stop managing Vimium when upgrading a policy written by an older Noctiri
# release. Firefox can then remove it like any other normal extension.
extension_settings.pop('{d7742d87-e61d-4b78-b8a1-b469842139fa}', None)
for extension_id, install_url in managed_extensions.items():
    settings = extension_settings.setdefault(extension_id, {})
    if not isinstance(settings, dict):
        raise SystemExit(
            f"The ExtensionSettings value for {extension_id} in {policy_path} must be a JSON object"
        )
    settings.update({
        'installation_mode': 'normal_installed',
        'install_url': install_url,
    })
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

configure_pywalfox() {
    log "Installing Noctalia's Pywalfox native messaging host"
    if ! have noctalia; then
        warn "Noctalia is not available yet; Pywalfox native-host setup was deferred."
        return "$STEP_DEFERRED"
    fi
    if ! noctalia firefox-theme install; then
        warn "Noctalia could not install its Pywalfox native messaging manifest."
        warn "If a legacy Python Pywalfox host exists, remove its manifest and rerun this step."
        return "$STEP_DEFERRED"
    fi

    if pgrep -x noctalia >/dev/null 2>&1; then
        noctalia msg templates-apply >/dev/null 2>&1 || true
        noctalia firefox-theme update >/dev/null 2>&1 || true
    fi
    ok "Installed Noctalia's Pywalfox host; restart Firefox once to connect it"
}

set_default_apps() {
    log "Setting default applications"
    local images=(image/jpeg image/png image/webp image/gif image/bmp image/tiff image/svg+xml image/avif image/heif image/heic)
    local videos=(video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg)
    local audio=(audio/mpeg audio/flac audio/x-flac audio/ogg audio/opus audio/x-wav audio/wav audio/mp4)
    local mime
    for mime in "${images[@]}"; do xdg-mime default qimgv.desktop "$mime" || true; done
    for mime in "${videos[@]}"; do xdg-mime default mpv.desktop "$mime" || true; done
    for mime in "${audio[@]}"; do xdg-mime default mpv.desktop "$mime" || true; done
    set_pdf_default
}

set_pdf_default() {
    local desktop_id=sioyek.desktop
    if flatpak info com.github.ahrm.sioyek >/dev/null 2>&1; then
        desktop_id=com.github.ahrm.sioyek.desktop
    elif ! have sioyek; then
        warn "Sioyek is not installed; leaving the current PDF association unchanged"
        return 0
    fi
    xdg-mime default "$desktop_id" application/pdf || true
    ok "Set Sioyek as the default PDF viewer"
}
