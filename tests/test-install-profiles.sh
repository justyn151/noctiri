#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=../lib/profiles.sh
source "$ROOT_DIR/lib/profiles.sh"

assert_has() {
    local profile="$1" feature="$2"
    INSTALL_PROFILE="$profile"
    profile_has "$feature" \
        || die "$profile should include $feature"
}

assert_lacks() {
    local profile="$1" feature="$2"
    INSTALL_PROFILE="$profile"
    if profile_has "$feature"; then
        die "$profile should exclude $feature"
    fi
}

assert_has minimal core
for feature in editor documents music zsh utilities desktop-apps flatpaks wallpapers spicetify gaming; do
    assert_lacks minimal "$feature"
done

for feature in core editor documents music zsh utilities desktop-apps flatpaks wallpapers spicetify; do
    assert_has standard "$feature"
done
assert_lacks standard gaming

for feature in core editor documents music zsh utilities desktop-apps flatpaks wallpapers spicetify gaming; do
    assert_has full "$feature"
done

profile_output="$($ROOT_DIR/install.sh --list-profiles)"
grep -Fq '1. Minimal' <<< "$profile_output"
grep -Fq '2. Standard (recommended)' <<< "$profile_output"
grep -Fq '3. Full' <<< "$profile_output"
if "$ROOT_DIR/install.sh" --profile minimal --doctor >/dev/null 2>&1; then
    die '--profile unexpectedly combined with a repair mode'
fi

printf 'Installer profile tests passed.\n'
