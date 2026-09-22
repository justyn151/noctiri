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

    # If a Noctalia process is already running, refresh its generated app themes.
    if pgrep -x noctalia >/dev/null 2>&1; then
        noctalia msg templates-apply >/dev/null 2>&1 || true
    fi

    # Restart portal services only if a user manager is available right now.
    if systemctl --user show-environment >/dev/null 2>&1; then
        systemctl --user restart plasma-xdg-desktop-portal-kde.service >/dev/null 2>&1 || true
        systemctl --user restart xdg-desktop-portal.service >/dev/null 2>&1 || true
    fi

    printf '\n\033[1;32mSetup complete.\033[0m\n'
    printf 'Backups (if any): %s\n' "$BACKUP_DIR"
    printf '\nBefore rebooting:\n'
    printf '  - If the installer warned about another display manager, resolve that first.\n'
    printf '  - A logout/reboot is recommended so Niri, portals, Qt variables and greetd start cleanly.\n'
    printf '  - After first Noctalia login, use Settings -> Security -> Noctalia Greeter -> Sync Now once.\n'
    printf '  - Noctalia Auto-Sync Greeter is already enabled by the supplied config.\n'
}
