#!/usr/bin/env bash
find_spicetify() {
    if have spicetify; then command -v spicetify; return; fi
    if [[ -x "$HOME/.spicetify/spicetify" ]]; then printf '%s\n' "$HOME/.spicetify/spicetify"; return; fi
    return 1
}

install_spicetify() {
    printf '\n'
    if ! ask_yes_no "Install and configure Spicetify + Marketplace for Spotify?" y; then
        ok "Skipping Spicetify"
        return
    fi

    log "Installing Spicetify"
    # tar is deliberately installed in 10-packages.sh; the upstream installer needs it.
    curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh

    local spicetify
    spicetify="$(find_spicetify || true)"
    [[ -n "$spicetify" ]] || { warn "Spicetify installed but executable was not found in PATH or ~/.spicetify."; return; }

    local prefs="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"
    if [[ ! -f "$prefs" ]]; then
        printf '\nSpotify must initialize its profile before Spicetify can patch it.\n'
        printf 'Spotify will be launched now. Log in, leave it open for about a minute, then CLOSE Spotify.\n'
        printf 'Return to this terminal afterward.\n\n'
        flatpak run com.spotify.Client >/dev/null 2>&1 &
        disown || true
        read -r -p 'Press Enter after Spotify is logged in and closed, or type s then Enter to skip: ' reply || true
        if [[ "${reply:-}" =~ ^[Ss]$ ]]; then
            warn "Skipping Spicetify configuration; rerun the installer later."
            return
        fi
    fi
    [[ -f "$prefs" ]] || { warn "Spotify prefs still not found at $prefs; skipping patch stage."; return; }

    local spotify_path="/var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
    if [[ ! -d "$spotify_path" ]]; then
        spotify_path="$HOME/.local/share/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
    fi
    [[ -d "$spotify_path" ]] || { warn "Could not locate the Spotify Flatpak files."; return; }

    "$spicetify" config spotify_path "$spotify_path"
    "$spicetify" config prefs_path "$prefs"

    if [[ "$spotify_path" == /var/lib/* ]]; then
        sudo chmod a+wr "$spotify_path"
        sudo chmod a+wr -R "$spotify_path/Apps"
    else
        chmod u+rw "$spotify_path" || true
        chmod u+rw -R "$spotify_path/Apps" || true
    fi

    "$spicetify" backup apply
    log "Installing Spicetify Marketplace"
    curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh
    "$spicetify" apply
}
