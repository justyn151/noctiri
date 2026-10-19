# Noctiri desktop installer for Fedora and Void Linux

A reproducible desktop installer with two deliberately separate flavours:

- **Modern:** the existing Niri + Noctalia scrolling desktop on Fedora 44+ and Void Linux
  (glibc or musl).
- **Tatami:** a traditional Mango master-stack desktop for Void Linux, with Waybar, awww,
  SwayNotificationCenter and paired day/night themes.

The Modern flavour and its configuration remain unchanged. A normal Void installation asks which
flavour to install; Fedora continues to select Modern automatically.

## What it installs

Shared desktop foundation:
- greetd + Noctalia Greeter
- PipeWire + WirePlumber
- XDG portals
- Polkit and GNOME Keyring PAM integration

Modern desktop:
- Niri + Noctalia
- XWayland Satellite
- Noctalia's integrated bar, launcher, notifications and wallpaper support

Tatami desktop (Void only):
- Mango with a traditional master-stack layout; grid, monocle and deck are optional layouts
- Waybar with compact Japanese-number tags, a constrained media title and icon-only system status;
  it uses Mango's ext-workspace and dwl-ipc protocols, which Void's Waybar supports
- awww wallpaper daemon
- Fuzzel launcher and SwayNotificationCenter
- swaylock + swayidle, cliphist, and grim + slurp + swappy
- Yazi in a Kitty named scratchpad

Theme/integration:
- Bibata Modern Ice cursor
- Inter UI font
- JetBrainsMono Nerd Font Mono for Modern; IosevkaTerm Nerd Font Mono for Tatami
- qt6ct + Breeze Qt style/icons
- Modern uses Noctalia templates for `btop`, `cava`, Qt/KDE, Kitty and Niri
- Tatami ships matching Mango, Waybar, Kitty, Fuzzel, qt6ct and btop day/night palettes
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

On Void, select either Modern or Tatami at the prompt. Non-interactive equivalents are:

```bash
./install.sh --flavour niri
./install.sh --flavour mango --theme night
./install.sh --flavour mango --theme day
```

To add Tatami to an existing Void desktop without rebuilding or replacing Niri/Noctalia, run:

```bash
./install.sh --mango-only
```

That mode installs/repairs Tatami and the shared runtime, then pins **Noctiri Tatami** in the
greeter. It does not alter `~/.config/niri`, `~/.config/noctalia`, or the saved Modern bar setup.

Completed stages are recorded under `~/.local/state/noctiri-installer/completed/`. On later full
runs, each completed stage defaults to **skip** but can be rerun when you want to update or repair
it. If the state directory does not exist yet, the installer detects an existing Niri, Noctalia,
and Noctalia Greeter installation and offers to adopt the expensive package/build stage as already
complete.

To install new wallpaper collections or update existing wallpaper repositories without package
installation, configuration replacement, or source compilation, run:

```bash
./install.sh --wallpapers-only
```

Use `./install.sh --wallpapers-only --flavour mango` to save the selected collection's initial
image for Tatami instead of Noctalia.

When installing from a TTY, the Spicetify stage is deferred because Spotify cannot create its
profile without a graphical session. After logging into the selected desktop, launch Spotify once,
log in, close Spotify, and finish only that stage with:

```bash
./install.sh --spicetify-only
```

To repair only greetd and Noctalia Greeter without reinstalling or rebuilding the desktop stack:

```bash
./install.sh --greeter-only
```

To repair KDE/Qt and btop color synchronization without reinstalling or rebuilding anything:

```bash
./install.sh --theme-only
```

This enables Noctalia's separate `qt` template, points qt6ct at the generated Qt palette, creates
btop's first-run config when necessary, defines the time/date bar entries as `clock` widgets, and
immediately reloads Noctalia and reapplies templates if it is running.

To install, configure, and check NetworkManager, Bluetooth, and PipeWire without rebuilding Niri or
Noctalia:

```bash
./install.sh --services-only
```

On Void, this enables D-Bus, NetworkManager, and Bluetooth runit services; adds the login user to
the required groups; enables WirePlumber, PipeWire's PulseAudio interface, XDG autostart, and ALSA
integration; enables persistent screen-brightness save/restore; and checks all three stacks. If
another network manager is active, the installer asks before switching because doing so can briefly
disconnect the machine.

The script detects the distribution from `/etc/os-release` and requests sudo only for system
packages/configuration. When the Void package stage runs, it performs a full XBPS update first
because partial upgrades are unsupported, then builds the latest stable Noctalia and Noctalia
Greeter releases from source for Modern. Tatami uses Void's `mangowc`, `Waybar`, `awww`, `yazi`,
and `SwayNotificationCenter` packages and builds only Noctalia Greeter when it is absent. The
Modern build also installs `nlohmann-json` from its latest stable release because Void does not
provide the development package required by Noctalia.

## Tatami controls and appearance

Core bindings:

- `Super+Return`: Kitty
- `Super+Shift+Return`: toggle the Yazi scratchpad
- `Super+Space`: Fuzzel
- `Super+B`: Firefox
- `Super+1` through `Super+5`: change tag; add `Shift` to move the focused window
- `Super+T`: cycle tile, grid, monocle and deck layouts
- `Super+Shift+Space`: toggle floating
- `Super+Shift+T`: toggle the complete day/night palette
- `Print`: save a full screenshot; `Shift+Print`: select an area and edit it in Swappy

The theme toggle updates Mango, Waybar, Kitty, Fuzzel, qt6ct and btop together. Already-running Qt
or btop processes may need to be reopened to adopt their new palette. It can also be run directly:

```bash
noctiri-theme day
noctiri-theme night
noctiri-theme toggle
```

The installer equivalent is `./install.sh --theme-only --flavour mango --theme day` (or `night`).

Set and persist an awww wallpaper with:

```bash
noctiri-wallpaper /absolute/path/to/image
```

Tatami automatically restores awww's last wallpaper at login. If awww has no history yet, it uses
the first image found under `~/Pictures/Wallpapers`.

## Important behavior

- Existing config files that the installer replaces are copied to
  `~/.local/state/niri-noctalia-installer-backup/<timestamp>/` first.
- The installer is designed to be safe to rerun.
- Modern and Tatami have separate completion-state identifiers for their package, font and config
  stages, so adding Tatami does not invalidate or rebuild an existing Modern installation.
- Noctalia GUI state (`~/.local/state/noctalia/settings.toml`) is backed up and removed,
  because GUI state overrides declarative config files.
- On Fedora, the installer enables greetd and sets `graphical.target`, but deliberately does **not**
  start/restart greetd during installation.
- On Void, enabling a runit service starts it immediately. The installer therefore configures
  greetd but never activates it later on your behalf. From a TTY, after resolving any
  display-manager warning, manually run `sudo ln -s /etc/sv/greetd /var/service/` once. Future runs
  detect the symlink and do not ask you to create it again.
- If another display manager is configured, the installer warns instead of blindly disabling it.

## Spotify / Spicetify

Spotify is installed from Flathub. A fresh Spotify profile must be opened and logged into once
before Spicetify can patch it. In a graphical session, the installer can launch Spotify and wait
for you. In a TTY, it leaves the stage incomplete instead of trying to launch Spotify.

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
- pins the selected Noctiri flavour as the startup session so another discovered or remembered
  desktop is not selected by default,
- runs greetd on VT7 on Void, leaving tty1 available as a recovery console,
- enables the constrained passwordless appearance-sync rule for the current user,
- enables greetd for the next boot on Fedora; Void activation is left as an explicit TTY step so the
  installer cannot replace the current GUI session.

## Distribution-specific behavior

Fedora and Void support lives in one installer. Most configuration, backup, Flatpak, wallpaper, and
application-default behavior is shared; only package installation, Firefox's system policy path, the
greetd account, and service management differ.

- Fedora uses DNF, the Fedora Noctalia package, Terra's Noctalia Greeter package, and systemd.
- Void uses XBPS. Modern builds Noctalia and Noctalia Greeter from their latest stable release tags;
  Tatami installs Mango and its desktop components from Void's repositories. Both use Void's
  `_greeter` account, enable the required system D-Bus service, configure PipeWire with WirePlumber,
  PulseAudio and ALSA compatibility, configure NetworkManager and BlueZ, and follow runit service
  conventions. Because Void's
  Polkit rules directory is owned by `polkitd`, the installer uses Noctalia Greeter's constrained
  manual rule after the upstream command validates the installed helper and policy.
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
- Mango: https://github.com/mangowm/mango
- Waybar ext-workspace and dwl modules: https://github.com/Alexays/Waybar
- awww: https://codeberg.org/LGFae/awww
