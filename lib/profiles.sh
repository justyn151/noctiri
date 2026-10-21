#!/usr/bin/env bash

PROFILE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/noctiri/install-profile"

profile_valid() {
    case "$1" in
        minimal|standard|full) return 0 ;;
        *) return 1 ;;
    esac
}

profile_title() {
    case "$1" in
        minimal) printf 'Minimal' ;;
        standard) printf 'Standard' ;;
        full) printf 'Full' ;;
    esac
}

profile_has() {
    local feature="$1"
    case "$feature" in
        core) return 0 ;;
        editor|documents|music|zsh|utilities|desktop-apps|flatpaks|wallpapers|spicetify)
            [[ "$INSTALL_PROFILE" == standard || "$INSTALL_PROFILE" == full ]]
            ;;
        gaming) [[ "$INSTALL_PROFILE" == full ]] ;;
        *) return 1 ;;
    esac
}

print_install_profiles() {
    cat <<'EOF'
Noctiri installation profiles

  1. Minimal
     Niri + Noctalia, greeter, Kitty, Firefox, Yazi, fonts, connectivity,
     audio, brightness persistence, Doctor, and managed configuration.

  2. Standard (recommended)
     Everything in Minimal, plus Neovim and compact LaTeX, rmpc, Zsh,
     daily utilities/OCR/KeePassXC, graphical fallback tools, Vesktop,
     wallpapers, Spotify, and Spicetify.

  3. Full
     Everything in Standard, plus Steam, Gamescope, MangoHud, GameMode,
     32-bit graphics libraries, and hybrid-GPU launch helpers.

DWL is an independent preview and is never installed by these profiles.
EOF
}

select_install_profile() {
    local remembered=standard choice default_number=2

    if [[ -n "${INSTALL_PROFILE:-}" ]]; then
        profile_valid "$INSTALL_PROFILE" || die "Unknown installation profile: $INSTALL_PROFILE"
        return 0
    fi

    if [[ -r "$PROFILE_FILE" ]]; then
        IFS= read -r remembered < "$PROFILE_FILE"
        profile_valid "$remembered" || remembered=standard
    fi
    case "$remembered" in
        minimal) default_number=1 ;;
        standard) default_number=2 ;;
        full) default_number=3 ;;
    esac

    if [[ ! -t 0 ]]; then
        INSTALL_PROFILE="$remembered"
        warn "No interactive terminal was detected; using the remembered $(profile_title "$INSTALL_PROFILE") profile"
        return 0
    fi

    print_install_profiles
    printf '\nChoose a profile [1-3, default %s — %s]: ' \
        "$default_number" "$(profile_title "$remembered")"
    read -r choice || true
    choice="${choice:-$default_number}"
    case "$choice" in
        1|minimal|Minimal) INSTALL_PROFILE=minimal ;;
        2|standard|Standard) INSTALL_PROFILE=standard ;;
        3|full|Full) INSTALL_PROFILE=full ;;
        *) die "Unknown profile choice: $choice" ;;
    esac
}

print_install_review() {
    printf '\nInstallation review\n'
    printf '  Distribution: %s\n' "$DISTRO_NAME"
    printf '  Profile:      %s\n' "$(profile_title "$INSTALL_PROFILE")"
    printf '  Always:       Niri, Noctalia, greeter, Kitty, Firefox, Yazi, fonts,\n'
    printf '                portals, networking, Bluetooth, PipeWire, brightness, Doctor\n'

    if profile_has editor; then
        printf '  Productivity: Neovim/CoC, Sioyek/Tectonic/TexLab, Zsh/Oh My Zsh\n'
        printf '  Utilities:    rmpc/MPD, KeePassXC, OCR, screenshot and Yazi helpers\n'
        printf '  Extras:       graphical fallback apps, Vesktop, wallpapers, Spotify/Spicetify\n'
    else
        printf '  Excluded:     editor/LaTeX, music stack, Zsh, daily utility bundle,\n'
        printf '                graphical fallback apps, Flatpaks, wallpapers, Spotify\n'
    fi

    if profile_has gaming; then
        printf '  Gaming:       Steam, Gamescope, MangoHud, GameMode, GPU offload runtime\n'
    else
        printf '  Gaming:       excluded (can be added later with --steam-only)\n'
    fi
    printf '  DWL preview:  excluded (always installed separately with --dwl-only)\n'
}

save_install_profile() {
    mkdir -p "$(dirname "$PROFILE_FILE")"
    printf '%s\n' "$INSTALL_PROFILE" > "$PROFILE_FILE"
}

profile_skip() {
    printf '\033[1;36m  –\033[0m %s is not included in the %s profile\n' \
        "$1" "$(profile_title "$INSTALL_PROFILE")"
}
