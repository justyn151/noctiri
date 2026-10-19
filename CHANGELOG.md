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
- Made Firefox policy merging privilege-safe and refuse to overwrite malformed existing JSON.
- Replaced `/home/mikoo` with the target user's `$HOME` at installation time.
- Removed disabled Noctalia lock-screen widget placement tied to `eDP-1`.
- Removed exported per-monitor wallpaper paths and made wallpaper repositories optional.
- Base Noctalia theme falls back to the built-in Noctalia palette when wallpapers are skipped.
- Explicitly enables Noctalia built-in templates.
- Preserves the current Niri keybindings, blur/opacity, rounded windows, hot-corner setting,
  screenshot binding, Kitty config, Qt/KDE configuration, portal routing and greetd config.
- Adds default application associations beyond the single JPEG association in the export.
- Adds Firefox XDG file-picker policy and the Vesktop Flatpak drag-and-drop permissions discussed
  during setup.
