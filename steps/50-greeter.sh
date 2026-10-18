#!/usr/bin/env bash
configure_greeter() {
    log "Configuring greetd + Noctalia Greeter"
    if [[ -e /etc/greetd/config.toml ]]; then
        mkdir -p "$BACKUP_DIR/etc/greetd"
        sudo cp -a /etc/greetd/config.toml "$BACKUP_DIR/etc/greetd/config.toml"
    fi
    local tmp
    tmp="$(mktemp)"
    sed "s|@@GREETER_USER@@|$GREETER_USER|g" "$ROOT_DIR/configs/greetd/config.toml.in" > "$tmp"
    sudo install -Dm0644 "$tmp" /etc/greetd/config.toml
    rm -f "$tmp"

    if have noctalia-greeter-apply-appearance; then
        sudo env GREETER_USER="$GREETER_USER" noctalia-greeter-apply-appearance --setup-system
    else
        warn "noctalia-greeter-apply-appearance was not found after installation."
    fi

    if have noctalia-greeter; then
        sudo noctalia-greeter passwordless-sync enable "$USER" || warn "Could not enable passwordless greeter appearance sync."
    fi

    # Do not start/restart greetd here: that can kill an active graphical session.
    if [[ "$DISTRO_ID" == "fedora" ]]; then
        sudo systemctl enable greetd.service
        sudo systemctl set-default graphical.target
    else
        configure_greeter_void_service
    fi

    local dm_link dm_target
    dm_link=/etc/systemd/system/display-manager.service
    if [[ "$DISTRO_ID" == "fedora" && -L "$dm_link" ]]; then
        dm_target="$(basename "$(readlink -f "$dm_link")")"
        if [[ "$dm_target" != "greetd.service" ]]; then
            warn "Another display manager is currently selected: $dm_target"
            warn "Do not enable two display managers at once. Review it before rebooting."
        fi
    fi
}

configure_greeter_void_service() {
    local service
    for service in gdm sddm lightdm lxdm; do
        if [[ -e "/var/service/$service" ]]; then
            warn "Another display manager is enabled through runit: $service"
            warn "Disable it before enabling greetd; do not run two display managers together."
        fi
    done

    if [[ -e /var/service/greetd ]]; then
        ok "greetd is already enabled in runit; it was not restarted"
    else
        warn "Void runit starts services as soon as they are enabled, so greetd was not enabled automatically."
        warn "From a TTY when ready, run: sudo ln -s /etc/sv/greetd /var/service/"
    fi
}
