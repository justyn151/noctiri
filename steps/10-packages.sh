#!/usr/bin/env bash
install_packages() {
    case "$DISTRO_ID" in
        fedora) install_packages_fedora ;;
        void) install_packages_void ;;
        *) die "No package installation implementation for $DISTRO_ID" ;;
    esac
}

install_neovim_editor() {
    log "Installing Neovim, the CoC runtime, and Wayland clipboard support"
    case "$DISTRO_ID" in
        fedora)
            sudo dnf install -y neovim nodejs wl-clipboard
            if rpm -q vim-enhanced >/dev/null 2>&1; then
                sudo dnf remove -y vim-enhanced
                ok "Removed the legacy Vim package"
            fi
            ;;
        void)
            sudo xbps-install -Sy neovim nodejs wl-clipboard
            if xbps-query -e vim >/dev/null 2>&1; then
                sudo xbps-remove -y vim
                ok "Removed the legacy Vim package"
            fi
            ;;
        *) die "No Neovim package installation implementation for $DISTRO_ID" ;;
    esac
}

install_tectonic_release_binary() {
    local arch tag version asset tmp
    case "$(uname -m)" in
        x86_64) arch=x86_64-unknown-linux-gnu ;;
        aarch64) arch=aarch64-unknown-linux-gnu ;;
        *) die "No prebuilt Tectonic release is available for $(uname -m)" ;;
    esac

    tag="$({ git ls-remote --refs --tags https://github.com/tectonic-typesetting/tectonic.git 2>/dev/null || true; } \
        | awk '$2 ~ /^refs\/tags\/tectonic@[0-9]+\.[0-9]+\.[0-9]+$/ {sub("refs/tags/", "", $2); print $2}' \
        | sort -V | tail -n 1)"
    [[ -n "$tag" ]] || die "Could not determine the latest Tectonic release"
    version="${tag#tectonic@}"
    asset="tectonic-${version}-${arch}.tar.gz"
    tmp="$(mktemp -d)"
    curl -fL --retry 3 -o "$tmp/$asset" \
        "https://github.com/tectonic-typesetting/tectonic/releases/download/$tag/$asset"
    tar -xzf "$tmp/$asset" -C "$tmp"
    install_file "$tmp/tectonic" "$HOME/.local/bin/tectonic" 0755
    rm -rf "$tmp"
}

install_document_stack() {
    log "Installing Sioyek, TexLab, Node.js, and the compact Tectonic LaTeX engine"
    case "$DISTRO_ID" in
        fedora)
            # Fedora does not currently ship either application in its base
            # repositories. Tectonic's upstream release is one self-contained
            # executable; Sioyek's documented Flatpak is the maintainable GUI.
            if ! have tectonic; then
                install_tectonic_release_binary
            fi
            sudo dnf install -y flatpak nodejs
            ensure_system_flathub
            sudo flatpak install --system -y flathub com.github.ahrm.sioyek
            flatpak override --user --filesystem=home com.github.ahrm.sioyek
            install_file "$ROOT_DIR/configs/bin/sioyek-flatpak" \
                "$HOME/.local/bin/sioyek" 0755
            ;;
        void)
            # Tectonic is about 18 MiB on Void and downloads only the TeX
            # resources a document uses; texlive-core is several gigabytes.
            sudo xbps-install -Sy tectonic sioyek texlab nodejs
            install_file "$ROOT_DIR/configs/bin/sioyek-void" \
                "$HOME/.local/bin/sioyek" 0755
            install_file "$ROOT_DIR/configs/applications/sioyek.desktop" \
                "$HOME/.local/share/applications/sioyek.desktop"
            if have update-desktop-database; then
                update-desktop-database "$HOME/.local/share/applications" || true
            fi
            ;;
        *) die "No document stack implementation for $DISTRO_ID" ;;
    esac

    have tectonic || die "Tectonic was installed but is not on PATH"
    if have sioyek || flatpak info com.github.ahrm.sioyek >/dev/null 2>&1; then
        ok "Installed Sioyek with on-demand LaTeX support from Tectonic"
    else
        die "Sioyek installation could not be verified"
    fi
}

install_rmpc_release_binary() {
    local arch tag asset tmp binary
    case "$(uname -m)" in
        x86_64) arch=x86_64-unknown-linux-gnu ;;
        aarch64) arch=aarch64-unknown-linux-gnu ;;
        *) die "No prebuilt rmpc release is available for $(uname -m)" ;;
    esac

    tag="$({ git ls-remote --refs --tags https://github.com/mierak/rmpc.git 2>/dev/null || true; } \
        | awk '$2 ~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+$/ {sub("refs/tags/", "", $2); print $2}' \
        | sort -V | tail -n 1)"
    [[ -n "$tag" ]] || die "Could not determine the latest rmpc release"
    asset="rmpc-${tag}-${arch}.tar.gz"
    tmp="$(mktemp -d)"
    curl -fL --retry 3 -o "$tmp/$asset" \
        "https://github.com/mierak/rmpc/releases/download/$tag/$asset"
    tar -xzf "$tmp/$asset" -C "$tmp"
    binary="$(find "$tmp" -type f -name rmpc -perm -u+x -print -quit)"
    [[ -n "$binary" ]] || die "The rmpc release archive did not contain its executable"
    install_file "$binary" "$HOME/.local/bin/rmpc" 0755
    rm -rf "$tmp"
}

install_rmpc_stack() {
    log "Installing rmpc and its per-user MPD backend"
    export PATH="$HOME/.local/bin:$PATH"
    case "$DISTRO_ID" in
        fedora)
            sudo dnf install -y mpd
            have rmpc || install_rmpc_release_binary
            ;;
        void)
            sudo xbps-install -Sy rmpc mpd
            ;;
        *) die "No rmpc installation implementation for $DISTRO_ID" ;;
    esac

    render_home_template "$ROOT_DIR/configs/mpd/mpd.conf.in" \
        "$HOME/.config/mpd/mpd.conf"
    install_file "$ROOT_DIR/configs/bin/noctiri-mpd" \
        "$HOME/.local/bin/noctiri-mpd" 0755
    install_file "$ROOT_DIR/configs/autostart/noctiri-mpd.desktop" \
        "$HOME/.config/autostart/noctiri-mpd.desktop"
    mkdir -p \
        "$HOME/Music" \
        "$HOME/.local/share/mpd/playlists" \
        "$HOME/.local/state/mpd" \
        "$HOME/.config/rmpc"

    if [[ ! -s "$HOME/.config/rmpc/config.ron" ]]; then
        local generated_config
        generated_config="$(mktemp)"
        rmpc config > "$generated_config"
        install_file "$generated_config" "$HOME/.config/rmpc/config.ron"
        rm -f "$generated_config"
    else
        ok "Preserved the existing rmpc configuration"
    fi

    if ! pgrep -u "$(id -u)" -x mpd >/dev/null 2>&1; then
        import_graphical_session_environment
        "$HOME/.local/bin/noctiri-mpd" >/dev/null 2>&1 &
        local attempt
        for attempt in {1..20}; do
            pgrep -u "$(id -u)" -x mpd >/dev/null 2>&1 && break
            sleep 0.1
        done
    fi

    have rmpc || die "rmpc was installed but is not on PATH"
    pgrep -u "$(id -u)" -x mpd >/dev/null 2>&1 \
        || die "MPD did not start; inspect $HOME/.local/state/mpd/mpd.log"
    ok "Installed rmpc with a PipeWire-backed user MPD session"
}

install_zsh_shell() {
    log "Installing Zsh and Oh My Zsh"
    case "$DISTRO_ID" in
        fedora) sudo dnf install -y zsh git ;;
        void) sudo xbps-install -Sy zsh git ;;
        *) die "No Zsh package installation implementation for $DISTRO_ID" ;;
    esac

    local oh_my_zsh_dir="$HOME/.oh-my-zsh"
    if [[ -d "$oh_my_zsh_dir/.git" ]]; then
        ok "Oh My Zsh is already installed"
    elif [[ -e "$oh_my_zsh_dir" ]]; then
        die "$oh_my_zsh_dir already exists but is not an Oh My Zsh Git checkout"
    else
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$oh_my_zsh_dir"
    fi

    local custom_plugins="${ZSH_CUSTOM:-$oh_my_zsh_dir/custom}/plugins"
    local plugin_name plugin_url plugin_dir
    while read -r plugin_name plugin_url; do
        plugin_dir="$custom_plugins/$plugin_name"
        if [[ -d "$plugin_dir/.git" ]]; then
            ok "$plugin_name is already installed"
        elif [[ -e "$plugin_dir" ]]; then
            die "$plugin_dir exists but is not a Git checkout"
        else
            git clone --depth=1 "$plugin_url" "$plugin_dir"
        fi
    done <<'PLUGINS'
zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
PLUGINS

    install_file "$ROOT_DIR/configs/zsh/zshrc" "$HOME/.zshrc"
    if have kitty; then
        install_file "$ROOT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    fi

    local zsh_path current_shell
    zsh_path="$(command -v zsh)"
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current_shell" != "$zsh_path" ]]; then
        sudo usermod -s "$zsh_path" "$USER"
        ok "Set $zsh_path as the login shell for $USER"
    fi

    zsh -ic '[[ -n "$ZSH" && -r "$ZSH/oh-my-zsh.sh" ]]' \
        || die "Oh My Zsh did not load from the installed .zshrc"
}

install_packages_fedora() {
    log "Installing Fedora packages"
    sudo dnf install -y dnf5-plugins

    local pkgs=(
        niri noctalia quickshell greetd greetd-selinux
        xwayland-satellite
        xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-desktop-portal-kde
        NetworkManager bluez bluez-tools upower
        pipewire pipewire-alsa pipewire-pulseaudio wireplumber alsa-utils
        polkit gnome-keyring gnome-keyring-pam
        kitty firefox neovim zsh ripgrep flatpak git curl tar xz unzip python3 xdg-utils wl-clipboard
        playerctl brightnessctl
        qt6ct plasma-breeze-qt6 breeze-icon-theme
        dolphin ark btop cava fastfetch qimgv mpv
        qpwgraph
        rsms-inter-fonts
    )
    sudo dnf install -y "${pkgs[@]}"

    if ! have yazi; then
        log "Installing Yazi from its Fedora COPR"
        sudo dnf copr enable -y lihaohong/yazi
        sudo dnf install -y yazi
    fi

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
        niri quickshell greetd dbus elogind seatd accountsservice mesa-dri
        xwayland-satellite
        xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-desktop-portal-kde
        NetworkManager bluez rfkill upower
        pipewire wireplumber libspa-bluetooth alsa-pipewire alsa-utils pulseaudio-utils
        polkit gnome-keyring
        kitty firefox neovim zsh ripgrep flatpak git curl tar xz unzip python3 xdg-utils wl-clipboard
        playerctl brightnessctl
        qt6ct breeze-qt6 breeze-icons
        dolphin ark btop cava fastfetch qimgv mpv
        qpwgraph
        yazi ffmpeg 7zip jq poppler fd fzf zoxide resvg ImageMagick
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
    log "Configuring Void Bluetooth, PipeWire, and brightness persistence"
    enable_void_service dbus
    enable_void_service bluetoothd

    add_user_to_group_if_present network
    add_user_to_group_if_present bluetooth
    add_user_to_group_if_present audio
    add_user_to_group_if_present video

    configure_void_pipewire
    configure_void_brightness_persistence
    verify_connectivity_audio false
}

finish_void_networkmanager_handoff() {
    [[ "$DISTRO_ID" == "void" ]] || return 0

    log "Finishing the Void NetworkManager handoff"
    configure_void_networkmanager || return $?
    verify_networkmanager
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
        if ask_yes_no "All downloads are complete. Switch networking to NetworkManager now? This may briefly disconnect the network." n; then
            for service in "${conflicts[@]}"; do
                sudo sv down "$service" >/dev/null 2>&1 || true
                sudo unlink "/var/service/$service"
                ok "Disabled the conflicting $service service"
            done
        else
            warn "NetworkManager was not enabled; the handoff can be retried with ./install.sh --services-only."
            warn "Noctalia's Wi-Fi widget will remain unavailable until the handoff is completed."
            return "$STEP_DEFERRED"
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
        warn "PipeWire will start automatically with the next Niri login."
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
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" niri_pid address
    if [[ -z "${XDG_RUNTIME_DIR:-}" && -d "$runtime_dir" && -O "$runtime_dir" ]]; then
        export XDG_RUNTIME_DIR="$runtime_dir"
    fi
    # Prefer Niri's environment even if an SSH client supplied a stale or
    # unrelated bus address. dbus-run-session commonly uses /tmp/dbus-* on Void.
    niri_pid="$(pgrep -u "$(id -u)" -xo niri 2>/dev/null || true)"
    if [[ -n "$niri_pid" && -r "/proc/$niri_pid/environ" ]]; then
        address="$(tr '\0' '\n' < "/proc/$niri_pid/environ" \
            | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p' | head -n 1)"
        if [[ -n "$address" ]]; then
            export DBUS_SESSION_BUS_ADDRESS="$address"
            ok "Connected this shell to Niri's user D-Bus session"
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
    local verify_network="${1:-true}"
    if [[ "$verify_network" == "true" ]]; then
        verify_networkmanager
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

verify_networkmanager() {
    if have nmcli && run_service_probe nmcli general status >/dev/null 2>&1; then
        ok "NetworkManager is responding"
    else
        warn "NetworkManager is not responding yet"
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
    local network_status=0
    finish_void_networkmanager_handoff || network_status=$?
    (( network_status == 0 || network_status == STEP_DEFERRED )) || return "$network_status"
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
        base-devel meson ninja pkg-config
        wlroots-devel tomlplusplus-devel stb
    )
    sudo xbps-install -y "${build_pkgs[@]}"

    # The greeter also links nlohmann_json. Keep this here even though the
    # Noctalia build installs it too, because greeter repair/rebuild is a
    # standalone stateful step and may run after package builds were skipped.
    install_nlohmann_json_void

    log "Building the latest stable Noctalia Greeter release"
    local tmp src
    tmp="$(mktemp -d)"
    src="$tmp/noctalia-greeter"
    clone_latest_release https://github.com/noctalia-dev/noctalia-greeter.git "$src"
    (
        cd "$src"
        patch -p1 < "$ROOT_DIR/patches/noctalia-greeter/password-glyph-animation.patch"
        meson setup build-release --prefix=/usr --buildtype=release
        meson compile -C build-release
        sudo meson install -C build-release
    )
    rm -rf "$tmp"
    mark_step_complete greeter-panel-blur-v3
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

install_fantasque_nerd_font() {
    log "Installing Fantasque Sans Mono Nerd Font 3.5.1"
    local font_dir="$HOME/.local/share/fonts/FantasqueSansMonoNerd"
    if fc-list : family 2>/dev/null | grep -qi 'FantasqueSansM Nerd Font Mono'; then
        ok "Fantasque Sans Mono Nerd Font already installed"
        return
    fi
    mkdir -p "$font_dir"
    local tmp
    tmp="$(mktemp -d)"
    curl -fL --retry 3 -o "$tmp/FantasqueSansMono.zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/FantasqueSansMono.zip
    printf '%s  %s\n' \
        '083c543efbfbb1be47897c02c2285ad7f7b75bd74765fad38d8a04f9db45c6f4' \
        "$tmp/FantasqueSansMono.zip" | sha256sum -c -
    unzip -q "$tmp/FantasqueSansMono.zip" -d "$font_dir"
    rm -rf "$tmp"
    fc-cache -f
}
