--!nonstrict

local function binding(keys, action)
  return ui.row({ gap = 14, align = "center", minHeight = 27 }, {
    ui.label({
      text = keys,
      width = 245,
      color = "primary",
      fontWeight = "bold",
    }),
    ui.label({
      text = action,
      color = "on_surface",
      flexGrow = 1,
      maxLines = 2,
    }),
  })
end

local function section(title, rows)
  local children = {
    ui.label({
      text = title,
      fontSize = 15,
      fontWeight = "bold",
      color = "on_surface",
    }),
    ui.separator({ color = "outline_variant", spacing = 2 }),
  }

  for _, row in ipairs(rows) do
    table.insert(children, binding(row[1], row[2]))
  end

  return ui.column({
    gap = 8,
    padding = 14,
    fill = "surface_variant/0.45",
    radius = 14,
    border = "outline_variant/0.55",
    borderWidth = 1,
  }, children)
end

local essentials = {
  { "Super + Shift + /", "Toggle this shortcut panel" },
  { "Super + T", "Open Kitty" },
  { "Super + D", "Open the app launcher" },
  { "Super + E", "Open Yazi in Kitty" },
  { "Super + Shift + S", "Take a screenshot" },
  { "Super + Alt + L", "Lock the session" },
  { "Super + Tab", "Toggle the Niri overview" },
  { "Alt + Tab", "Switch through recent windows" },
  { "Super + Q", "Close the focused window" },
}

local focus = {
  { "Super + Left / Right", "Focus the neighboring column" },
  { "Super + Up / Down", "Focus a window in the current column" },
  { "Super + Home / End", "Focus the first or last column" },
  { "Super + Page Up / Down", "Switch workspace" },
  { "Super + 1…9", "Switch directly to a workspace" },
  { "Super + Shift + H/J/K/L", "Focus another monitor" },
}

local movement = {
  { "Super + Shift + Left / Right", "Move the focused column" },
  { "Super + Shift + Up / Down", "Move the focused stacked window" },
  { "Super + Ctrl + Home / End", "Move column to the first or last position" },
  { "Super + Ctrl + Page Up / Down", "Send column to another workspace" },
  { "Super + Ctrl + 1…9", "Send column directly to a workspace" },
  { "Super + Shift + Page Up / Down", "Reorder the current workspace" },
  { "Super + Shift + Ctrl + Arrow", "Send column to another monitor" },
}

local layout = {
  { "Super + [ / ]", "Consume or expel a window left/right" },
  { "Super + , / .", "Consume the next window / expel the bottom window" },
  { "Super + R", "Cycle preset column widths" },
  { "Super + Shift + R", "Cycle column widths in reverse" },
  { "Super + Ctrl + Shift + R", "Cycle preset window heights" },
  { "Super + Ctrl + R", "Reset window height" },
  { "Super + F", "Maximize the column" },
  { "Super + Shift + F", "Fullscreen the window" },
  { "Super + M", "Maximize the window to screen edges" },
  { "Super + Ctrl + F", "Expand column to available width" },
  { "Super + C", "Center the focused column" },
  { "Super + Ctrl + C", "Center all visible columns" },
  { "Super + - / =", "Decrease / increase column width" },
  { "Super + Shift + - / =", "Decrease / increase stacked window height" },
  { "Super + V", "Toggle floating for the focused window" },
  { "Super + Shift + V", "Switch focus between floating and tiling" },
  { "Super + W", "Toggle tabbed column display" },
}

local system = {
  { "Super + Escape", "Toggle application shortcut inhibition" },
  { "Super + Shift + P", "Turn off the displays" },
  { "Super + Shift + E", "Exit Niri (with confirmation)" },
  { "Ctrl + Alt + Delete", "Exit Niri (with confirmation)" },
  { "Volume / Media keys", "Control PipeWire volume and playback" },
  { "Brightness keys", "Adjust display brightness" },
}

local function render()
  panel.render(ui.column({ flexGrow = 1, gap = 14 }, {
    ui.row({ align = "center", justify = "space_between", gap = 12 }, {
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({
          text = "Noctiri shortcuts",
          fontSize = 21,
          fontWeight = "bold",
          color = "on_surface",
        }),
        ui.label({
          text = "The active Niri keymap — Super is the Windows key",
          color = "on_surface_variant",
        }),
      }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = "Close", onClick = "onCloseClicked" }),
    }),
    ui.scroll({ flexGrow = 1, gap = 16 }, {
      ui.row({ gap = 16, align = "start" }, {
        ui.column({ gap = 16, flexGrow = 1 }, {
          section("Essentials", essentials),
          section("Focus and navigation", focus),
          section("System", system),
        }),
        ui.column({ gap = 16, flexGrow = 1 }, {
          section("Move windows and workspaces", movement),
          section("Layout", layout),
        }),
      }),
    }),
  }))
end

function onOpen(_context)
  render()
end

function onCloseClicked()
  panel.close()
end
