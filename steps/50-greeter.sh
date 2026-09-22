#!/usr/bin/env bash
configure_greeter() {
    log "Configuring greetd + Noctalia Greeter"
    if [[ -e /etc/greetd/config.toml ]]; then
        mkdir -p "$BACKUP_DIR/etc/greetd"
        sudo cp -a /etc/greetd/config.toml "$BACKUP_DIR/etc/greetd/config.toml"
    fi
    sudo install -Dm0644 "$ROOT_DIR/configs/greetd/config.toml" /etc/greetd/config.toml

    if have noctalia-greeter-apply-appearance; then
        sudo noctalia-greeter-apply-appearance --setup-system
    else
        warn "noctalia-greeter-apply-appearance was not found after installation."
    fi

    if have noctalia-greeter; then
        sudo noctalia-greeter passwordless-sync enable "$USER" || warn "Could not enable passwordless greeter appearance sync."
    fi

    # Do not start/restart greetd here: that can kill an active graphical session.
    sudo systemctl enable greetd.service
    sudo systemctl set-default graphical.target

    local dm_link dm_target
    dm_link=/etc/systemd/system/display-manager.service
    if [[ -L "$dm_link" ]]; then
        dm_target="$(basename "$(readlink -f "$dm_link")")"
        if [[ "$dm_target" != "greetd.service" ]]; then
            warn "Another display manager is currently selected: $dm_target"
            warn "Do not enable two display managers at once. Review it before rebooting."
        fi
    fi
}
