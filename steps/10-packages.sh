#!/usr/bin/env bash
install_packages() {
    case "$DISTRO_ID" in
        fedora) install_packages_fedora ;;
        void) install_packages_void ;;
        *) die "No package installation implementation for $DISTRO_ID" ;;
    esac
}

install_packages_fedora() {
    log "Installing Fedora packages"
    sudo dnf install -y dnf5-plugins

    local pkgs=(
        niri noctalia greetd greetd-selinux
        xwayland-satellite
        xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-desktop-portal-kde
        NetworkManager bluez bluez-tools upower
        pipewire pipewire-alsa pipewire-pulseaudio wireplumber alsa-utils
        polkit gnome-keyring gnome-keyring-pam
        kitty firefox vim-enhanced ripgrep latexmk flatpak git curl tar xz unzip python3 xdg-utils
        playerctl brightnessctl
        qt6ct plasma-breeze-qt6 breeze-icon-theme
        dolphin ark fooyin btop cava fastfetch qimgv mpv
        zathura zathura-pdf-mupdf qpwgraph
        rsms-inter-fonts
    )
    sudo dnf install -y "${pkgs[@]}"

    log "Installing Bibata cursor theme"
    if sudo dnf copr list --enabled 2>/dev/null | grep -q 'peterwu/rendezvous'; then
        ok "Bibata COPR already enabled"
    else
        sudo dnf copr enable -y peterwu/rendezvous
    fi
    sudo dnf install -y bibata-cursor-themes

    log "Installing Noctalia Greeter from Terra"
    if ! rpm -q terra-release >/dev/null 2>&1; then
        sudo dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
    fi
    sudo dnf install -y noctalia-greeter
}

install_packages_void() {
    log "Updating Void Linux and installing desktop packages"
    # Void does not support partial upgrades, so update the installed system before
    # resolving this installer's package set.
    sudo xbps-install -Suy

    local pkgs=(
        niri greetd dbus elogind seatd accountsservice mesa-dri
        xwayland-satellite
        xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-desktop-portal-kde
        NetworkManager bluez rfkill upower
        pipewire wireplumber libspa-bluetooth alsa-pipewire alsa-utils pulseaudio-utils
        polkit gnome-keyring
        kitty firefox vim ripgrep texlive-latexmk flatpak git curl tar xz unzip python3 xdg-utils
        playerctl brightnessctl
        qt6ct breeze-qt6 breeze-icons
        dolphin ark fooyin btop cava fastfetch qimgv mpv
        zathura zathura-pdf-mupdf qpwgraph
        font-inter
    )
    sudo xbps-install -y "${pkgs[@]}"

    install_noctalia_void
    install_noctalia_greeter_void
    install_bibata_cursor_void
    configure_void_runtime
}

configure_void_runtime() {
    log "Configuring Void system D-Bus and seat management"
    if [[ ! -e /var/service/dbus && ! -L /var/service/dbus ]]; then
        sudo ln -s /etc/sv/dbus /var/service/
        ok "Enabled the dbus runit service"
    fi

    repair_duplicate_void_elogind_service

    # Keep elogind for PAM/XDG_RUNTIME_DIR, but let libseat use seatd for DRM
    # and input access. This avoids elogind seat acquisition stalls seen with
    # greetd on some Void hybrid-GPU systems. libseat prefers seatd when its
    # socket is available.
    if ! id -nG "$USER" | tr ' ' '\n' | grep -Fxq _seatd; then
        sudo usermod -aG _seatd "$USER"
        ok "Added $USER to the _seatd group"
    fi
    if id "$GREETER_USER" >/dev/null 2>&1 \
        && ! id -nG "$GREETER_USER" | tr ' ' '\n' | grep -Fxq _seatd; then
        sudo usermod -aG _seatd "$GREETER_USER"
        ok "Added $GREETER_USER to the _seatd group"
    fi
    if [[ ! -e /var/service/seatd && ! -L /var/service/seatd ]]; then
        sudo ln -s /etc/sv/seatd /var/service/
        ok "Enabled the seatd runit service"
    fi
    install_void_niri_session
}

configure_connectivity_audio() {
    case "$DISTRO_ID" in
        fedora) configure_fedora_connectivity_audio ;;
        void) configure_void_connectivity_audio ;;
        *) die "No connectivity/audio configuration for $DISTRO_ID" ;;
    esac
}

repair_connectivity_audio() {
    log "Installing and repairing Wi-Fi, Bluetooth, and PipeWire"
    case "$DISTRO_ID" in
        fedora)
            sudo dnf install -y NetworkManager bluez bluez-tools upower \
                pipewire pipewire-alsa pipewire-pulseaudio wireplumber alsa-utils
            ;;
        void)
            sudo xbps-install -Sy NetworkManager bluez rfkill upower \
                pipewire wireplumber libspa-bluetooth alsa-pipewire alsa-utils pulseaudio-utils
            ;;
    esac
    configure_connectivity_audio
}

configure_fedora_connectivity_audio() {
    log "Configuring Fedora Wi-Fi, Bluetooth, and PipeWire"
    sudo systemctl enable --now NetworkManager.service bluetooth.service

    if systemctl --user show-environment >/dev/null 2>&1; then
        systemctl --user enable --now pipewire.socket pipewire-pulse.socket >/dev/null 2>&1 \
            || warn "Could not enable the PipeWire user sockets; Fedora's package presets may manage them instead."
        systemctl --user start wireplumber.service >/dev/null 2>&1 \
            || warn "WirePlumber will start with the next graphical login."
    else
        warn "No user service manager is available in this shell; PipeWire will start at graphical login."
    fi
    verify_connectivity_audio
}

configure_void_connectivity_audio() {
    log "Configuring Void Wi-Fi, Bluetooth, and PipeWire"
    enable_void_service dbus
    configure_void_networkmanager
    enable_void_service bluetoothd

    add_user_to_group_if_present network
    add_user_to_group_if_present bluetooth
    add_user_to_group_if_present audio
    add_user_to_group_if_present video

    configure_void_pipewire
    verify_connectivity_audio
}

enable_void_service() {
    local service="$1"
    [[ -d "/etc/sv/$service" ]] || {
        warn "Void service /etc/sv/$service is unavailable"
        return 1
    }
    if [[ ! -e "/var/service/$service" && ! -L "/var/service/$service" ]]; then
        sudo ln -s "/etc/sv/$service" /var/service/
        ok "Enabled the $service runit service"
    fi
}

add_user_to_group_if_present() {
    local group="$1"
    getent group "$group" >/dev/null 2>&1 || return 0
    if ! id -nG "$USER" | tr ' ' '\n' | grep -Fxq "$group"; then
        sudo usermod -aG "$group" "$USER"
        ok "Added $USER to the $group group (takes effect at next login)"
    fi
}

configure_void_networkmanager() {
    local conflicts=() service
    for service in dhcpcd wpa_supplicant wicd connmand; do
        if [[ -e "/var/service/$service" || -L "/var/service/$service" ]]; then
            conflicts+=("$service")
        fi
    done

    if (( ${#conflicts[@]} > 0 )); then
        warn "NetworkManager conflicts with enabled service(s): ${conflicts[*]}"
        if ask_yes_no "Switch networking to NetworkManager now? This may briefly disconnect the network." n; then
            for service in "${conflicts[@]}"; do
                sudo sv down "$service" >/dev/null 2>&1 || true
                sudo unlink "/var/service/$service"
                ok "Disabled the conflicting $service service"
            done
        else
            warn "NetworkManager was not enabled; Noctalia's Wi-Fi widget will remain unavailable."
            return 0
        fi
    fi
    enable_void_service NetworkManager
}

configure_void_pipewire() {
    local pipewire_dir="$HOME/.config/pipewire/pipewire.conf.d"
    mkdir -p "$pipewire_dir" "$HOME/.config/autostart"
    ensure_user_symlink /usr/share/examples/wireplumber/10-wireplumber.conf \
        "$pipewire_dir/10-wireplumber.conf"
    ensure_user_symlink /usr/share/examples/pipewire/20-pipewire-pulse.conf \
        "$pipewire_dir/20-pipewire-pulse.conf"

    if [[ -e /usr/share/applications/pipewire.desktop ]]; then
        ensure_user_symlink /usr/share/applications/pipewire.desktop \
            "$HOME/.config/autostart/pipewire.desktop"
    else
        warn "PipeWire's XDG autostart entry is missing; audio cannot be started automatically."
    fi

    ensure_system_symlink /usr/share/alsa/alsa.conf.d/50-pipewire.conf \
        /etc/alsa/conf.d/50-pipewire.conf
    ensure_system_symlink /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf \
        /etc/alsa/conf.d/99-pipewire-default.conf

    if [[ -n "${XDG_RUNTIME_DIR:-}" && -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] \
        && ! pgrep -u "$(id -u)" -x pipewire >/dev/null 2>&1; then
        mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/noctiri"
        nohup pipewire > "${XDG_STATE_HOME:-$HOME/.local/state}/noctiri/pipewire.log" 2>&1 </dev/null &
        sleep 1
    elif pgrep -u "$(id -u)" -x pipewire >/dev/null 2>&1; then
        warn "PipeWire is already running; log out and back in once to load the repaired configuration."
    else
        warn "PipeWire will start automatically with the next Niri login."
    fi
}

ensure_user_symlink() {
    local source="$1" destination="$2"
    [[ -e "$source" ]] || die "Required file is missing: $source"
    if [[ -L "$destination" \
        && "$(readlink -f "$destination")" == "$(readlink -f "$source")" ]]; then
        return 0
    fi
    if [[ -e "$destination" || -L "$destination" ]]; then
        [[ ! -d "$destination" ]] || die "Cannot replace directory $destination with a symlink"
        backup_path "$destination"
        unlink "$destination"
    fi
    ln -s "$source" "$destination"
}

ensure_system_symlink() {
    local source="$1" destination="$2"
    [[ -e "$source" ]] || die "Required file is missing: $source"
    sudo mkdir -p "$(dirname "$destination")"
    if sudo test -L "$destination" \
        && [[ "$(sudo readlink -f "$destination")" == "$(readlink -f "$source")" ]]; then
        return 0
    fi
    if sudo test -e "$destination" || sudo test -L "$destination"; then
        warn "Keeping existing $destination; verify that it enables PipeWire if ALSA applications have no audio."
        return 0
    fi
    sudo ln -s "$source" "$destination"
}

verify_connectivity_audio() {
    if have nmcli && nmcli general status >/dev/null 2>&1; then
        ok "NetworkManager is responding"
    else
        warn "NetworkManager is not responding yet"
    fi
    if have bluetoothctl && bluetoothctl list >/dev/null 2>&1; then
        ok "BlueZ is responding"
    else
        warn "BlueZ is not responding yet (the adapter may also be disabled or absent)"
    fi
    if have wpctl && wpctl status >/dev/null 2>&1; then
        ok "PipeWire and WirePlumber are responding"
    else
        warn "PipeWire/WirePlumber is not responding yet; log out and back in, then run: wpctl status"
    fi
    if have pactl && pactl info >/dev/null 2>&1; then
        ok "PipeWire's PulseAudio compatibility server is responding"
    else
        warn "PipeWire's PulseAudio compatibility server is not responding yet"
    fi
}

install_void_niri_session() {
    sudo install -Dm0755 "$ROOT_DIR/configs/niri/noctiri-niri-session" \
        /usr/local/bin/noctiri-niri-session
    sudo install -Dm0644 "$ROOT_DIR/configs/niri/noctiri.desktop" \
        /usr/share/wayland-sessions/noctiri.desktop
    ok "Installed the Void seatd-backed Noctiri session"
}

repair_duplicate_void_elogind_service() {
    local status
    [[ -L /var/service/elogind ]] || return 0
    [[ "$(readlink -f /var/service/elogind)" == /etc/sv/elogind ]] || return 0

    status="$(sudo sv status /var/service/elogind 2>&1 || true)"
    if [[ "$status" == down:* ]] && pgrep -x elogind >/dev/null 2>&1; then
        # Void normally starts elogind through the enabled system D-Bus. If an
        # elogind process already exists while its runit service stays down,
        # runit will endlessly retry a second instance and log "already running".
        sudo sv down /var/service/elogind || true
        sudo unlink /var/service/elogind
        ok "Removed the redundant elogind runit service; D-Bus activation is already running elogind"
    fi
}

repair_void_runtime() {
    log "Installing the Void Wayland graphics and seat runtime"
    sudo xbps-install -y mesa-dri dbus elogind seatd
    configure_void_runtime
    repair_connectivity_audio
    configure_niri_gpu_override
    configure_greeter
}

install_nlohmann_json_void() {
    # Meson installs the generated pkg-config file here. Exporting the path makes
    # the source install discoverable even when Void's pkgconf excludes /usr/local.
    local local_pkgconfig=/usr/local/lib/pkgconfig
    export PKG_CONFIG_PATH="$local_pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

    if pkg-config --exists nlohmann_json; then
        ok "nlohmann-json is already installed"
        return 0
    fi

    log "Installing nlohmann-json from its latest stable release"
    local tmp src
    tmp="$(mktemp -d)"
    src="$tmp/nlohmann-json"
    clone_latest_release https://github.com/nlohmann/json.git "$src"
    (
        cd "$src"
        meson setup build-release --prefix=/usr/local --libdir=lib --buildtype=release
        sudo meson install -C build-release
    )
    rm -rf "$tmp"

    pkg-config --exists nlohmann_json \
        || die "nlohmann-json installed, but pkg-config cannot find it"
    ok "nlohmann-json installed"
}

install_noctalia_void() {
    log "Installing Noctalia build dependencies for Void Linux"
    local build_pkgs=(
        base-devel meson ninja pkg-config just
        wayland-devel wayland-protocols libepoxy-devel MesaLib-devel libglvnd-devel
        cairo-devel pango-devel fontconfig-devel freetype-devel harfbuzz-devel
        libxkbcommon-devel libglib-devel libsecret-devel libsodium-devel
        basu-devel 'sdbus-c++-devel' polkit-devel pam-devel
        pipewire-devel wireplumber-devel libcurl-devel
        libwebp-devel libjxl-devel libsndfile-devel librsvg-devel
        libqalculate-devel libxml2-devel libmd4c-devel libical-devel
        tomlplusplus-devel stb
    )
    sudo xbps-install -y "${build_pkgs[@]}"

    install_nlohmann_json_void

    log "Building the latest stable Noctalia release"
    local tmp src
    tmp="$(mktemp -d)"
    src="$tmp/noctalia"
    clone_latest_release https://github.com/noctalia-dev/noctalia.git "$src"
    (
        cd "$src"
        meson setup build-release --prefix=/usr/local --buildtype=release -Dtests=disabled
        meson compile -C build-release
        sudo meson install -C build-release
    )
    rm -rf "$tmp"
}

install_noctalia_greeter_void() {
    log "Installing Noctalia Greeter build dependencies for Void Linux"
    local build_pkgs=(
        wlroots-devel tomlplusplus-devel stb
    )
    sudo xbps-install -y "${build_pkgs[@]}"

    log "Building the latest stable Noctalia Greeter release"
    local tmp src
    tmp="$(mktemp -d)"
    src="$tmp/noctalia-greeter"
    clone_latest_release https://github.com/noctalia-dev/noctalia-greeter.git "$src"
    (
        cd "$src"
        meson setup build-release --prefix=/usr --buildtype=release
        meson compile -C build-release
        sudo meson install -C build-release
    )
    rm -rf "$tmp"
}

install_bibata_cursor_void() {
    log "Installing Bibata Modern Ice cursor theme"
    if [[ -d /usr/share/icons/Bibata-Modern-Ice ]]; then
        ok "Bibata Modern Ice already installed"
        return
    fi

    local tmp
    tmp="$(mktemp -d)"
    curl -fL --retry 3 -o "$tmp/Bibata-Modern-Ice.tar.xz" \
        https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz
    sudo install -d -m 0755 /usr/share/icons
    sudo tar -xf "$tmp/Bibata-Modern-Ice.tar.xz" -C /usr/share/icons
    rm -rf "$tmp"
}

install_nerd_font() {
    log "Installing JetBrainsMono Nerd Font for Kitty"
    local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"
    if fc-list : family 2>/dev/null | grep -qi 'JetBrainsMono Nerd Font Mono'; then
        ok "JetBrainsMono Nerd Font already installed"
        return
    fi
    mkdir -p "$font_dir"
    local tmp
    tmp="$(mktemp -d)"
    curl -fL --retry 3 -o "$tmp/JetBrainsMono.tar.xz" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
    tar -xf "$tmp/JetBrainsMono.tar.xz" -C "$font_dir"
    rm -rf "$tmp"
    fc-cache -f
}
