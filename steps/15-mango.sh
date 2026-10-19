#!/usr/bin/env bash

install_packages_mango_void() {
    log "Updating Void Linux and installing the Tatami/Mango desktop"
    sudo xbps-install -Suy

    local pkgs=(
        mangowc Waybar fuzzel SwayNotificationCenter awww
        grim slurp swappy yazi swaylock swayidle wl-clipboard cliphist
        greetd dbus elogind seatd accountsservice mesa-dri xorg-server-xwayland
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal-kde
        NetworkManager bluez rfkill upower
        pipewire wireplumber libspa-bluetooth alsa-pipewire alsa-utils pulseaudio-utils
        polkit polkit-gnome gnome-keyring
        kitty firefox vim ripgrep texlive-latexmk flatpak git curl tar xz unzip python3 xdg-utils
        playerctl brightnessctl
        qt6ct breeze-qt6 breeze-icons
        dolphin ark fooyin btop cava fastfetch qimgv mpv
        zathura zathura-pdf-mupdf qpwgraph
        font-inter
    )
    sudo xbps-install -y "${pkgs[@]}"

    if ! have noctalia-greeter; then
        install_noctalia_greeter_void
    else
        ok "Noctalia Greeter is already installed"
    fi
    install_bibata_cursor_void
    configure_void_runtime
}

install_iosevka_font() {
    log "Installing IosevkaTerm Nerd Font for Tatami"
    local font_dir="$HOME/.local/share/fonts/IosevkaTermNerd"
    if fc-list : family 2>/dev/null | grep -qi 'IosevkaTerm Nerd Font'; then
        ok "IosevkaTerm Nerd Font already installed"
        return
    fi

    mkdir -p "$font_dir"
    local tmp
    tmp="$(mktemp -d)"
    curl -fL --retry 3 -o "$tmp/IosevkaTerm.tar.xz" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IosevkaTerm.tar.xz
    tar -xf "$tmp/IosevkaTerm.tar.xz" -C "$font_dir"
    rm -rf "$tmp"
    fc-cache -f
}

install_void_mango_session() {
    sudo install -Dm0755 "$ROOT_DIR/configs/mango/noctiri-mango-session" \
        /usr/local/bin/noctiri-mango-session
    sudo install -Dm0644 "$ROOT_DIR/configs/mango/noctiri-tatami.desktop" \
        /usr/share/wayland-sessions/noctiri-tatami.desktop
    ok "Installed the Void seatd-backed Noctiri Tatami session"
}

install_mango_configs() {
    log "Installing the Tatami Mango, Waybar, SwayNC, Fuzzel, Kitty and portal configuration"

    install_file "$ROOT_DIR/configs/mango/config.conf" "$HOME/.config/mango/config.conf"
    install_file "$ROOT_DIR/configs/mango/bindings.conf" "$HOME/.config/mango/bindings.conf"
    install_file "$ROOT_DIR/configs/mango/rules.conf" "$HOME/.config/mango/rules.conf"
    install_file "$ROOT_DIR/configs/mango/autostart.sh" "$HOME/.config/mango/autostart.sh" 0755
    install_file "$ROOT_DIR/configs/mango/kitty.conf" "$HOME/.config/mango/kitty.conf"
    install_file "$ROOT_DIR/configs/mango/themes/day.conf" "$HOME/.config/mango/themes/day.conf"
    install_file "$ROOT_DIR/configs/mango/themes/night.conf" "$HOME/.config/mango/themes/night.conf"
    install_file "$ROOT_DIR/configs/mango/kitty-themes/day.conf" "$HOME/.config/mango/kitty-themes/day.conf"
    install_file "$ROOT_DIR/configs/mango/kitty-themes/night.conf" "$HOME/.config/mango/kitty-themes/night.conf"
    render_home_template "$ROOT_DIR/configs/mango/qt6ct.conf.in" "$HOME/.config/qt6ct/qt6ct.conf"
    install_file "$ROOT_DIR/configs/mango/qt6ct-palettes/day.conf" \
        "$HOME/.config/qt6ct/colors/tatami-day.conf"
    install_file "$ROOT_DIR/configs/mango/qt6ct-palettes/night.conf" \
        "$HOME/.config/qt6ct/colors/tatami-night.conf"
    install_file "$ROOT_DIR/configs/mango/btop-themes/day.theme" \
        "$HOME/.config/btop/themes/tatami-day.theme"
    install_file "$ROOT_DIR/configs/mango/btop-themes/night.theme" \
        "$HOME/.config/btop/themes/tatami-night.theme"
    configure_tatami_btop
    install_file "$ROOT_DIR/configs/vim/vimrc" "$HOME/.vimrc"

    install_file "$ROOT_DIR/configs/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
    install_file "$ROOT_DIR/configs/waybar/style.css" "$HOME/.config/waybar/style.css"
    install_file "$ROOT_DIR/configs/waybar/themes/day.css" "$HOME/.config/waybar/themes/day.css"
    install_file "$ROOT_DIR/configs/waybar/themes/night.css" "$HOME/.config/waybar/themes/night.css"

    install_file "$ROOT_DIR/configs/swaync/config.json" "$HOME/.config/swaync/config.json"
    install_file "$ROOT_DIR/configs/swaync/style.css" "$HOME/.config/swaync/style.css"
    install_file "$ROOT_DIR/configs/fuzzel/themes/day.ini" "$HOME/.config/fuzzel/themes/day.ini"
    install_file "$ROOT_DIR/configs/fuzzel/themes/night.ini" "$HOME/.config/fuzzel/themes/night.ini"
    install_file "$ROOT_DIR/configs/portals/mango-portals.conf" \
        "$HOME/.config/xdg-desktop-portal/mango-portals.conf"

    install_file "$ROOT_DIR/configs/mango/scripts/noctiri-theme" \
        "$HOME/.local/bin/noctiri-theme" 0755
    install_file "$ROOT_DIR/configs/mango/scripts/noctiri-wallpaper" \
        "$HOME/.local/bin/noctiri-wallpaper" 0755

    mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"
    configure_mango_gpu_override

    backup_path "$HOME/.config/mango/theme.conf"
    backup_path "$HOME/.config/mango/kitty-theme.conf"
    backup_path "$HOME/.config/waybar/colors.css"
    backup_path "$HOME/.config/fuzzel/fuzzel.ini"
    backup_path "$HOME/.config/qt6ct/colors/tatami.conf"
    backup_path "$HOME/.config/btop/themes/tatami.theme"
    rm -f \
        "$HOME/.config/mango/theme.conf" \
        "$HOME/.config/mango/kitty-theme.conf" \
        "$HOME/.config/waybar/colors.css" \
        "$HOME/.config/fuzzel/fuzzel.ini" \
        "$HOME/.config/qt6ct/colors/tatami.conf" \
        "$HOME/.config/btop/themes/tatami.theme"
    "$HOME/.local/bin/noctiri-theme" "${TATAMI_THEME:-night}" --no-reload

    if ! mango -c "$HOME/.config/mango/config.conf" -p; then
        die "Mango rejected $HOME/.config/mango/config.conf"
    fi
    ok "Installed the Tatami/Mango desktop configuration"
}

configure_tatami_btop() {
    local config_path="$HOME/.config/btop/btop.conf" tmp
    mkdir -p "$(dirname "$config_path")"
    if [[ ! -f "$config_path" ]]; then
        printf 'color_theme = "tatami"\n' > "$config_path"
        return
    fi

    backup_path "$config_path"
    tmp="$(mktemp)"
    if grep -qE '^color_theme[[:space:]]*=' "$config_path"; then
        sed -E 's/^color_theme[[:space:]]*=.*/color_theme = "tatami"/' "$config_path" > "$tmp"
    else
        cp "$config_path" "$tmp"
        [[ ! -s "$tmp" || -z "$(tail -c1 "$tmp")" ]] || printf '\n' >> "$tmp"
        printf 'color_theme = "tatami"\n' >> "$tmp"
    fi
    install -m 0644 "$tmp" "$config_path"
    rm -f "$tmp"
}

configure_mango_gpu_override() {
    [[ "$DISTRO_ID" == "void" ]] || return 0

    local card_path device driver_path driver intel_card="" nouveau_card=""
    for card_path in /dev/dri/by-path/pci-*-card; do
        [[ -L "$card_path" ]] || continue
        device="${card_path##*/pci-}"
        device="${device%-card}"
        driver_path="/sys/bus/pci/devices/$device/driver"
        [[ -L "$driver_path" ]] || continue
        driver="$(basename "$(readlink -f "$driver_path")")"
        case "$driver" in
            # WLR_DRM_DEVICES uses ':' as its list separator, so the PCI
            # by-path name itself cannot be exported. Resolve it to cardN.
            i915) intel_card="$(readlink -f "$card_path")" ;;
            nouveau) nouveau_card="$(readlink -f "$card_path")" ;;
        esac
    done

    local hardware_path="$HOME/.config/mango/noctiri-hardware.env" tmp
    if [[ -n "$intel_card" && -n "$nouveau_card" ]]; then
        tmp="$(mktemp)"
        printf "export WLR_DRM_DEVICES='%s'\n" "$intel_card" > "$tmp"
        install_file "$tmp" "$hardware_path" 0600
        rm -f "$tmp"
        ok "Pinned Mango to Intel graphics and excluded the nouveau render device"
    elif [[ -e "$hardware_path" || -L "$hardware_path" ]]; then
        backup_path "$hardware_path"
        rm -f "$hardware_path"
    fi
}

install_mango_flavour() {
    install_packages_mango_void
    repair_connectivity_audio
    install_iosevka_font
    install_mango_configs
    merge_firefox_policy
    set_default_apps
    configure_greeter
}
