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

MODE=full
case "${1:-}" in
    "") ;;
    --wallpapers-only) MODE=wallpapers ;;
    --spicetify-only) MODE=spicetify ;;
    --greeter-only) MODE=greeter ;;
    --void-runtime-only) MODE=void-runtime ;;
    --theme-only) MODE=theme ;;
    --services-only) MODE=services ;;
    -h|--help)
        printf 'Usage: %s [--wallpapers-only | --spicetify-only | --greeter-only | --void-runtime-only | --theme-only | --services-only]\n' "$0"
        printf '  --wallpapers-only  Install or update wallpaper collections without rerunning setup\n'
        printf '  --spicetify-only   Finish Spicetify after Spotify has created its graphical profile\n'
        printf '  --greeter-only     Repair greetd/Noctalia Greeter configuration without rebuilding\n'
        printf '  --void-runtime-only  Repair Void graphics and seat services without rebuilding\n'
        printf '  --theme-only       Repair Noctalia app colors and bar clocks without rebuilding\n'
        printf '  --services-only    Repair Wi-Fi, Bluetooth, PipeWire, and brightness persistence\n'
        exit 0
        ;;
    *) die "Unknown option: $1 (try --help)" ;;
esac

checks

if [[ "$MODE" == "wallpapers" ]]; then
    printf '\nWallpaper-only mode: package installation, source builds, configs, greeter, and apps will be skipped.\n\n'
    configure_wallpapers
    mark_step_complete wallpapers
    printf '\n\033[1;32mWallpaper update complete.\033[0m\n'
    printf 'Choose or refresh the wallpaper in Noctalia if the running session does not notice it automatically.\n'
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
    repair_theme_sync
    printf '\nColors and bar clocks repaired. Restart any open KDE/Qt applications to reload their palette.\n'
    exit 0
fi

if [[ "$MODE" == "services" ]]; then
    printf '\nServices-only mode: the desktop stack and personal configuration will not be rebuilt.\n\n'
    repair_connectivity_audio
    printf '\nWi-Fi, Bluetooth, audio, and brightness persistence repaired. Log out and back in once if group membership or PipeWire changed.\n'
    exit 0
fi

printf '\nThis installer will configure a Niri + Noctalia desktop on %s and install the selected app stack.\n' "$DISTRO_NAME"
printf 'It DOES NOT start/restart greetd during the run, so it will not intentionally kill your current GUI session.\n\n'
if [[ "$DISTRO_ID" == "void" ]]; then
    printf 'Void note: when selected, the package stage performs a full XBPS upgrade and builds Noctalia + its greeter from stable source releases.\n\n'
fi
ask_yes_no "Continue?" y || exit 0

package_step="packages-$DISTRO_ID"
if ! step_is_complete "$package_step" \
    && have niri && have noctalia && have noctalia-greeter \
    && ask_yes_no "An existing Niri + Noctalia + Noctalia Greeter installation was detected. Skip package installation and source builds, and save that choice?" y; then
    mark_step_complete "$package_step"
    ok "Adopted the existing desktop installation; package installation and source builds were skipped"
else
    run_stateful_step "$package_step" "System packages and desktop builds" install_packages
fi

run_stateful_step "services-$DISTRO_ID" "Wi-Fi, Bluetooth, PipeWire, and brightness persistence setup" repair_connectivity_audio
run_stateful_step nerd-font "JetBrainsMono Nerd Font" install_nerd_font
run_stateful_step configs "Desktop configuration" install_configs
run_stateful_step firefox-policy "Firefox portal policy" merge_firefox_policy
run_stateful_step default-apps "Default application associations" set_default_apps
run_stateful_step flatpaks "Flatpak applications" install_flatpaks
run_stateful_step wallpapers "Wallpaper collections" configure_wallpapers
run_stateful_step greeter "greetd and Noctalia Greeter configuration" configure_greeter
run_stateful_step spicetify "Spicetify setup" install_spicetify
finalize_setup
