#!/usr/bin/env bash
install_packages() {
    if [[ "$FLAVOUR" == "mango" ]]; then
        [[ "$DISTRO_ID" == "void" ]] || die "Mango package installation is currently available on Void only"
        install_packages_mango_void
        return
    fi
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
    install_selected_void_session
}

install_selected_void_session() {
    case "$FLAVOUR" in
        mango) install_void_mango_session ;;
        *) install_void_niri_session ;;
    esac
}

configure_connectivity_audio() {
    case "$DISTRO_ID" in
        fedora) configure_fedora_connectivity_audio ;;
        void) configure_void_connectivity_audio ;;
        *) die "No connectivity/audio configuration for $DISTRO_ID" ;;
    esac
}

repair_connectivity_audio() {
    log "Installing and repairing Wi-Fi, Bluetooth, PipeWire, and brightness persistence"
    case "$DISTRO_ID" in
        fedora)
            sudo dnf install -y NetworkManager bluez bluez-tools upower \
                pipewire pipewire-alsa pipewire-pulseaudio wireplumber alsa-utils brightnessctl
            ;;
        void)
            sudo xbps-install -Sy NetworkManager bluez rfkill upower \
                pipewire wireplumber libspa-bluetooth alsa-pipewire alsa-utils pulseaudio-utils \
                brightnessctl
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
    configure_void_brightness_persistence
    verify_connectivity_audio
}

configure_void_brightness_persistence() {
    sudo install -Dm0755 "$ROOT_DIR/configs/void/noctiri-brightness-run" \
        /etc/sv/noctiri-brightness/run
    enable_void_service noctiri-brightness
    ok "Enabled persistent backlight restore for Void"
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
            warn "NetworkManager was not enabled; the desktop Wi-Fi widget will remain unavailable."
            return 0
        fi
    fi
    enable_void_service NetworkManager
}

configure_void_pipewire() {
    local pipewire_dir="$HOME/.config/pipewire/pipewire.conf.d"
    mkdir -p "$pipewire_dir" "$HOME/.config/autostart"
    configure_void_pipewire_dropin /usr/share/examples/wireplumber/10-wireplumber.conf \
        10-wireplumber.conf
    configure_void_pipewire_dropin /usr/share/examples/pipewire/20-pipewire-pulse.conf \
        20-pipewire-pulse.conf

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

    remove_void_pulseaudio_conflict
    discover_void_user_session_bus
    if [[ -n "${XDG_RUNTIME_DIR:-}" && -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        restart_void_pipewire_stack
    else
        warn "PipeWire will start automatically with the next graphical login."
    fi
}

configure_void_pipewire_dropin() {
    local source="$1" filename="$2"
    local system_path="/etc/pipewire/pipewire.conf.d/$filename"
    local user_path="$HOME/.config/pipewire/pipewire.conf.d/$filename"

    if sudo test -e "$system_path" || sudo test -L "$system_path"; then
        if [[ -L "$user_path" \
            && "$(readlink -f "$user_path")" == "$(readlink -f "$source")" ]]; then
            backup_path "$user_path"
            unlink "$user_path"
            ok "Removed duplicate user PipeWire drop-in $filename; the system copy is active"
        elif [[ -e "$user_path" || -L "$user_path" ]]; then
            warn "Both system and custom user copies of $filename exist; keeping the custom user file."
            warn "Duplicate context.exec entries in those files can start audio components twice."
        fi
        return 0
    fi
    ensure_user_symlink "$source" "$user_path"
}

discover_void_user_session_bus() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local session_pid="" session_name="" candidate address
    if [[ -z "${XDG_RUNTIME_DIR:-}" && -d "$runtime_dir" && -O "$runtime_dir" ]]; then
        export XDG_RUNTIME_DIR="$runtime_dir"
    fi
    # Prefer the running compositor's environment even if an SSH client supplied
    # a stale bus address. dbus-run-session commonly uses /tmp/dbus-* on Void.
    for candidate in niri mango; do
        session_pid="$(pgrep -u "$(id -u)" -xo "$candidate" 2>/dev/null || true)"
        if [[ -n "$session_pid" ]]; then
            session_name="$candidate"
            break
        fi
    done
    if [[ -n "$session_pid" && -r "/proc/$session_pid/environ" ]]; then
        address="$(tr '\0' '\n' < "/proc/$session_pid/environ" \
            | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p' | head -n 1)"
        if [[ -n "$address" ]]; then
            export DBUS_SESSION_BUS_ADDRESS="$address"
            ok "Connected this shell to $session_name's user D-Bus session"
            return 0
        fi
    fi
    if [[ -S "$runtime_dir/bus" ]]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"
        ok "Connected this shell to the existing user D-Bus session"
    fi
}

remove_void_pulseaudio_conflict() {
    local uid
    uid="$(id -u)"
    if pgrep -u "$uid" -x pulseaudio >/dev/null 2>&1; then
        warn "A PulseAudio daemon is occupying the socket required by pipewire-pulse."
        if have pulseaudio; then
            pulseaudio --kill >/dev/null 2>&1 || true
        fi
        pkill -TERM -u "$uid" -x pulseaudio >/dev/null 2>&1 || true
    fi

    if have xbps-query && xbps-query -e pulseaudio >/dev/null 2>&1; then
        warn "The PulseAudio server package conflicts with the selected PipeWire audio stack."
        if ask_yes_no "Remove the conflicting pulseaudio server package?" y; then
            sudo xbps-remove -y pulseaudio
        else
            warn "PulseAudio was kept; pipewire-pulse may continue to fail with 'address already in use'."
        fi
    fi
}

restart_void_pipewire_stack() {
    local uid process log_path attempts
    uid="$(id -u)"
    log_path="${XDG_STATE_HOME:-$HOME/.local/state}/noctiri/pipewire.log"

    # A previous failed launch can leave pipewire-pulse alive without the main
    # PipeWire daemon. Stop the complete per-user stack before starting it in
    # dependency order from PipeWire's configured context.exec entries.
    for process in wireplumber pipewire-pulse pipewire; do
        pkill -TERM -u "$uid" -x "$process" >/dev/null 2>&1 || true
    done
    attempts=0
    while (( attempts < 30 )); do
        if ! pgrep -u "$uid" -x wireplumber >/dev/null 2>&1 \
            && ! pgrep -u "$uid" -x pipewire-pulse >/dev/null 2>&1 \
            && ! pgrep -u "$uid" -x pipewire >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
        ((attempts += 1))
    done
    if pgrep -u "$uid" -x wireplumber >/dev/null 2>&1 \
        || pgrep -u "$uid" -x pipewire-pulse >/dev/null 2>&1 \
        || pgrep -u "$uid" -x pipewire >/dev/null 2>&1; then
        warn "The incomplete PipeWire stack did not stop gracefully; terminating its user processes."
        for process in wireplumber pipewire-pulse pipewire; do
            pkill -KILL -u "$uid" -x "$process" >/dev/null 2>&1 || true
        done
        sleep 0.2
    fi
    if pgrep -u "$uid" -x wireplumber >/dev/null 2>&1 \
        || pgrep -u "$uid" -x pipewire-pulse >/dev/null 2>&1 \
        || pgrep -u "$uid" -x pipewire >/dev/null 2>&1; then
        warn "Could not stop the incomplete PipeWire stack; log out and back in to finish the repair."
        return 0
    fi

    if ! clean_stale_pipewire_sockets; then
        warn "Another process still owns an audio socket; PipeWire was not started on top of it."
        warn "Find the owner with: sudo ss -xlpn | grep -E 'pulse/native|pipewire-'"
        return 0
    fi

    mkdir -p "$(dirname "$log_path")"
    : > "$log_path"
    nohup pipewire > "$log_path" 2>&1 </dev/null &
    sleep 2
    if pgrep -u "$uid" -x pipewire >/dev/null 2>&1; then
        ok "Restarted a clean PipeWire user stack"
    else
        warn "PipeWire exited during startup; inspect $log_path"
    fi
}

clean_stale_pipewire_sockets() {
    local runtime_dir socket
    runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    for socket in \
        "$runtime_dir/pulse/native" \
        "$runtime_dir/pipewire-0" \
        "$runtime_dir/pipewire-0-manager"; do
        [[ -S "$socket" ]] || continue
        if grep -Fq -- "$socket" /proc/net/unix; then
            warn "A live process owns $socket"
            return 1
        fi
        unlink "$socket"
        ok "Removed stale audio socket $socket"
    done
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
    if have nmcli && run_service_probe nmcli general status >/dev/null 2>&1; then
        ok "NetworkManager is responding"
    else
        warn "NetworkManager is not responding yet"
    fi
    if have bluetoothctl && run_service_probe bluetoothctl list >/dev/null 2>&1; then
        ok "BlueZ is responding"
    else
        warn "BlueZ is not responding yet (the adapter may also be disabled or absent)"
    fi
    if have wpctl && run_service_probe wpctl status >/dev/null 2>&1; then
        ok "PipeWire and WirePlumber are responding"
    else
        warn "PipeWire/WirePlumber did not respond within 5 seconds."
        warn "After logging out and back in, check: timeout 5 wpctl status"
        warn "Void startup log: ${XDG_STATE_HOME:-$HOME/.local/state}/noctiri/pipewire.log"
    fi
    if have pactl && run_service_probe pactl info >/dev/null 2>&1; then
        ok "PipeWire's PulseAudio compatibility server is responding"
    else
        warn "PipeWire's PulseAudio compatibility server did not respond within 5 seconds"
    fi
}

run_service_probe() {
    have timeout || {
        warn "The timeout command is unavailable; skipping a potentially blocking service probe."
        return 1
    }
    timeout --signal=TERM --kill-after=1 5 "$@"
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
    if [[ "$FLAVOUR" == "mango" ]]; then
        configure_mango_gpu_override
    else
        configure_niri_gpu_override
    fi
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
        base-devel meson ninja pkg-config
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
