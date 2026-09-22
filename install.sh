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

checks
printf '\nThis installer will configure a Fedora 44+ Niri + Noctalia desktop and install the selected app stack.\n'
printf 'It DOES NOT start/restart greetd during the run, so it will not intentionally kill your current GUI session.\n\n'
ask_yes_no "Continue?" y || exit 0

install_packages
install_nerd_font
install_configs
merge_firefox_policy
set_default_apps
install_flatpaks
configure_wallpapers
configure_greeter
install_spicetify
finalize_setup
