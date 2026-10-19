# Build notes

This installer was generated from the supplied `setup-export.tar.gz`.

Sanitization/portability changes:
- Added automatic Fedora/Void detection with distro-specific package, Firefox policy, greeter-user,
  and service-management paths.
- Added Void XBPS package installation and stable-source builds for Noctalia and Noctalia Greeter.
- Fixed Void installation failing on the nonexistent `nlohmann-json-devel` package by installing
  the header-only dependency from its latest stable release.
- Added a Void-specific fallback for Noctalia Greeter passwordless sync when the upstream rule
  manager rejects Void's `polkitd`-owned rules directory.
- Added persistent per-stage completion state with skip prompts, existing-install adoption, and a
  `--wallpapers-only` mode that avoids package installation and source compilation.
- Deferred Spicetify cleanly during TTY installs and added `--spicetify-only` for completing it
  after Spotify creates its profile in a graphical session.
- Pinned Niri as Noctalia Greeter's default session and added `--greeter-only` for repairing the
  greeter without reinstalling or recompiling the desktop stack.
- Moved greetd from Void's tty1 to VT7 and repairs both the administrator default and remembered
  Greeter session to Niri.
- Made Firefox policy merging privilege-safe and refuse to overwrite malformed existing JSON.
- Replaced `/home/mikoo` with the target user's `$HOME` at installation time.
- Removed disabled Noctalia lock-screen widget placement tied to `eDP-1`.
- Removed exported per-monitor wallpaper paths and made wallpaper repositories optional.
- Base Noctalia theme falls back to the built-in Noctalia palette when wallpapers are skipped.
- Explicitly enables Noctalia built-in templates.
- Fixed application color synchronization by enabling Noctalia's separate Qt template, pointing
  qt6ct at its generated palette, and seeding btop's config before its template hook runs. Added
  `--theme-only` to apply the repair without rebuilding the desktop stack.
- Fixed the missing bar time and date by declaring the configured `clock-time` and `clock-date`
  instances as current Noctalia `clock` widgets.
- Added complete NetworkManager, BlueZ, and PipeWire setup and health checks on Fedora and Void,
  including Void runit services, user groups, XDG PipeWire autostart, WirePlumber, PulseAudio and
  ALSA integration. Added `--services-only` so existing systems can be repaired without rebuilding.
- Bounded all connectivity/audio health checks to five seconds so a broken PipeWire socket cannot
  hang the installer at `wpctl status`.
- Fixed PipeWire repair when an orphaned `pipewire-pulse` or a legacy PulseAudio daemon already
  owns the Pulse socket: the installer now removes the conflicting server package when approved,
  stops the partial user stack, and starts PipeWire once in the correct order.
- Safely removes stale Pulse/PipeWire Unix socket files after confirming that no live kernel socket
  owns them, while preserving and reporting sockets that still have a real listener.
- Allows `--services-only` to repair audio over SSH by discovering the existing graphical user's
  runtime directory and D-Bus session socket.
- Avoids launching WirePlumber and pipewire-pulse twice when equivalent system-wide and per-user
  PipeWire drop-ins coexist. SSH repair now reads `dbus-run-session`'s temporary address directly
  from Niri, and a wedged duplicate stack is force-stopped only after a graceful timeout.
- Preserves the current Niri keybindings, blur/opacity, rounded windows, hot-corner setting,
  screenshot binding, Kitty config, Qt/KDE configuration, portal routing and greetd config.
- Adds default application associations beyond the single JPEG association in the export.
- Adds Firefox XDG file-picker policy and the Vesktop Flatpak drag-and-drop permissions discussed
  during setup.
