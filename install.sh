#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"
for step in "$ROOT_DIR"/steps/*.sh; do
    # shellcheck disable=SC1090
    source "$step"
done

trap 'printf "\nInstaller stopped at line %s. Existing files were backed up under: %s\n" "$LINENO" "$BACKUP_DIR" >&2' ERR

usage() {
    printf 'Usage: %s [mode] [--flavour niri|mango] [--theme day|night]\n' "$0"
    printf '  --mango-only       Add or repair the Tatami/Mango flavour without rebuilding Niri\n'
    printf '  --wallpapers-only  Install or update wallpaper collections without rerunning setup\n'
    printf '  --spicetify-only   Finish Spicetify after Spotify has created its graphical profile\n'
    printf '  --greeter-only     Repair greetd/Noctalia Greeter configuration without rebuilding\n'
    printf '  --void-runtime-only  Repair Void graphics and seat services without rebuilding\n'
    printf '  --theme-only       Apply or repair desktop colors without rebuilding\n'
    printf '  --services-only    Repair Wi-Fi, Bluetooth, PipeWire, and brightness persistence\n'
    printf '  --flavour VALUE    Select niri or mango for a full install (Mango is Void-only)\n'
    printf '  --theme VALUE      Select the initial Mango theme: day or night\n'
}

set_mode() {
    local requested="$1"
    [[ "$MODE" == "full" ]] || die "Only one installer mode can be selected"
    MODE="$requested"
}

MODE=full
while (( $# > 0 )); do
    case "$1" in
        --mango-only) set_mode mango; FLAVOUR=mango ;;
        --wallpapers-only) set_mode wallpapers ;;
        --spicetify-only) set_mode spicetify ;;
        --greeter-only) set_mode greeter ;;
        --void-runtime-only) set_mode void-runtime ;;
        --theme-only) set_mode theme ;;
        --services-only) set_mode services ;;
        --flavour)
            shift
            [[ $# -gt 0 ]] || die "--flavour requires niri or mango"
            FLAVOUR="$1"
            ;;
        --theme)
            shift
            [[ $# -gt 0 ]] || die "--theme requires day or night"
            TATAMI_THEME="$1"
            ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1 (try --help)" ;;
    esac
    shift
done

case "$FLAVOUR" in ""|niri|mango) ;; *) die "Unknown flavour: $FLAVOUR" ;; esac
case "$TATAMI_THEME" in ""|day|night) ;; *) die "Unknown theme: $TATAMI_THEME" ;; esac

checks

choose_flavour() {
    [[ -z "$FLAVOUR" ]] || return 0
    if [[ "$DISTRO_ID" != "void" ]]; then
        FLAVOUR=niri
        return 0
    fi
    printf '\nChoose a Noctiri flavour:\n'
    printf '  1) Modern — Niri + Noctalia (scrolling layout)\n'
    printf '  2) Tatami — Mango + Waybar (traditional master-stack tiling)\n'
    local reply
    read -r -p 'Selection [1]: ' reply || true
    case "${reply:-1}" in
        1) FLAVOUR=niri ;;
        2) FLAVOUR=mango ;;
        *) die "Invalid flavour selection: $reply" ;;
    esac
}

choose_tatami_theme() {
    [[ "$FLAVOUR" == "mango" ]] || return 0
    [[ -z "$TATAMI_THEME" ]] || return 0
    printf '\nChoose the initial Tatami appearance:\n'
    printf '  1) Night — blue-charcoal, sage, coral and moon-gold\n'
    printf '  2) Day   — parchment, teal, moss and persimmon\n'
    local reply
    read -r -p 'Selection [1]: ' reply || true
    case "${reply:-1}" in
        1) TATAMI_THEME=night ;;
        2) TATAMI_THEME=day ;;
        *) die "Invalid theme selection: $reply" ;;
    esac
}

if [[ "$MODE" != "full" && "$MODE" != "mango" && -z "$FLAVOUR" ]]; then
    FLAVOUR=niri
fi

[[ "$FLAVOUR" != "mango" || "$DISTRO_ID" == "void" ]] \
    || die "The Tatami/Mango flavour currently supports Void Linux only"
if [[ "$MODE" != "full" && "$FLAVOUR" != "mango" && -n "$TATAMI_THEME" ]]; then
    die "--theme applies only to the Mango flavour"
fi

if [[ "$MODE" == "wallpapers" ]]; then
    printf '\nWallpaper-only mode: package installation, source builds, configs, greeter, and apps will be skipped.\n\n'
    configure_wallpapers
    mark_step_complete wallpapers
    printf '\n\033[1;32mWallpaper update complete.\033[0m\n'
    if [[ "$FLAVOUR" == "mango" ]]; then
        printf 'Apply one now with: noctiri-wallpaper /path/to/image\n'
    else
        printf 'Choose or refresh the wallpaper in Noctalia if the running session does not notice it automatically.\n'
    fi
    exit 0
fi

if [[ "$MODE" == "spicetify" ]]; then
    printf '\nSpicetify-only mode: all other installer stages will be skipped.\n\n'
    run_stateful_step spicetify "Spicetify setup" install_spicetify true
    exit 0
fi

if [[ "$MODE" == "greeter" ]]; then
    printf '\nGreeter-only mode: package installation, source builds, desktop configs, and apps will be skipped.\n\n'
    run_stateful_step greeter "greetd and Noctalia Greeter configuration" configure_greeter true
    if [[ "$DISTRO_ID" == "void" && -e /var/service/greetd ]]; then
        printf '\nThe configuration is repaired. From this TTY, apply it with: sudo sv restart greetd\n'
    fi
    exit 0
fi

if [[ "$MODE" == "void-runtime" ]]; then
    [[ "$DISTRO_ID" == "void" ]] || die "--void-runtime-only is only available on Void Linux"
    printf '\nVoid runtime repair mode: Niri and Noctalia will not be rebuilt.\n\n'
    repair_void_runtime
    printf '\nVoid graphics and seat runtime repaired. From this TTY, apply it with: sudo sv restart greetd\n'
    exit 0
fi

if [[ "$MODE" == "theme" ]]; then
    printf '\nTheme-only mode: packages, builds, greeter, wallpapers, and apps will be skipped.\n\n'
    if [[ "$FLAVOUR" == "mango" ]]; then
        choose_tatami_theme
        [[ -x "$HOME/.local/bin/noctiri-theme" ]] \
            || die "Tatami is not configured yet; run ./install.sh --mango-only first"
        "$HOME/.local/bin/noctiri-theme" "$TATAMI_THEME"
        printf '\nTatami colors applied. Restart any open Qt or btop applications to reload their palette.\n'
    else
        repair_theme_sync
        printf '\nColors and bar clocks repaired. Restart any open KDE/Qt applications to reload their palette.\n'
    fi
    exit 0
fi

if [[ "$MODE" == "services" ]]; then
    printf '\nServices-only mode: the desktop stack and personal configuration will not be rebuilt.\n\n'
    repair_connectivity_audio
    printf '\nWi-Fi, Bluetooth, audio, and brightness persistence repaired. Log out and back in once if group membership or PipeWire changed.\n'
    exit 0
fi

if [[ "$MODE" == "mango" ]]; then
    [[ "$FLAVOUR" == "mango" ]] || die "--mango-only cannot be combined with --flavour niri"
    [[ "$DISTRO_ID" == "void" ]] || die "The Tatami/Mango flavour currently supports Void Linux only"
    choose_tatami_theme
    printf '\nMango-only mode: Niri and Noctalia files will not be changed.\n\n'
    install_mango_flavour
    finalize_setup
    exit 0
fi

# An explicit --flavour wins. Otherwise normal Void installs ask, while Fedora
# keeps the existing Niri-only behavior until Mango is supported there.
choose_flavour
[[ "$FLAVOUR" != "mango" || "$DISTRO_ID" == "void" ]] \
    || die "The Tatami/Mango flavour currently supports Void Linux only"
[[ "$FLAVOUR" == "mango" || -z "$TATAMI_THEME" ]] \
    || die "--theme applies only to the Mango flavour"
choose_tatami_theme

if [[ "$FLAVOUR" == "mango" ]]; then
    printf '\nThis installer will configure Noctiri Tatami (Mango + Waybar) on %s.\n' "$DISTRO_NAME"
else
    printf '\nThis installer will configure a Niri + Noctalia desktop on %s and install the selected app stack.\n' "$DISTRO_NAME"
fi
printf 'It DOES NOT start/restart greetd during the run, so it will not intentionally kill your current GUI session.\n\n'
if [[ "$DISTRO_ID" == "void" ]]; then
    if [[ "$FLAVOUR" == "mango" ]]; then
        printf 'Void note: the package stage performs a full XBPS upgrade, installs Mango from Void, and builds Noctalia Greeter only when absent.\n\n'
    else
        printf 'Void note: the package stage performs a full XBPS upgrade and builds Noctalia + its greeter from stable source releases.\n\n'
    fi
fi
ask_yes_no "Continue?" y || exit 0

package_step="packages-$DISTRO_ID"
config_step=configs
font_step=nerd-font
font_label="JetBrainsMono Nerd Font"
font_function=install_nerd_font
if [[ "$FLAVOUR" == "mango" ]]; then
    package_step="packages-$DISTRO_ID-mango"
    config_step=configs-mango
    font_step=iosevka-font
    font_label="IosevkaTerm Nerd Font"
    font_function=install_iosevka_font
fi

if [[ "$FLAVOUR" == "niri" ]] \
    && ! step_is_complete "$package_step" \
    && have niri && have noctalia && have noctalia-greeter \
    && ask_yes_no "An existing Niri + Noctalia + Noctalia Greeter installation was detected. Skip package installation and source builds, and save that choice?" y; then
    mark_step_complete "$package_step"
    ok "Adopted the existing desktop installation; package installation and source builds were skipped"
else
    run_stateful_step "$package_step" "System packages and desktop builds" install_packages
fi

run_stateful_step "services-$DISTRO_ID" "Wi-Fi, Bluetooth, PipeWire, and brightness persistence setup" repair_connectivity_audio
run_stateful_step "$font_step" "$font_label" "$font_function"
run_stateful_step "$config_step" "$( [[ "$FLAVOUR" == mango ]] && printf 'Tatami/Mango' || printf 'Niri/Noctalia' ) desktop configuration" install_configs
run_stateful_step firefox-policy "Firefox portal policy" merge_firefox_policy
run_stateful_step default-apps "Default application associations" set_default_apps
run_stateful_step flatpaks "Flatpak applications" install_flatpaks
run_stateful_step wallpapers "Wallpaper collections" configure_wallpapers
run_stateful_step greeter "greetd and Noctalia Greeter configuration" configure_greeter
run_stateful_step spicetify "Spicetify setup" install_spicetify
finalize_setup
