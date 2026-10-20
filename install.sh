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
    --firefox-only) MODE=firefox ;;
    --zsh-only) MODE=zsh ;;
    --dwl-only) MODE=dwl ;;
    --font-only) MODE=font ;;
    --documents-only) MODE=documents ;;
    -h|--help)
        printf 'Usage: %s [--wallpapers-only | --spicetify-only | --greeter-only | --void-runtime-only | --theme-only | --services-only | --firefox-only | --zsh-only | --dwl-only | --font-only | --documents-only]\n' "$0"
        printf '  --wallpapers-only  Install or update wallpaper collections without rerunning setup\n'
        printf '  --spicetify-only   Install Spotify if needed, then finish Spicetify setup\n'
        printf '  --greeter-only     Repair greetd/Noctalia Greeter configuration without rebuilding\n'
        printf '  --void-runtime-only  Repair Void graphics and seat services without rebuilding\n'
        printf '  --theme-only       Repair Noctalia app colors and bar clocks without rebuilding\n'
        printf '  --services-only    Repair Wi-Fi, Bluetooth, PipeWire, and brightness persistence\n'
        printf '  --firefox-only     Install Firefox policies, extensions, and Noctalia theming\n'
        printf '  --zsh-only         Install Zsh, suggestions/highlighting, and smooth Kitty cursor settings\n'
        printf '  --dwl-only         Install the optional Void DWL + Foot + Somebar preview\n'
        printf '  --font-only        Install and apply Fantasque Sans Mono across the desktop\n'
        printf '  --documents-only   Install Sioyek, CoC/TexLab, and compact Tectonic LaTeX support\n'
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
    install_fantasque_system_font
    repair_theme_sync
    pywalfox_status=0
    configure_pywalfox || pywalfox_status=$?
    (( pywalfox_status == 0 || pywalfox_status == STEP_DEFERRED )) || exit "$pywalfox_status"
    printf '\nColors, bar clocks, and Firefox theming repaired. Restart open applications to reload their palettes.\n'
    exit 0
fi

if [[ "$MODE" == "font" ]]; then
    printf '\nFont-only mode: installing and applying Fantasque Sans Mono without rebuilding the desktop.\n\n'
    install_fantasque_system_font
    printf '\n\033[1;32mFantasque Sans Mono configuration complete.\033[0m\n'
    printf 'Reopen applications to refresh their fonts; log out once to refresh the complete session.\n'
    exit 0
fi

if [[ "$MODE" == "documents" ]]; then
    printf '\nDocuments-only mode: installing Sioyek, CoC/TexLab, and compact on-demand LaTeX support.\n\n'
    install_document_stack
    install_neovim_integration
    set_pdf_default
    printf '\n\033[1;32mDocument setup complete.\033[0m\n'
    printf 'In a complete TeX buffer, save to compile and open the refreshed PDF in Sioyek.\n'
    exit 0
fi

if [[ "$MODE" == "services" ]]; then
    printf '\nServices-only mode: the desktop stack and personal configuration will not be rebuilt.\n\n'
    repair_connectivity_audio
    if [[ "$DISTRO_ID" == "void" ]]; then
        run_stateful_step networkmanager-handoff-void-v1 \
            "Void NetworkManager handoff" finish_void_networkmanager_handoff true
    fi
    printf '\nWi-Fi, Bluetooth, audio, and brightness persistence repaired. Log out and back in once if group membership or PipeWire changed.\n'
    exit 0
fi

if [[ "$MODE" == "firefox" ]]; then
    printf '\nFirefox-only mode: configuring the portal, extensions, and Noctalia theme integration.\n\n'
    merge_firefox_policy
    pywalfox_status=0
    configure_pywalfox || pywalfox_status=$?
    (( pywalfox_status == 0 || pywalfox_status == STEP_DEFERRED )) || exit "$pywalfox_status"
    printf '\nFirefox setup complete. Fully close and reopen Firefox once to load the policy.\n'
    exit 0
fi

if [[ "$MODE" == "zsh" ]]; then
    printf '\nZsh-only mode: installing Zsh, completions, and Kitty cursor settings without changing the desktop stack.\n\n'
    install_zsh_shell
    printf '\nZsh setup complete. Start it now with zsh; log out once to make it the login shell everywhere.\n'
    exit 0
fi

if [[ "$MODE" == "dwl" ]]; then
    printf '\nDWL preview mode: Niri and Noctalia will not be changed or rebuilt.\n'
    printf 'A separate greeter session will be installed; your existing default session is preserved.\n\n'
    install_dwl_preview
    printf '\n\033[1;32mDWL preview installation complete.\033[0m\n'
    printf 'Log out normally, then select "DWL (Noctiri Preview)" in the greeter.\n'
    printf 'DWL is intentionally not started or made the default by this installer.\n'
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

run_stateful_step "services-core-v2-$DISTRO_ID" "Bluetooth, PipeWire, and brightness persistence setup" repair_connectivity_audio
if [[ "$DISTRO_ID" == "void" ]] && ! step_is_complete greeter-panel-blur-v3; then
    run_stateful_step greeter-panel-blur-v3 \
        "Noctalia Greeter animation and glass-effect build" install_noctalia_greeter_void
fi
run_stateful_step fantasque-system-font-v1 "Fantasque Sans Mono system font" install_fantasque_system_font
run_stateful_step neovim-editor-v3 "Neovim, CoC runtime, beam cursor, and Vim removal" install_neovim_editor
run_stateful_step document-stack-v2 "Sioyek, TexLab, and compact on-demand LaTeX support" install_document_stack
run_stateful_step zsh-ohmyzsh-v2 "Zsh, Oh My Zsh, suggestions, and highlighting" install_zsh_shell
run_stateful_step configs-v4 "Desktop configuration" install_configs
run_stateful_step firefox-policy-v4 "Firefox portal and extension policy" merge_firefox_policy
run_stateful_step pywalfox "Noctalia Pywalfox native host" configure_pywalfox
run_stateful_step default-apps-v2 "Default application associations" set_default_apps
run_stateful_step flatpaks "Flatpak applications" install_flatpaks
run_stateful_step wallpapers "Wallpaper collections" configure_wallpapers
run_stateful_step greeter-v2 "greetd and animated Noctalia Greeter configuration" configure_greeter
run_stateful_step spicetify "Spicetify setup" install_spicetify
if [[ "$DISTRO_ID" == "void" ]]; then
    run_stateful_step networkmanager-handoff-void-v1 \
        "Void NetworkManager handoff" finish_void_networkmanager_handoff
fi
finalize_setup
