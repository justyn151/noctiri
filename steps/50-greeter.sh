#!/usr/bin/env bash
configure_greeter() {
    log "Configuring greetd + Noctalia Greeter"
    if [[ -e /etc/greetd/config.toml ]]; then
        mkdir -p "$BACKUP_DIR/etc/greetd"
        sudo cp -a /etc/greetd/config.toml "$BACKUP_DIR/etc/greetd/config.toml"
    fi
    local tmp
    tmp="$(mktemp)"
    local greeter_session=niri
    if [[ "$DISTRO_ID" == "void" && -f /usr/share/wayland-sessions/noctiri.desktop ]]; then
        greeter_session=noctiri
    fi
    sed -e "s|@@GREETER_USER@@|$GREETER_USER|g" \
        -e "s|@@GREETER_SESSION@@|$greeter_session|g" \
        "$ROOT_DIR/configs/greetd/config.toml.in" > "$tmp"
    sudo install -Dm0644 "$tmp" /etc/greetd/config.toml
    rm -f "$tmp"

    if have noctalia-greeter-apply-appearance; then
        sudo env GREETER_USER="$GREETER_USER" noctalia-greeter-apply-appearance --setup-system
    else
        warn "noctalia-greeter-apply-appearance was not found after installation."
    fi

    if have noctalia-greeter; then
        pin_greeter_session "$greeter_session"
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

set_toml_table_value() {
    local input_file="$1" output_file="$2" table="$3" key="$4" value="$5"
    python3 - "$input_file" "$output_file" "$table" "$key" "$value" <<'PY'
import json
import pathlib
import re
import sys

input_path, output_path, table, key, value = sys.argv[1:]
text = pathlib.Path(input_path).read_text(encoding="utf-8")
lines = text.splitlines()
header_pattern = re.compile(r"^\s*\[([^]]+)]\s*(?:#.*)?$")
key_pattern = re.compile(rf"^(\s*){re.escape(key)}\s*=.*$")

section_start = None
section_end = len(lines)
for index, line in enumerate(lines):
    match = header_pattern.match(line)
    if not match:
        continue
    if section_start is not None:
        section_end = index
        break
    if match.group(1).strip() == table:
        section_start = index

assignment = f"{key} = {json.dumps(value)}"
if section_start is None:
    if lines and lines[-1].strip():
        lines.append("")
    lines.extend((f"[{table}]", assignment))
else:
    for index in range(section_start + 1, section_end):
        match = key_pattern.match(lines[index])
        if match:
            lines[index] = match.group(1) + assignment
            break
    else:
        lines.insert(section_end, assignment)

pathlib.Path(output_path).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

set_protected_greeter_toml_value() {
    local path="$1" key="$2" value="$3" greeter_group tmp_dir input_file output_file backup_file
    greeter_group="$(id -gn "$GREETER_USER")"
    tmp_dir="$(mktemp -d)"
    input_file="$tmp_dir/input.toml"
    output_file="$tmp_dir/output.toml"

    if sudo test -L "$path"; then
        rm -rf "$tmp_dir"
        warn "Refusing to replace symlinked Noctalia Greeter state: $path"
        return 1
    fi
    if sudo test -e "$path"; then
        sudo cat -- "$path" > "$input_file"
        backup_file="$BACKUP_DIR/${path#/}"
        mkdir -p "$(dirname "$backup_file")"
        sudo cat -- "$path" > "$backup_file"
    else
        : > "$input_file"
    fi

    set_toml_table_value "$input_file" "$output_file" session "$key" "$value"
    sudo install -o "$GREETER_USER" -g "$greeter_group" -m 0640 "$output_file" "$path"
    rm -rf "$tmp_dir"
}

pin_greeter_session() {
    local requested_session="$1" selected_session sessions
    sessions="$(noctalia-greeter sessions 2>/dev/null || true)"
    selected_session="$(printf '%s\n' "$sessions" \
        | awk -v target="$requested_session" 'tolower($0) == tolower(target) { print; exit }')"
    [[ -n "$selected_session" ]] \
        || die "Noctalia Greeter cannot find the $requested_session session in /usr/share/wayland-sessions/."

    set_protected_greeter_toml_value /var/lib/noctalia-greeter/greeter.toml default "$selected_session"
    # Also repair the remembered value because Greeter 1.5 has an open bug where
    # session.last can override both the CLI and administrator default.
    set_protected_greeter_toml_value /var/lib/noctalia-greeter/sync.toml last "$selected_session"
    ok "Pinned Noctalia Greeter's startup session to $selected_session"
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
