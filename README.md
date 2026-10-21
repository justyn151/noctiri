# Fedora / Void Linux Niri + Noctalia Setup

A reproducible Niri + Noctalia installer for Fedora 44+ and Void Linux (glibc or musl),
built from a working Fedora configuration.

## What it installs

Core desktop:
- Niri
- Noctalia
- greetd + Noctalia Greeter
- Standard XDG home folders (`Desktop`, `Documents`, `Downloads`, `Music`, `Pictures`, `Public`, `Templates`, and `Videos`)
- XWayland Satellite
- PipeWire + WirePlumber
- XDG portals (GNOME + GTK; KDE is retained only on Fedora)
- Polkit and GNOME Keyring PAM integration

Theme/integration:
- Bibata Modern Ice cursor
- Fantasque Sans Mono Nerd Font 3.5.1 for the desktop UI and terminals, with Noto fallback for CJK and other scripts
- qt6ct + Breeze Qt style/icons
- Noctalia templates for `btop`, `cava`, KDE/Qt, Kitty, Niri, Yazi, and Pywalfox
- Native XDG file picker integration
- Firefox policy forcing the XDG portal file picker and installing the Pywalfox extension

Apps:
- Firefox
- Kitty
- Neovim (with the included VimTeX/FZF configuration)
- Sioyek for PDFs and Tectonic for compact, on-demand LaTeX compilation
- Yazi as the `Super+E` file manager, with a Noctalia-generated palette
- KeePassXC with its Firefox integration
- Dolphin + Ark available from the application launcher for graphical fallback
- btop
- cava
- fastfetch
- qimgv
- mpv
- qpwgraph
- Steam (native package on x86-64 glibc Void; Flatpak fallback elsewhere)
- Spotify (Flatpak, installed by the optional Spicetify stage)
- Vesktop (Flatpak)
- Spicetify + Marketplace (optional interactive stage)

An optional, side-by-side Void preview is also available for the setup shown in Bread on
Penguins' **I moved to Wayland :D** video: the creator's patched DWL fork, Foot, Somebar,
Someblocks, and Liberation Mono. It does not replace or edit the Niri + Noctalia flavour.

Default media associations are set to qimgv for common images, mpv for common video and audio
types, and Sioyek for PDF. VimTeX uses Sioyek directly for SyncTeX, compiles with Tectonic whenever
a TeX buffer is saved, and refreshes the viewer after a successful build. Tectonic is used instead
of a multi-gigabyte TeX Live installation and downloads support files only when a document needs them.

## Wallpapers

Wallpaper downloads are optional. The installer lets you choose any subset of:
1. https://github.com/sewergweller/walls
2. https://github.com/AbegAshford/rice-walls
3. https://github.com/na-ive/wallpapers
4. https://github.com/makccr/wallpapers
5. https://github.com/krishna4a6av/Wallpapers

You can also choose all or skip wallpapers entirely.

The recommended initial wallpaper is
[`145439722_p14.jpg`](https://github.com/na-ive/wallpapers/blob/abc91cf882479ff0e1260b0ad4d88e4d08d7b8b0/145439722_p14.jpg)
from [na-ive/wallpapers](https://github.com/na-ive/wallpapers), retrieved from upstream rather than
vendored here. That collection states that its images were gathered from the internet and carries
no license, so the original artist and redistribution terms are unknown; all rights remain with
the original creator. The installer defaults to collection 3 so it can reference the upstream copy
without republishing it.

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

After installation, run a read-only health check with:

```bash
noctiri-doctor
```

It checks Niri and Noctalia configuration, runit/systemd services, NetworkManager, BlueZ,
PipeWire/WirePlumber, MPD/MPRIS media integration, portals, fonts, and the standard XDG home
folders. It also checks the daily utilities, OCR languages, Yazi drive plugin, Noctiri recovery
command, and current memory against the 1500 MiB target. The memory result distinguishes Linux's
kernel-reported use from proportional application memory (PSS) and shows how much remains readily
available. `noctiri-doctor --repair` may be used to
restart safe per-user components and refresh
templates/directories; system-level changes remain explicit installer repair steps. From the
repository, `./install.sh --doctor` runs the same read-only checks without installing the command.
The same checks are available in a movable, palette-matched Quickshell window from the app launcher
or with `Super+Shift+D`. Its **Maintenance** tab creates snapshots, updates Noctiri, and performs a
two-step confirmed rollback; its **Memory** tab shows the proportional cost of each process and
reclaimable cache. `Super+Shift+/` opens the shortcut guide, whose tabs cover the desktop,
Neovim, Yazi, and rmpc controls installed by Noctiri.

## Daily utilities and safe updates

Noctiri uses Noctalia's existing encrypted clipboard store, screenshot annotator, notification
history, and Do Not Disturb support, so these features do not add another always-running shell.
`Super+Ctrl+V` opens clipboard history, `Super+N` opens notification history,
`Super+Shift+N` toggles DND, `Super+Shift+S` captures and annotates a region, and
`Super+Shift+O` captures a region and copies English/Japanese/Chinese OCR text. Screenshots and OCR
text are kept in `~/Pictures/Screenshots`.

KeePassXC is installed with the normal-install Firefox extension. Open KeePassXC once, create or
open a database, then enable Firefox under **Settings → Browser Integration**. Yazi's `M` key opens
its drive mount/unmount/eject interface, while `E` opens the interactive archive/open-with menu.
Install or repair only this bundle on Void with:

```bash
./install.sh --utilities-only
```

The `noctiri` command provides configuration snapshots without copying personal documents or
rolling back system packages:

```bash
noctiri status
noctiri snapshot
noctiri update
noctiri update --system
noctiri snapshots
noctiri rollback                 # restores the newest snapshot
noctiri rollback YYYYMMDD-HHMMSS # restores a selected snapshot
```

Every update and rollback makes a safety snapshot first, validates Niri and Noctalia, and reloads
the running shell. These actions are also available from **Noctiri Doctor → Maintenance**; protected
changes use a graphical administrator prompt.
DND scheduling is opt-in (`noctiri dnd schedule 23:00 07:00`) and otherwise has no resident
process; disable it with `noctiri dnd disable-schedule`.

To install new wallpaper collections or update existing wallpaper repositories without package
installation, configuration replacement, or source compilation, run:

```bash
./install.sh --wallpapers-only
```

The Spicetify stage installs Spotify if it is missing. When Niri/Noctalia is running, it opens
Spotify in that graphical session—even if the installer was started over SSH—then continues after
you log in and close Spotify. If no graphical session is running, log into Niri and finish only
that stage with:

```bash
./install.sh --spicetify-only
```

To repair only greetd and Noctalia Greeter without reinstalling or rebuilding the desktop stack:

```bash
./install.sh --greeter-only
```

To install or repair Steam without rerunning the desktop setup:

```bash
./install.sh --steam-only
```

On Void, this also installs the matching 32-bit Vulkan libraries, Gamescope, MangoHud, and
GameMode. Hybrid laptops get a **Steam (Discrete GPU)** launcher. To offload only one title instead,
put this in that game's Steam launch options:

```text
noctiri-gpu-run %command%
```

The normal Steam launcher remains available and does not force the dedicated GPU awake.

To repair KDE/Qt, btop, Yazi, Neovim, and Firefox color synchronization without reinstalling or rebuilding anything:

```bash
./install.sh --theme-only
```

This enables Noctalia's separate `qt` template and community `pywalfox` template, points qt6ct at
the generated Qt palette, creates btop's first-run config when necessary, installs dynamic Yazi and Neovim
template, defines the time/date bar entries as `clock` widgets, and immediately reloads Noctalia and
reapplies templates if it is running. The installer uses Noctalia's built-in Firefox native host,
so no legacy Python Pywalfox daemon is installed. Restart Firefox once after initial setup; reopen
Yazi or Neovim after changing palettes so it reloads the rendered theme.

Neovim replaces Vim in the package set. Its Lua configuration keeps the original navigation,
FZF, C++ highlighting, VimTeX, and TeX completion behavior while dropping every fixed
colorscheme plugin. Noctalia renders `~/.config/nvim/colors/noctalia.lua` from the active wallpaper,
and Neovim loads that palette as its only colorscheme. It uses a thin blinking beam in every mode;
the installer also removes the old `vim`/`vim-enhanced` package. `EDITOR` and `VISUAL` are set to `nvim`.
Completion, diagnostics, symbol navigation, and LaTeX intelligence are handled by CoC with the
`coc-texlab` extension. `Tab` and `Shift+Tab` move through suggestions, `Enter` accepts an explicitly
selected suggestion, and `Ctrl+Space` opens completion manually. `gd` jumps to a definition, `gr`
finds references, `[d`/`]d` move through diagnostics, and `Space+r,n` renames a symbol. ToggleTerm
provides persistent floating and split terminals:
`Space+t` opens the float, `Space+v,t` opens a vertical terminal, `Space+h,t` opens a horizontal one,
and `Ctrl+\` toggles the active terminal from normal or terminal mode.
Sioyek is the PDF default and VimTeX viewer. Saving a complete TeX buffer runs a single Tectonic
build and opens or refreshes Sioyek with SyncTeX support. TexLab supplies editing intelligence but
does not launch a second build. Run `./install.sh --documents-only` to install or repair this
lightweight document stack and its CoC runtime.
On Void, the installer runs Sioyek through its packaged xcb backend because that build does not
include Qt's native Wayland platform plugin; this affects only Sioyek and leaves the desktop native
Wayland.
Inside a TeX buffer, `Space+l,x` toggles compile-on-save, `Space+l,b` builds once, and `Space+l,v`
opens the generated PDF. If no readable PDF exists, the viewer shortcut now points to
`:VimtexErrors` instead of opening an empty viewer. Compile-on-save starts enabled for each TeX buffer.

Firefox receives a deliberately small default extension set through its normal-install policy:
Pywalfox, uBlock Origin, SponsorBlock, Ctrl+Number to switch tabs, and KeePassXC-Browser. Normal-installed extensions
can still be disabled by the user. Restart Firefox after installation so it reads the policy and connects Pywalfox.
To install or repair only that browser setup, run `./install.sh --firefox-only`.

Zsh is the default interactive shell, with Oh My Zsh installed from its official Git repository.
The managed `.zshrc` enables the standard `robbyrussell` theme, Git integration, selectable
completion menus, history/completion suggestions, and syntax highlighting while retaining Noctiri's
`~/.local/bin`, `EDITOR`, and `VISUAL` environment. Kitty uses a beam cursor with a short cursor trail
for smooth movement. Niri pre-warms a hidden single-instance Kitty process at login, so terminal and
Yazi windows reuse its GPU cache instead of repeating the full cold start. To install or repair only
the shell:

```bash
./install.sh --zsh-only
```

Log out once after the first installation so terminals and SSH sessions use Zsh by default.

rmpc is installed as the terminal music player together with a per-user MPD daemon. MPD scans
`~/Music` and sends audio directly to PipeWire. To preserve idle memory, MPD and its media bridge
start on demand when **rmpc Music Player** is opened instead of at every login. They remain active
after the terminal closes so playback is uninterrupted. The installer also supervises
[`mpd-mpris`](https://github.com/natsukagami/mpd-mpris), allowing Noctalia's media widget,
`playerctl`, and media keys to see and control rmpc/MPD playback. A dedicated `rmpc Music Player`
entry—with its own icon—opens it in Kitty from the application launcher. The installer preserves
an existing `~/.config/rmpc/config.ron`; on a new setup, run `rmpc` in Kitty and use its default
Vim-style controls. To install or repair only this stack:

```bash
./install.sh --music-only
```

The installer also adds `~/.local/bin` to interactive/login shell startup and to the graphical Niri
session. Log out and back in once after applying this to an existing installation so every desktop
application inherits the updated `PATH`.

To install or repair only the desktop font configuration:

```bash
./install.sh --font-only
```

This pins the Fantasque Sans Mono Nerd Font 3.5.1 archive and verifies its checksum, then selects
`FantasqueSansM Nerd Font` for Fontconfig's system UI, sans, and serif aliases and
`FantasqueSansM Nerd Font Mono` for monospace. Noto Sans CJK is installed as the fallback for
Chinese, Japanese, and Korean glyphs, including applications running through Flatpak. GTK 3/4,
GNOME interface settings, Qt6ct, KDE applications, Kitty, and Noctalia receive explicit settings as
well. The separate DWL preview's Foot and Somebar styling is left unchanged. Existing applications
may cache fonts, so reopen them; one logout refreshes the entire Niri session. Web pages and
documents that deliberately specify a typeface are not overridden.

To install, configure, and check NetworkManager, Bluetooth, and PipeWire without rebuilding Niri or
Noctalia:

```bash
./install.sh --services-only
```

On Void, this enables D-Bus and Bluetooth runit services; adds the login user to the required groups;
enables WirePlumber, PipeWire's PulseAudio interface, XDG autostart, and ALSA integration; enables
persistent screen-brightness save/restore; and checks the repaired services. PipeWire runs beneath a
single-instance session supervisor and an elogind resume hook cleanly recreates the stack after
suspend. BlueZ and WirePlumber are configured to restore trusted Bluetooth audio profiles and retry
them after resume. During a full install, the NetworkManager handoff is deliberately postponed until
Flatpak, wallpaper, and Spicetify downloads are finished. If another network manager is active, the
installer asks before switching because doing so can briefly disconnect the machine. Declining
leaves the existing connection alone and keeps the handoff available on a later run.

The Void source build of Noctalia Greeter also applies Noctiri's animated password dots and glass
styling: only the wallpaper area directly behind the translucent login card is softly blurred on the
GPU; the rest of the background and the card's text stay sharp. The installer never restarts greetd
automatically, so the new appearance is picked up at the next normal logout or reboot.

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
before Spicetify can patch it. If a Noctalia/Niri graphical session is running—even when the
installer itself is invoked through SSH or a TTY—the installer imports that session environment,
opens Spotify there, and continues automatically after Spotify is closed. With no graphical
session, it leaves the stage incomplete; it does not fabricate an unsupported prefs file.

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
- uses Noctalia's regular circular password mask and, on Void's source build, gives each newly typed
  circle a short fade-and-spring animation,
- hides the Noctalia logo for a cleaner login card,
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
