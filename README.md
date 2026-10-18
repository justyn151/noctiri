# Fedora / Void Linux Niri + Noctalia Setup

A reproducible Niri + Noctalia installer for Fedora 44+ and Void Linux (glibc or musl),
built from a working Fedora configuration.

## What it installs

Core desktop:
- Niri
- Noctalia
- greetd + Noctalia Greeter
- XWayland Satellite
- PipeWire + WirePlumber
- XDG portals (GNOME + GTK + KDE)
- Polkit and GNOME Keyring PAM integration

Theme/integration:
- Bibata Modern Ice cursor
- Inter UI font
- JetBrainsMono Nerd Font Mono for Kitty
- qt6ct + Breeze Qt style/icons
- Noctalia built-in templates: `btop`, `cava`, `kcolorscheme`, `kitty`, `niri`
- KDE file picker through `xdg-desktop-portal-kde`
- Firefox policy forcing the XDG portal file picker

Apps:
- Firefox
- Kitty
- Vim (with the included VimTeX/FZF configuration)
- Dolphin + Ark
- fooyin
- btop
- cava
- fastfetch
- qimgv
- mpv
- Zathura + MuPDF backend
- qpwgraph
- Spotify (Flatpak)
- Vesktop (Flatpak)
- Spicetify + Marketplace (optional interactive stage)

Default media associations are set to qimgv for common images, mpv for common videos,
fooyin for common audio types, and Zathura for PDF.

## Wallpapers

Wallpaper downloads are optional. The installer lets you choose any subset of:
1. https://github.com/sewergweller/walls
2. https://github.com/AbegAshford/rice-walls
3. https://github.com/na-ive/wallpapers
4. https://github.com/makccr/wallpapers
5. https://github.com/krishna4a6av/Wallpapers

You can also choose all or skip wallpapers entirely.

## Run

Do **not** run the whole installer with sudo. Run it as your normal user:

```bash
chmod +x install.sh
./install.sh
```

The script detects the distribution from `/etc/os-release` and requests sudo only for system
packages/configuration. On Void, it performs a full XBPS update first because partial upgrades are
unsupported, then builds the latest stable Noctalia and Noctalia Greeter releases from source.

## Important behavior

- Existing config files that the installer replaces are copied to
  `~/.local/state/niri-noctalia-installer-backup/<timestamp>/` first.
- The installer is designed to be safe to rerun.
- Noctalia GUI state (`~/.local/state/noctalia/settings.toml`) is backed up and removed,
  because GUI state overrides declarative config files.
- On Fedora, the installer enables greetd and sets `graphical.target`, but deliberately does **not**
  start/restart greetd during installation.
- On Void, enabling a runit service starts it immediately. The installer therefore configures
  greetd but leaves activation to you. From a TTY, after resolving any display-manager warning, run
  `sudo ln -s /etc/sv/greetd /var/service/`.
- If another display manager is configured, the installer warns instead of blindly disabling it.

## Spotify / Spicetify

Spotify is installed from Flathub. A fresh Spotify profile must be opened and logged into once
before Spicetify can patch it. The installer pauses at that stage, launches Spotify, and waits for
you to return. You may skip the patch stage and rerun the installer later.

`tar` is installed before Spicetify because the upstream installer requires it.

## Vesktop file drag-and-drop

The Flatpak receives access to Downloads, Documents, and Pictures. This fixes the common
"file cannot be empty" drag-and-drop problem without granting access to the entire home directory.

## Greeter

Noctalia Greeter comes from the Terra repository on Fedora 44+. On Void it is built from the latest
stable upstream release using the upstream-documented Void dependencies. The installer:

- installs the greeter,
- runs the greeter system setup helper,
- installs the known-good greetd config,
- enables the constrained passwordless appearance-sync rule for the current user,
- enables greetd for the next boot on Fedora; Void activation is left as an explicit TTY step so the
  installer cannot replace the current GUI session.

## Distribution-specific behavior

Fedora and Void support lives in one installer. Most configuration, backup, Flatpak, wallpaper, and
application-default behavior is shared; only package installation, Firefox's system policy path, the
greetd account, and service management differ.

- Fedora uses DNF, the Fedora Noctalia package, Terra's Noctalia Greeter package, and systemd.
- Void uses XBPS, builds Noctalia and Noctalia Greeter from their latest stable release tags, uses
  Void's `_greeter` account, enables the required system D-Bus service, configures PipeWire with
  WirePlumber and PulseAudio compatibility, and follows runit service conventions.
- Both Void glibc and musl are accepted. Noctalia's Meson configuration automatically skips
  jemalloc on musl.

After your first Noctalia login, use **Settings -> Security -> Noctalia Greeter -> Sync Now** once.
The provided Noctalia config has Auto-Sync Greeter enabled afterward.

## Notes about portability

Machine-specific `/home/mikoo` paths from the source setup were removed. The installer substitutes
the current user's `$HOME`. Monitor-specific Noctalia lock-screen placement was also omitted because
it was disabled and tied to the original laptop display.

The disabled example Niri `output "eDP-1"` block remains commented out and therefore does not force
another machine to use that monitor mode or scale.

## Upstream references

- Noctalia: https://docs.noctalia.dev/noctalia/getting-started/installation/
- Noctalia configuration: https://docs.noctalia.dev/noctalia/configuration/
- Noctalia Greeter: https://docs.noctalia.dev/greeter/installation/
- Greeter sync: https://docs.noctalia.dev/greeter/sync/
- Spicetify: https://spicetify.app/docs/getting-started
- Vesktop Flatpak: https://github.com/flathub/dev.vencord.Vesktop
- Bibata: https://github.com/ful1e5/Bibata_Cursor
