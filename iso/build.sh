#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_DIR="$ROOT_DIR/iso"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/out}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.iso-work}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT_DIR/artifacts}"
FEDORA_BRANCH="${FEDORA_BRANCH:-f44}"
FEDORA_KIWI_REPO="${FEDORA_KIWI_REPO:-https://forge.fedoraproject.org/releng/fedora-kiwi-descriptions.git}"
EROFS_COMPRESSION="${EROFS_COMPRESSION:-zstd,level=3}"

if [[ $EUID -ne 0 ]]; then
    printf 'ERROR: KIWI image builds need root privileges. Run this script with sudo.\n' >&2
    exit 1
fi

for cmd in git python3 kiwi-ng; do
    command -v "$cmd" >/dev/null 2>&1 || {
        printf 'ERROR: required command not found: %s\n' "$cmd" >&2
        exit 1
    }
done

rm -rf "$WORK_DIR" "$ARTIFACT_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR" "$ARTIFACT_DIR"

printf '==> Cloning Fedora KIWI descriptions (%s)\n' "$FEDORA_BRANCH"
git clone --depth 1 --branch "$FEDORA_BRANCH" "$FEDORA_KIWI_REPO"     "$WORK_DIR/fedora-kiwi-descriptions"

DESC="$WORK_DIR/fedora-kiwi-descriptions"

printf '==> Adding Noctiri image profile\n'
install -Dm0644 "$ISO_DIR/noctiri.xml" "$DESC/teams/noctiri.xml"

python3 - "$DESC/Fedora.kiwi" "$DESC/components/liveinstall.xml" "$EROFS_COMPRESSION" <<'PY'
from pathlib import Path
import re
import sys

fedora = Path(sys.argv[1])
liveinstall = Path(sys.argv[2])
compression = sys.argv[3]

text = fedora.read_text()
include = '\t<include from="this://./teams/noctiri.xml"/>\n'
if include not in text:
    marker = '\t<packages type="bootstrap">'
    if marker not in text:
        raise SystemExit("Could not locate Fedora.kiwi bootstrap package marker")
    text = text.replace(marker, include + marker, 1)
    fedora.write_text(text)

text = liveinstall.read_text()
updated, count = re.subn(
    r'erofscompression="[^"]+"',
    f'erofscompression="{compression}"',
    text,
)
if count == 0:
    raise SystemExit("Could not locate EROFS compression setting in liveinstall.xml")

# Fedora live media ships every glibc locale by default. That costs roughly
# 238 MB installed. Noctiri's testing image only needs English and Indonesian.
all_langpacks = '<package name="glibc-all-langpacks"/>'
replacement = (
    '<package name="glibc-langpack-en"/>\n'
    '\t\t<package name="glibc-langpack-id"/>'
)
if all_langpacks not in updated:
    raise SystemExit("Could not locate glibc-all-langpacks in liveinstall.xml")
updated = updated.replace(all_langpacks, replacement, 1)

liveinstall.write_text(updated)
print(f"Using EROFS compression: {compression}")
print("Using glibc locales: en, id")
PY

printf '==> Installing Noctiri root overlay\n'
cp -a "$ISO_DIR/root/." "$DESC/root/"

# Ship the same configuration sources used by the normal installer.
share="$DESC/root/usr/share/noctiri/configs"
mkdir -p "$share"/{niri,noctalia,kitty,qt6ct,kde,portals,systemd,greetd}
cp "$ROOT_DIR/configs/niri/config.kdl.in" "$share/niri/config.kdl.in"
cp "$ROOT_DIR/configs/noctalia/config.toml.in" "$share/noctalia/config.toml.in"
cp "$ROOT_DIR/configs/kitty/kitty.conf" "$share/kitty/kitty.conf"
cp "$ROOT_DIR/configs/qt6ct/qt6ct.conf.in" "$share/qt6ct/qt6ct.conf.in"
cp "$ROOT_DIR/configs/kde/kdeglobals" "$share/kde/kdeglobals"
cp "$ROOT_DIR/configs/portals/niri-portals.conf" "$share/portals/niri-portals.conf"
cp "$ROOT_DIR/configs/systemd/kde-portal-override.conf" "$share/systemd/kde-portal-override.conf"
cp "$ROOT_DIR/configs/greetd/config.toml" "$share/greetd/config.toml"

# The live image uses the same greetd config after installation.
install -Dm0644 "$ROOT_DIR/configs/greetd/config.toml"     "$DESC/root/etc/greetd/config.toml"

chmod 0755     "$DESC/root/usr/libexec/noctiri-first-login"     "$DESC/root/usr/bin/noctiri-session"

printf '==> Fetching JetBrainsMono Nerd Font for the live image\n'
font_tmp="$WORK_DIR/JetBrainsMono.tar.xz"
curl -fL --retry 3     -o "$font_tmp"     https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
mkdir -p "$DESC/root/usr/share/fonts/noctiri/JetBrainsMonoNerd"
tar -xf "$font_tmp" -C "$DESC/root/usr/share/fonts/noctiri/JetBrainsMonoNerd"

printf '==> Building Noctiri live ISO\n'
cd "$DESC"
./kiwi-build     --kiwi-file=Fedora.kiwi     --image-type=iso     --image-profile=Noctiri-Live     --output-dir="$OUT_DIR/noctiri"

iso_file="$(find "$OUT_DIR/noctiri-build" -maxdepth 1 -type f -name '*.iso' -print -quit)"
[[ -n "$iso_file" ]] || {
    printf 'ERROR: KIWI completed but no ISO was found in %s\n' "$OUT_DIR/noctiri-build" >&2
    exit 1
}

artifact="$ARTIFACT_DIR/Noctiri-Fedora-44-x86_64.iso"
install -m 0644 "$iso_file" "$artifact"

printf '\nBuild finished. ISO artifact:\n  %s\n' "$artifact"
