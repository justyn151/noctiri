#!/usr/bin/env bash
checks() {
    [[ $EUID -ne 0 ]] || die "Run ./install.sh as your normal user, not with sudo. The installer asks for sudo only when needed."
    [[ -r /etc/os-release ]] || die "Cannot identify this operating system."
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_ID="${ID:-}"
    DISTRO_NAME="${PRETTY_NAME:-unknown Linux distribution}"

    case "$DISTRO_ID" in
        fedora)
            local major="${VERSION_ID%%.*}"
            [[ "$major" =~ ^[0-9]+$ ]] || die "Could not parse Fedora VERSION_ID=$VERSION_ID"
            (( major >= 44 )) || die "Fedora 44 or newer is required; detected Fedora $major."
            if (( major != 44 )); then
                warn "This setup was built and verified against Fedora 44. Fedora $major may have package/config differences."
            fi
            GREETER_USER="greetd"
            ;;
        void)
            have xbps-install || die "Void Linux was detected, but xbps-install is unavailable."
            GREETER_USER="_greeter"
            ;;
        *)
            die "This installer supports Fedora 44+ and Void Linux; detected $DISTRO_NAME."
            ;;
    esac

    mkdir -p "$BACKUP_ROOT"
    log "Distribution: $DISTRO_NAME"
    log "Target user: $USER ($HOME)"
    log "Backups for replaced files: $BACKUP_DIR"
}
