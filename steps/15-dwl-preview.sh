#!/usr/bin/env bash

DWL_REPOSITORY="https://github.com/BreadOnPenguins/dwl.git"
DWL_COMMIT="4e39b9ba98cead96fae354f192bbee057aa38d84"
SOMEBAR_REPOSITORY="https://git.sr.ht/~raphi/somebar"
SOMEBAR_COMMIT="6572b98d697fef50473366bf4b598e66c0be3e54"
SOMEBLOCKS_REPOSITORY="https://git.sr.ht/~raphi/someblocks"
SOMEBLOCKS_COMMIT="540a90e521e7c17c2010e038b934b73d2cf46df3"

clone_pinned_dwl_component() {
    local repository="$1" commit="$2" destination="$3" label="$4"
    log "Fetching $label"
    git clone --quiet "$repository" "$destination"
    git -C "$destination" checkout --quiet --detach "$commit"
    [[ "$(git -C "$destination" rev-parse HEAD)" == "$commit" ]] \
        || die "$label did not resolve to the pinned revision"
}

install_dwl_preview_packages_void() {
    log "Installing the Void build and runtime dependencies for the DWL preview"
    local packages=(
        base-devel git pkg-config
        wlroots0.19-devel wayland-devel wayland-protocols
        libinput-devel libxkbcommon-devel
        meson ninja cairo-devel pango-devel
        foot swaybg wmenu liberation-fonts-ttf
    )
    sudo xbps-install -Sy "${packages[@]}"
}

build_dwl_preview() {
    local build_root="$1"
    local dwl_source="$build_root/dwl"
    local somebar_source="$build_root/somebar"
    local someblocks_source="$build_root/someblocks"

    clone_pinned_dwl_component "$DWL_REPOSITORY" "$DWL_COMMIT" \
        "$dwl_source" "BreadOnPenguins' DWL fork"
    install -m 0644 "$ROOT_DIR/configs/dwl/config.h" "$dwl_source/config.h"
    log "Building DWL against wlroots 0.19"
    make -C "$dwl_source"

    clone_pinned_dwl_component "$SOMEBAR_REPOSITORY" "$SOMEBAR_COMMIT" \
        "$somebar_source" "Somebar"
    install -m 0644 "$ROOT_DIR/configs/dwl/somebar-config.hpp" \
        "$somebar_source/src/config.hpp"
    log "Building Somebar"
    meson setup "$somebar_source/build" "$somebar_source"
    ninja -C "$somebar_source/build"

    clone_pinned_dwl_component "$SOMEBLOCKS_REPOSITORY" "$SOMEBLOCKS_COMMIT" \
        "$someblocks_source" "Someblocks"
    install -m 0644 "$ROOT_DIR/configs/dwl/blocks.h" "$someblocks_source/blocks.h"
    log "Building Someblocks"
    make -C "$someblocks_source"

    sudo install -Dm0755 "$dwl_source/dwl" /usr/local/bin/dwl
    sudo install -Dm0644 "$dwl_source/dwl.1" /usr/local/share/man/man1/dwl.1
    sudo install -Dm0755 "$somebar_source/build/somebar" /usr/local/bin/somebar
    sudo install -Dm0755 "$someblocks_source/someblocks" /usr/local/bin/someblocks
}

install_dwl_preview_configs() {
    log "Installing the Foot, Somebar, and DWL preview configuration"
    install_user_path
    install_file "$ROOT_DIR/configs/dwl/foot.ini" "$HOME/.config/foot/foot.ini"
    install_file "$ROOT_DIR/configs/dwl/autostart.sh" \
        "$HOME/.config/dwl/autostart.sh" 0755
    install_file "$ROOT_DIR/configs/dwl/noctiri-dwl-status" \
        "$HOME/.local/bin/noctiri-dwl-status" 0755

    sudo install -Dm0755 "$ROOT_DIR/configs/dwl/noctiri-dwl-session" \
        /usr/local/bin/noctiri-dwl-session
    sudo install -Dm0644 "$ROOT_DIR/configs/dwl/noctiri-dwl.desktop" \
        /usr/share/wayland-sessions/noctiri-dwl.desktop
    fc-cache -f >/dev/null 2>&1 || true
}

verify_dwl_preview() {
    local command
    for command in dwl somebar someblocks foot swaybg wmenu-run; do
        have "$command" || die "DWL preview verification failed: $command is unavailable"
    done
    [[ -x "$HOME/.config/dwl/autostart.sh" ]] \
        || die "DWL preview verification failed: autostart is not executable"
    [[ -f /usr/share/wayland-sessions/noctiri-dwl.desktop ]] \
        || die "DWL preview verification failed: greetd session entry is missing"
    fc-match 'Liberation Mono' | grep -qi 'LiberationMono' \
        || warn "Fontconfig did not resolve Liberation Mono; Foot may use a fallback font."
    if ! id -nG "$USER" | tr ' ' '\n' | grep -Fxq _seatd; then
        warn "$USER is not in the _seatd group. Run the full installer once before starting DWL."
    fi
    ok "DWL, Foot, Somebar, Someblocks, and Liberation Mono are installed"
}

install_dwl_preview() {
    [[ "$DISTRO_ID" == "void" ]] \
        || die "The initial DWL preview is currently supported on Void Linux only"

    install_dwl_preview_packages_void

    local build_root
    build_root="$(mktemp -d "${TMPDIR:-/tmp}/noctiri-dwl.XXXXXX")"
    log "Using temporary DWL build directory: $build_root"
    build_dwl_preview "$build_root"
    install_dwl_preview_configs
    verify_dwl_preview
    rm -rf -- "$build_root"
}
