# Noctiri

A reproducible Fedora 44 + Niri + Noctalia rice, available as both a normal installer and an experimental live ISO.

## Installation paths

### Existing Fedora installation

Run the normal installer as your regular user:

```bash
chmod +x install.sh
./install.sh
```

### Live ISO

Noctiri also has an experimental Fedora KIWI live-image build under `iso/`. It boots directly into the Noctiri Niri + Noctalia session and includes Anaconda live-install support.

Build locally on Fedora:

```bash
sudo dnf install kiwi kiwi-systemdeps distribution-gpg-keys git curl
sudo FEDORA_BRANCH=f44 bash iso/build.sh
```

Or run **Build Noctiri Live ISO** from GitHub Actions. See [iso/README.md](iso/README.md) for details.

The ISO intentionally leaves Spotify, Vesktop, Spicetify, and wallpaper collections to the post-install setup rather than baking them into the image.

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

You can also choose all or skip wallpapers entirely.

## Run

Do **not** run the whole installer with sudo. Run it as your normal user:

```bash
chmod +x install.sh
./install.sh
```

The script requests sudo only for system packages/configuration.

## Important behavior

- Existing config files that the installer replaces are copied to
  `~/.local/state/niri-noctalia-installer-backup/<timestamp>/` first.
- The installer is designed to be safe to rerun.
- Noctalia GUI state (`~/.local/state/noctalia/settings.toml`) is backed up and removed,
  because GUI state overrides declarative config files.
- The installer enables greetd and sets `graphical.target`, but deliberately does **not**
  start/restart greetd during installation. This avoids terminating an active graphical session.
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

Noctalia Greeter comes from the Terra repository on Fedora 44+. The installer:
- installs the greeter,
- runs the greeter system setup helper,
- installs the known-good greetd config,
- enables the constrained passwordless appearance-sync rule for the current user,
- enables greetd for the next boot.

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
