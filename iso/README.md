# Noctiri Live ISO

This directory contains the experimental Fedora KIWI live-image build for Noctiri.

## What the ISO does

- boots a Fedora live environment into the Noctiri Niri + Noctalia session
- carries the same portable Niri, Noctalia, Kitty, Qt and portal configuration as the normal installer
- includes Anaconda live-install support
- uses SDDM only for live-media autologin
- switches the installed system to greetd + Noctalia Greeter in an Anaconda post-install script
- does **not** bake Spotify, Vesktop, Spicetify, or the optional wallpaper repositories into the ISO

The normal `install.sh` remains the supported path for configuring an existing Fedora installation.

## Local build

The build host should be Fedora and needs KIWI plus its system dependencies:

```bash
sudo dnf install kiwi kiwi-systemdeps distribution-gpg-keys git curl
sudo FEDORA_BRANCH=f44 bash iso/build.sh
```

The result is written under `out/`.

The script clones Fedora's current KIWI descriptions from Fedora Forge and adds the Noctiri profile and root overlay before invoking Fedora's own `kiwi-build` wrapper.

## GitHub Actions

The `Build Noctiri Live ISO` workflow can be started manually from the Actions tab. Tagged versions matching `v*` also trigger a build.

The GitHub-hosted build runs KIWI inside a privileged Fedora container. This is convenient CI, but the live image should still be tested in a VM and on real hardware before publishing it as a release.

## First-login configuration

The image ships configuration templates in `/usr/share/noctiri/configs`.

The custom `Noctiri` Wayland session runs `noctiri-first-login` before starting Niri, rendering any paths that depend on the target user's home directory. An XDG autostart entry provides the same initialization for later user accounts.

## Current scope

The ISO path is experimental. It intentionally avoids bundling optional third-party user content such as wallpaper repositories and post-login applications that are better handled by the normal interactive installer.
