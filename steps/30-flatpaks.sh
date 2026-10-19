#!/usr/bin/env bash
ensure_system_flathub() {
    if flatpak remotes --system --columns=name 2>/dev/null | grep -Fxq flathub; then
        return
    fi

    log "Adding the system Flathub remote"
    sudo flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
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
