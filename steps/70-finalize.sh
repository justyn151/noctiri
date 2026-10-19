#!/usr/bin/env bash
finalize_setup() {
    log "Final checks"

    if have noctalia; then
        noctalia config validate || warn "Noctalia config validation reported an error."
    fi

    if have niri; then
        # Newer niri accepts 'validate'; older builds may require -c. Do not abort finalization.
        niri validate >/dev/null 2>&1 && ok "Niri config validates" || warn "Run 'niri validate' after logging into the new session to verify the Niri config."
    fi

    if [[ "$FLAVOUR" == "mango" ]] && have mango; then
        mango -c "$HOME/.config/mango/config.conf" -p >/dev/null 2>&1 \
            && ok "Mango config validates" \
            || warn "Mango rejected the installed config; run: mango -c ~/.config/mango/config.conf -p"
    fi

    # If a Noctalia process is already running, refresh its generated app themes.
    if pgrep -x noctalia >/dev/null 2>&1; then
        noctalia msg templates-apply >/dev/null 2>&1 || true
    fi

    # Restart portal services only if a user manager is available right now.
    if have systemctl && systemctl --user show-environment >/dev/null 2>&1; then
        systemctl --user restart plasma-xdg-desktop-portal-kde.service >/dev/null 2>&1 || true
        systemctl --user restart xdg-desktop-portal.service >/dev/null 2>&1 || true
    fi

    printf '\n\033[1;32mSetup complete.\033[0m\n'
    printf 'Backups (if any): %s\n' "$BACKUP_DIR"
    printf '\nBefore rebooting:\n'
    printf '  - If the installer warned about another display manager, resolve that first.\n'
    if [[ "$DISTRO_ID" == "void" && ! -e /var/service/greetd ]]; then
        printf '  - Void: from a TTY, enable greetd with: sudo ln -s /etc/sv/greetd /var/service/\n'
    fi
    if [[ "$FLAVOUR" == "mango" ]]; then
        printf '  - Log out and select Noctiri Tatami in the greeter; Niri remains installed and unchanged.\n'
        printf '  - Toggle Tatami day/night mode with Super+Shift+T or: noctiri-theme toggle\n'
        printf '  - Set a wallpaper with: noctiri-wallpaper /path/to/image\n'
    else
        printf '  - A logout/reboot is recommended so Niri, portals, Qt variables and greetd start cleanly.\n'
        printf '  - After first Noctalia login, use Settings -> Security -> Noctalia Greeter -> Sync Now once.\n'
        printf '  - Noctalia Auto-Sync Greeter is already enabled by the supplied config.\n'
    fi
}
