#!/usr/bin/env bash
install_flatpaks() {
    log "Configuring Flathub and installing Spotify + Vesktop"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub com.spotify.Client dev.vencord.Vesktop

    # Narrow permissions are enough for the common drag-and-drop locations and avoid
    # exposing the entire home directory to Vesktop.
    flatpak override --user \
        --filesystem=xdg-download \
        --filesystem=xdg-documents \
        --filesystem=xdg-pictures \
        dev.vencord.Vesktop
}
