#!/usr/bin/env bash
install_packages() {
    log "Installing Fedora packages"
    sudo dnf install -y dnf5-plugins

    local pkgs=(
        niri noctalia greetd greetd-selinux
        xwayland-satellite
        xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-desktop-portal-kde
        pipewire wireplumber polkit gnome-keyring gnome-keyring-pam
        kitty firefox flatpak git curl tar xz unzip python3 xdg-utils
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
