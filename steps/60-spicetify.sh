#!/usr/bin/env bash
find_spicetify() {
    if have spicetify; then command -v spicetify; return; fi
    if [[ -x "$HOME/.spicetify/spicetify" ]]; then printf '%s\n' "$HOME/.spicetify/spicetify"; return; fi
    return 1
}

install_spicetify() {
    printf '\n'
    if ! ask_yes_no "Install Spotify and configure Spicetify + Marketplace?" y; then
        ok "Skipping Spotify and Spicetify"
        return
    fi

    ensure_spotify_flatpak
    import_graphical_session_environment

    local prefs="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"
    if [[ ! -f "$prefs" ]]; then
        if [[ -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" ]]; then
            warn "No graphical session is available, so Spotify cannot create its prefs file yet."
            warn "After logging into Niri, open Spotify once, log in, close it, then run: ./install.sh --spicetify-only"
            return "$STEP_DEFERRED"
        fi

        printf '\nSpotify must initialize its real profile before Spicetify can patch it.\n'
        printf 'Spotify will open in the running graphical session. Log in, then CLOSE Spotify.\n'
        printf 'The installer will continue automatically after the app exits.\n\n'
        flatpak run com.spotify.Client >/dev/null 2>&1 &
        local spotify_pid=$!
        wait "$spotify_pid" || true

        # A Flatpak invocation can hand off to an already-running instance and
        # exit before the application does. Never patch Spotify while it is open.
        while flatpak ps --columns=application 2>/dev/null \
            | grep -Fxq com.spotify.Client; do
            sleep 2
        done
    fi
    if [[ ! -f "$prefs" ]]; then
        warn "Spotify prefs still not found at $prefs; deferring the patch stage."
        return "$STEP_DEFERRED"
    fi

    local spicetify
    spicetify="$(find_spicetify || true)"
    if [[ -z "$spicetify" ]]; then
        log "Installing Spicetify"
        # tar is deliberately installed in 10-packages.sh; the upstream installer needs it.
        curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
        spicetify="$(find_spicetify || true)"
        [[ -n "$spicetify" ]] || { warn "Spicetify installed but executable was not found in PATH or ~/.spicetify."; return 1; }
    else
        ok "Spicetify is already installed"
    fi

    local spotify_path="/var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
    if [[ ! -d "$spotify_path" ]]; then
        spotify_path="$HOME/.local/share/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
    fi
    [[ -d "$spotify_path" ]] || { warn "Could not locate the Spotify Flatpak files."; return 1; }

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
