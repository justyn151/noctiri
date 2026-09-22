# Build notes

This installer was generated from the supplied `setup-export.tar.gz`.

Sanitization/portability changes:
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
