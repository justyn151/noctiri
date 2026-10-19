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
- Fantasque Sans Mono Nerd Font 3.5.1 for the desktop UI and terminals
- qt6ct + Breeze Qt style/icons
- Noctalia templates for `btop`, `cava`, KDE/Qt, Kitty, Niri, Yazi, and Pywalfox
- KDE file picker through `xdg-desktop-portal-kde`
- Firefox policy forcing the XDG portal file picker and installing the Pywalfox extension

Apps:
- Firefox
- Kitty
- Vim (with the included VimTeX/FZF configuration)
- Yazi as the `Super+E` file manager, with a Noctalia-generated palette
- Dolphin + Ark available from the application launcher for graphical fallback
- btop
- cava
- fastfetch
- qimgv
- mpv
- qpwgraph
- Spotify (Flatpak, installed by the optional Spicetify stage)
- Vesktop (Flatpak)
- Spicetify + Marketplace (optional interactive stage)

An optional, side-by-side Void preview is also available for the setup shown in Bread on
Penguins' **I moved to Wayland :D** video: the creator's patched DWL fork, Foot, Somebar,
Someblocks, and Liberation Mono. It does not replace or edit the Niri + Noctalia flavour.

Default media associations are set to qimgv for common images, mpv for common video and audio
types, and Firefox for PDF. VimTeX follows the system PDF association,
so a replacement reader can be selected later without editing Vim.

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

When installing from a TTY, the Spicetify stage installs Spotify if it is missing, then defers the
patch because Spotify cannot create its profile without a graphical session. After logging into
Niri, launch Spotify once, log in, close Spotify, and finish only that stage with:

```bash
./install.sh --spicetify-only
```

To repair only greetd and Noctalia Greeter without reinstalling or rebuilding the desktop stack:

```bash
./install.sh --greeter-only
```

To repair KDE/Qt, btop, Yazi, and Firefox color synchronization without reinstalling or rebuilding anything:

```bash
./install.sh --theme-only
```

This enables Noctalia's separate `qt` template and community `pywalfox` template, points qt6ct at
the generated Qt palette, creates btop's first-run config when necessary, installs the dynamic Yazi
template, defines the time/date bar entries as `clock` widgets, and immediately reloads Noctalia and
reapplies templates if it is running. The installer uses Noctalia's built-in Firefox native host,
so no legacy Python Pywalfox daemon is installed. Restart Firefox once after initial setup; reopen
Yazi after changing palettes so it reloads the rendered theme.

The installer also adds `~/.local/bin` to interactive/login shell startup and to the graphical Niri
session. Log out and back in once after applying this to an existing installation so every desktop
application inherits the updated `PATH`.

To install or repair only the desktop font configuration:

```bash
./install.sh --font-only
```

This pins the Fantasque Sans Mono Nerd Font 3.5.1 archive and verifies its checksum, then selects
`FantasqueSansM Nerd Font` for Fontconfig's system UI, sans, and serif aliases and
`FantasqueSansM Nerd Font Mono` for monospace. GTK 3/4, GNOME interface settings, Qt6ct,
KDE applications, Kitty, and Noctalia receive explicit settings as well. The separate DWL preview's
Foot and Somebar styling is left unchanged. Existing applications may cache fonts, so reopen them;
one logout refreshes the entire Niri session. Web pages and documents that deliberately specify a
typeface are not overridden.

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

## Optional DWL preview (Void)

Install the initial terminal + compositor + bar experiment without rebuilding or changing Niri:

```bash
./install.sh --dwl-only
```

The mode pins the exact creator DWL revision referenced by the video and matching known-good
Somebar/Someblocks revisions, builds DWL against Void's `wlroots0.19-devel`, and installs a separate
`DWL (Noctiri Preview)` Wayland session. It does not restart greetd or change the remembered/default
session. Log out normally and choose that session from the greeter when you want to test it.

The terminal and bar explicitly use **Liberation Mono**, which is the sharp monospace face used by
the referenced dotfiles (alongside the broader Liberation, Libertinus, and Noto Sans Nerd Font
families). Foot uses a 17-pixel font size so its apparent size remains stable across display DPI.

Initial DWL keys:

- `Super+Enter`: Foot
- `Super+D`: wmenu application launcher
- `Super+B`: Firefox
- `Super+E`: Yazi in Foot
- `Super+J/K`: focus next/previous window
- `Super+Shift+J/K`: rotate windows
- `Super+H/L`: change the main-window ratio
- `Super+Shift+Enter`: promote the focused window to master
- `Super+T`, `Super+M`, `Super+Space`: tile, monocle, or cycle layout
- `Super+Shift+Space`: toggle floating
- `Super+F`: toggle fullscreen
- `Super+G`: toggle gaps
- `Super+1..9`: view a tag; add `Shift` to move a window there
- `Super+Q`: close the focused window
- `Super+Shift+Q`: exit DWL
- `Ctrl+Alt+F1..F12`: switch TTYs

The output rule is connector-independent and lets wlroots select each display's preferred mode,
rather than hard-coding a laptop panel name or refresh rate. On an Intel + nouveau hybrid laptop,
the session wrapper automatically selects Intel for DWL to avoid the same nouveau startup hang that
the Niri configuration works around.

The script detects the distribution from `/etc/os-release` and requests sudo only for system
packages/configuration. When the Void package stage runs, it performs a full XBPS update first
because partial upgrades are unsupported, then builds the latest stable Noctalia and Noctalia
Greeter releases from source. It also installs `nlohmann-json` from its latest stable release
because Void does not provide the development package required by those builds.

## Important behavior

- Existing config files that the installer replaces are copied to
  `~/.local/state/niri-noctalia-installer-backup/<timestamp>/` first.
- The installer is designed to be safe to rerun.
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
- pins Niri as the startup session so another discovered or remembered desktop is not selected by
  default,
- runs greetd on VT7 on Void, leaving tty1 available as a recovery console,
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
  WirePlumber, PulseAudio and ALSA compatibility, configures NetworkManager and BlueZ, and follows
  runit service conventions. Because Void's
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
- Video setup: https://www.youtube.com/watch?v=FpWhd-UtJ2M
- Creator DWL fork: https://github.com/BreadOnPenguins/dwl
- Somebar: https://git.sr.ht/~raphi/somebar
- Someblocks: https://git.sr.ht/~raphi/someblocks
- Foot: https://codeberg.org/dnkl/foot
