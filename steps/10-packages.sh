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
        pipewire wireplumber polkit gnome-keyring gnome-keyring-pam
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
        niri greetd dbus elogind accountsservice
        xwayland-satellite
        xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-desktop-portal-kde
        pipewire wireplumber libspa-bluetooth alsa-pipewire pulseaudio-utils polkit gnome-keyring
        kitty firefox vim ripgrep texlive-latexmk flatpak git curl tar xz unzip python3 xdg-utils
        playerctl brightnessctl
        qt6ct breeze-qt6 breeze-icons
        dolphin ark fooyin btop cava fastfetch qimgv mpv
        zathura zathura-pdf-mupdf qpwgraph
        font-inter
    )
    sudo xbps-install -y "${pkgs[@]}"

    configure_void_runtime
    install_noctalia_void
    install_noctalia_greeter_void
    install_bibata_cursor_void
}

configure_void_runtime() {
    log "Configuring Void system D-Bus and PipeWire"
    if [[ ! -e /var/service/dbus && ! -L /var/service/dbus ]]; then
        sudo ln -s /etc/sv/dbus /var/service/
        ok "Enabled the dbus runit service"
    fi

    local pipewire_dir="$HOME/.config/pipewire/pipewire.conf.d"
    mkdir -p "$pipewire_dir"
    if [[ ! -e "$pipewire_dir/10-wireplumber.conf" && ! -L "$pipewire_dir/10-wireplumber.conf" ]]; then
        ln -s /usr/share/examples/wireplumber/10-wireplumber.conf "$pipewire_dir/10-wireplumber.conf"
    fi
    if [[ ! -e "$pipewire_dir/20-pipewire-pulse.conf" && ! -L "$pipewire_dir/20-pipewire-pulse.conf" ]]; then
        ln -s /usr/share/examples/pipewire/20-pipewire-pulse.conf "$pipewire_dir/20-pipewire-pulse.conf"
    fi
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
