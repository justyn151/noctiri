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
        enable_passwordless_greeter_sync
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

enable_passwordless_greeter_sync() {
    local output
    if output="$(sudo noctalia-greeter passwordless-sync enable "$USER" 2>&1)"; then
        printf '%s\n' "$output"
        return 0
    fi

    # Void deliberately owns /etc/polkit-1/rules.d as polkitd:polkitd (0700).
    # Noctalia Greeter validates its helper, policy, and pkexec before rejecting
    # that directory ownership, so this exact failure can safely use the
    # upstream-documented manual rule instead.
    if [[ "$DISTRO_ID" == "void" \
        && "$output" == *"Polkit rules must use a root-owned, non-user-writable directory chain"* ]]; then
        warn "Noctalia Greeter's rule manager is incompatible with Void's Polkit directory ownership; installing the constrained rule directly."
        install_void_passwordless_greeter_sync_rule
        return
    fi

    printf '%s\n' "$output" >&2
    warn "Could not enable passwordless greeter appearance sync."
}

install_void_passwordless_greeter_sync_rule() {
    local helper rule_path tmp backup_file
    helper="$(readlink -f "$(command -v noctalia-greeter-apply-appearance)")"
    rule_path=/etc/polkit-1/rules.d/49-noctiri-noctalia-greeter-sync.rules
    tmp="$(mktemp)"

    LOGIN_USER="$USER" HELPER_PATH="$helper" python3 - <<'PY' > "$tmp"
import json
import os

user = json.dumps(os.environ["LOGIN_USER"])
helper = json.dumps(os.environ["HELPER_PATH"])

print(f"""// Installed by the Noctiri setup for Void Linux.
polkit.addRule(function (action, subject) {{
  var allowedUsers = [{user}];

  if (
    action.id == "org.noctalia.greeter.sync-appearance" &&
    action.lookup("program") == {helper} &&
    action.lookup("user") == "root" &&
    subject.local &&
    subject.active &&
    allowedUsers.indexOf(subject.user) >= 0
  ) {{
    return polkit.Result.YES;
  }}
}});
""")
PY

    if sudo test -L "$rule_path"; then
        rm -f "$tmp"
        warn "Refusing to replace symlinked Polkit rule: $rule_path"
        return 1
    fi
    if sudo test -e "$rule_path"; then
        backup_file="$BACKUP_DIR/${rule_path#/}"
        mkdir -p "$(dirname "$backup_file")"
        sudo cat -- "$rule_path" > "$backup_file"
    fi

    sudo install -o root -g root -m 0644 "$tmp" "$rule_path"
    rm -f "$tmp"
    ok "Enabled constrained passwordless greeter appearance sync for $USER"
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
