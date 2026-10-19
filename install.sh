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
    -h|--help)
        printf 'Usage: %s [--wallpapers-only | --spicetify-only]\n' "$0"
        printf '  --wallpapers-only  Install or update wallpaper collections without rerunning setup\n'
        printf '  --spicetify-only   Finish Spicetify after Spotify has created its graphical profile\n'
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

run_stateful_step nerd-font "JetBrainsMono Nerd Font" install_nerd_font
run_stateful_step configs "Desktop configuration" install_configs
run_stateful_step firefox-policy "Firefox portal policy" merge_firefox_policy
run_stateful_step default-apps "Default application associations" set_default_apps
run_stateful_step flatpaks "Flatpak applications" install_flatpaks
run_stateful_step wallpapers "Wallpaper collections" configure_wallpapers
run_stateful_step greeter "greetd and Noctalia Greeter configuration" configure_greeter
run_stateful_step spicetify "Spicetify setup" install_spicetify
finalize_setup
