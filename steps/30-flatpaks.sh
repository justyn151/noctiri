#!/usr/bin/env bash
ensure_system_flathub() {
    if flatpak remotes --system --columns=name 2>/dev/null | grep -Fxq flathub; then
        return
    fi

    log "Adding the system Flathub remote"
    sudo flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_steam() {
    log "Installing Steam and the Noctiri gaming runtime"

    case "$DISTRO_ID" in
        void)
            if [[ "$(uname -m)" == x86_64 ]] \
                && getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
                # Void's native Steam package is proprietary and needs both
                # nonfree repositories plus the 32-bit multilib repository.
                sudo xbps-install -Sy \
                    void-repo-nonfree \
                    void-repo-multilib \
                    void-repo-multilib-nonfree
                sudo xbps-install -Sy steam

                local steam_graphics=(
                    mesa-dri-32bit
                    vulkan-loader
                    vulkan-loader-32bit
                    Vulkan-Tools
                    gamescope
                    gamescope-32bit
                    MangoHud
                    MangoHud-32bit
                    gamemode
                    libgamemode
                    libgamemode-32bit
                )
                if grep -Fqx 0x8086 /sys/bus/pci/devices/*/vendor 2>/dev/null; then
                    steam_graphics+=(mesa-vulkan-intel mesa-vulkan-intel-32bit)
                fi
                if grep -Fqx 0x1002 /sys/bus/pci/devices/*/vendor 2>/dev/null; then
                    steam_graphics+=(mesa-vulkan-radeon mesa-vulkan-radeon-32bit)
                fi
                if grep -Fqx 0x10de /sys/bus/pci/devices/*/vendor 2>/dev/null; then
                    # Do not mix the Nouveau Vulkan provider into a system that
                    # is already using NVIDIA's proprietary kernel/userspace
                    # stack. Steam games need the matching 32-bit NVIDIA library.
                    if find /sys/bus/pci/devices -maxdepth 2 -path '*/driver' \
                        -type l -lname '*/nvidia' -print -quit 2>/dev/null \
                        | grep -q . \
                        || xbps-query -e nvidia-libs >/dev/null 2>&1; then
                        steam_graphics+=(nvidia-libs nvidia-libs-32bit)
                    else
                        steam_graphics+=(mesa-vulkan-nouveau mesa-vulkan-nouveau-32bit)
                    fi
                fi
                sudo xbps-install -Sy "${steam_graphics[@]}"

                install_file "$ROOT_DIR/configs/bin/noctiri-gpu-run" \
                    "$HOME/.local/bin/noctiri-gpu-run" 0755
                install_file "$ROOT_DIR/configs/applications/noctiri-steam-discrete.desktop" \
                    "$HOME/.local/share/applications/noctiri-steam-discrete.desktop"
                if have update-desktop-database; then
                    update-desktop-database "$HOME/.local/share/applications" || true
                fi
            else
                # Native Steam is not available on Void musl or non-x86_64.
                # The Flatpak bundles its compatible userspace instead.
                sudo xbps-install -Sy flatpak
                ensure_system_flathub
                sudo flatpak install --system -y flathub com.valvesoftware.Steam
            fi
            ;;
        fedora)
            sudo dnf install -y flatpak
            ensure_system_flathub
            sudo flatpak install --system -y flathub com.valvesoftware.Steam
            ;;
        *) die "No Steam installation implementation for $DISTRO_ID" ;;
    esac

    if have steam || flatpak info --system com.valvesoftware.Steam >/dev/null 2>&1; then
        ok "Installed Steam and its gaming runtime"
        if [[ "$DISTRO_ID" == "void" && -x "$HOME/.local/bin/noctiri-gpu-run" ]]; then
            "$HOME/.local/bin/noctiri-gpu-run" --print
        fi
    else
        die "Steam installation could not be verified"
    fi
}

ensure_spotify_flatpak() {
    have flatpak || die "Flatpak is required to install Spotify"

    if flatpak info com.spotify.Client >/dev/null 2>&1; then
        ok "Spotify Flatpak is already installed"
        return
    fi

    ensure_system_flathub
    log "Installing Spotify Flatpak"
    sudo flatpak install --system -y flathub com.spotify.Client
}

install_flatpaks() {
    log "Configuring Flathub and installing Vesktop"
    ensure_system_flathub
    sudo flatpak install --system -y flathub dev.vencord.Vesktop

    # Narrow permissions are enough for the common drag-and-drop locations and avoid
    # exposing the entire home directory to Vesktop.
    flatpak override --user \
        --filesystem=xdg-download \
        --filesystem=xdg-documents \
        --filesystem=xdg-pictures \
        dev.vencord.Vesktop
}
