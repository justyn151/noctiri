//@ pragma AppId noctiri-shortcuts

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root

    readonly property string fontFamily: "FantasqueSansM Nerd Font"
    property int activeTab: 0

    function paletteValue(name, fallback) {
        if (!paletteFile.loaded)
            return fallback;
        const expression = new RegExp("(?:^|\\n)" + name + "\\s+(#[0-9a-fA-F]{6,8})(?:\\s|$)");
        const match = paletteFile.text().match(expression);
        return match ? match[1] : fallback;
    }

    readonly property color backgroundColor: paletteValue("background", "#111414")
    readonly property color foregroundColor: paletteValue("foreground", "#e1e3e2")
    readonly property color surfaceColor: paletteValue("color0", "#404849")
    readonly property color mutedColor: paletteValue("color8", "#899292")
    readonly property color accentColor: paletteValue("active_border_color", "#9ad0d2")
    readonly property color urgentColor: paletteValue("color1", "#ffb4ab")

    readonly property var tabNames: ["Desktop", "Neovim", "Yazi", "rmpc"]

    function closeWindow() {
        // The guide is opened on demand, so closing it should release the
        // standalone Qt/Quickshell process instead of merely hiding it.
        Qt.quit();
    }

    readonly property var essentials: [
        { combo: "Super + Shift + /", action: "Toggle this shortcut window" },
        { combo: "Super + Shift + D", action: "Open Noctiri Doctor" },
        { combo: "Super + T", action: "Open Kitty" },
        { combo: "Super + D", action: "Open the app launcher" },
        { combo: "Super + P", action: "Open the wallpaper picker" },
        { combo: "Super + E", action: "Open Yazi in Kitty" },
        { combo: "Super + Shift + S", action: "Capture and annotate a region" },
        { combo: "Print", action: "Capture the current monitor" },
        { combo: "Super + Shift + O", action: "OCR a region and copy its text" },
        { combo: "Super + Alt + R", action: "Start/stop recording a selected region" },
        { combo: "Super + Alt + Shift + R", action: "Start/stop recording a monitor" },
        { combo: "Super + Ctrl + V", action: "Open encrypted clipboard history" },
        { combo: "Super + N", action: "Open notification history" },
        { combo: "Super + Shift + N", action: "Toggle Do Not Disturb" },
        { combo: "Super + Alt + L", action: "Lock the session" },
        { combo: "Super + Tab", action: "Toggle the Niri overview" },
        { combo: "Alt + Tab", action: "Switch through recent windows" },
        { combo: "Super + Q", action: "Close the focused window" }
    ]

    readonly property var focusBindings: [
        { combo: "Super + Left / Right", action: "Focus the neighboring column" },
        { combo: "Super + Up / Down", action: "Focus a window in the current column" },
        { combo: "Super + Home / End", action: "Focus the first or last column" },
        { combo: "Super + Page Up / Down", action: "Switch workspace" },
        { combo: "Super + 1…9", action: "Switch directly to a workspace" },
        { combo: "Super + Shift + H/J/K/L", action: "Focus another monitor" }
    ]

    readonly property var movement: [
        { combo: "Super + Shift + Left / Right", action: "Move the focused column" },
        { combo: "Super + Shift + Up / Down", action: "Send window to the workspace above / below" },
        { combo: "Super + Ctrl + Up / Down", action: "Move a stacked window vertically" },
        { combo: "Super + Ctrl + Home / End", action: "Move column to the first or last position" },
        { combo: "Super + Ctrl + Page Up / Down", action: "Send column to another workspace" },
        { combo: "Super + Ctrl + 1…9", action: "Send column directly to a workspace" },
        { combo: "Super + Shift + Page Up / Down", action: "Reorder the current workspace" },
        { combo: "Super + Shift + Ctrl + Arrow", action: "Send column to another monitor" }
    ]

    readonly property var layoutBindings: [
        { combo: "Super + [ / ]", action: "Consume or expel a window left/right" },
        { combo: "Super + , / .", action: "Consume the next window / expel the bottom window" },
        { combo: "Super + R", action: "Cycle preset column widths" },
        { combo: "Super + Shift + R", action: "Cycle column widths in reverse" },
        { combo: "Super + Ctrl + Shift + R", action: "Cycle preset window heights" },
        { combo: "Super + Ctrl + R", action: "Reset window height" },
        { combo: "Super + F", action: "Maximize the column" },
        { combo: "Super + Shift + F", action: "Fullscreen the window" },
        { combo: "Super + M", action: "Maximize the window to screen edges" },
        { combo: "Super + Ctrl + F", action: "Expand column to available width" },
        { combo: "Super + C", action: "Center the focused column" },
        { combo: "Super + Ctrl + C", action: "Center all visible columns" },
        { combo: "Super + - / =", action: "Decrease / increase column width" },
        { combo: "Super + Shift + - / =", action: "Decrease / increase stacked window height" },
        { combo: "Super + V", action: "Toggle floating for the focused window" },
        { combo: "Super + Shift + V", action: "Switch focus between floating and tiling" },
        { combo: "Super + W", action: "Toggle tabbed column display" }
    ]

    readonly property var systemBindings: [
        { combo: "Super + Escape", action: "Toggle application shortcut inhibition" },
        { combo: "Super + Shift + P", action: "Turn off the displays" },
        { combo: "Super + Shift + E", action: "Exit Niri with confirmation" },
        { combo: "Ctrl + Alt + Delete", action: "Exit Niri with confirmation" },
        { combo: "Volume / Media keys", action: "Control PipeWire volume and playback" },
        { combo: "Brightness keys", action: "Adjust display brightness" }
    ]

    readonly property var nvimBasics: [
        { combo: "Space", action: "Leader key" },
        { combo: "i / Esc", action: "Enter Insert mode / return to Normal mode" },
        { combo: ":w / :q / :wq", action: "Save / quit / save and quit" },
        { combo: "u / Ctrl + R", action: "Undo / redo" },
        { combo: "yy / dd / p", action: "Copy line / delete line / paste" },
        { combo: "/ · n / N", action: "Search · next / previous result" },
        { combo: "Space + n", action: "Toggle absolute and relative line numbers" },
        { combo: "Space + Enter", action: "Clear search highlighting" }
    ]

    readonly property var nvimFiles: [
        { combo: "Space + e", action: "Open the vertical file explorer" },
        { combo: "Space + f f", action: "Find files with FZF" },
        { combo: "Space + f g", action: "Search file contents with ripgrep" },
        { combo: "Space + q", action: "Close the current window" },
        { combo: "Space + w", action: "Enter the window-command prefix" },
        { combo: "Space + Arrow", action: "Resize the current split" }
    ]

    readonly property var nvimTerminal: [
        { combo: "Space + t", action: "Toggle the floating terminal" },
        { combo: "Space + v t", action: "Open a vertical terminal" },
        { combo: "Space + h t", action: "Open a horizontal terminal" },
        { combo: "Ctrl + \\", action: "Toggle the terminal" },
        { combo: "Alt + e", action: "Leave terminal input mode" }
    ]

    readonly property var nvimCompletion: [
        { combo: "Tab / Shift + Tab", action: "Next / previous completion" },
        { combo: "Enter", action: "Accept the selected completion" },
        { combo: "Ctrl + Space", action: "Open completion manually" },
        { combo: "g d / g r", action: "Go to definition / references" },
        { combo: "[ d / ] d", action: "Previous / next diagnostic" },
        { combo: "Space + r n", action: "Rename the current symbol" },
        { combo: "K", action: "Show documentation" }
    ]

    readonly property var nvimTex: [
        { combo: "Space + l x", action: "Toggle VimTeX compile-on-save" },
        { combo: "Space + l b", action: "Build the document once" },
        { combo: "Space + l v", action: "Open the generated PDF" }
    ]

    readonly property var yaziNavigation: [
        { combo: "h / Left", action: "Go to the parent directory" },
        { combo: "j / k", action: "Move down / up" },
        { combo: "l / Right", action: "Enter a directory or open a file" },
        { combo: "g g / G", action: "Jump to the top / bottom" },
        { combo: "J / K", action: "Seek the preview down / up" },
        { combo: "z / Z", action: "Jump with fzf / zoxide" }
    ]

    readonly property var yaziFiles: [
        { combo: "Enter / o", action: "Open item (audio/video play in MPV)" },
        { combo: "Space", action: "Toggle selection" },
        { combo: "v / V", action: "Start / clear visual selection" },
        { combo: "y / x / p", action: "Copy / cut / paste" },
        { combo: "Y / X", action: "Cancel copy / cut state" },
        { combo: "d / D", action: "Trash / permanently delete" },
        { combo: "a / r", action: "Create / rename" },
        { combo: ".", action: "Toggle hidden files" },
        { combo: "Tab", action: "Show file information" },
        { combo: "E", action: "Choose an archive/open action" },
        { combo: "A", action: "Create a 7z/zip archive" },
        { combo: "M", action: "Mount, unmount, or eject a drive" }
    ]

    readonly property var yaziSearch: [
        { combo: "f", action: "Filter the current directory" },
        { combo: "F", action: "Smart-filter and open the result" },
        { combo: "/ / ?", action: "Find next / previous match" },
        { combo: "n / N", action: "Next / previous found item" },
        { combo: "s / S", action: "Search filenames / file contents" },
        { combo: "Ctrl + S", action: "Cancel the active search" },
        { combo: "; / :", action: "Run a shell command / blocking command" },
        { combo: "c c / c d", action: "Copy path / directory path" },
        { combo: "c f / c n", action: "Copy filename / filename stem" }
    ]

    readonly property var yaziTabs: [
        { combo: "t t", action: "Create a new tab" },
        { combo: "1…9", action: "Switch directly to a tab" },
        { combo: "[ / ]", action: "Previous / next tab" },
        { combo: "{ / }", action: "Move the current tab left / right" },
        { combo: "Ctrl + C", action: "Close the current tab" },
        { combo: "T", action: "Maximize / restore the preview (FFprobe for audio)" },
        { combo: "+ / -", action: "Zoom an image preview in / out" },
        { combo: "c m", action: "Change selected file permissions" },
        { combo: "w", action: "Open the task manager" }
    ]

    readonly property var rmpcPlayback: [
        { combo: "p", action: "Play or pause" },
        { combo: "s", action: "Stop playback" },
        { combo: "> / <", action: "Next / previous track" },
        { combo: "f / b", action: "Seek forward / backward" },
        { combo: ". / ,", action: "Volume up / down" },
        { combo: "z / x / c / v", action: "Repeat / random / consume / single" },
        { combo: "q", action: "Quit rmpc" },
        { combo: "?", action: "Open rmpc's built-in help" }
    ]

    readonly property var rmpcPages: [
        { combo: "Tab / Shift + Tab", action: "Next / previous page" },
        { combo: "1", action: "Queue" },
        { combo: "2", action: "Directories" },
        { combo: "3 / 4", action: "Artists / album artists" },
        { combo: "5", action: "Albums" },
        { combo: "6", action: "Playlists" },
        { combo: "7", action: "Search" },
        { combo: ":", action: "Enter command mode" }
    ]

    readonly property var rmpcNavigation: [
        { combo: "j / k · Arrow keys", action: "Move through the active pane" },
        { combo: "h / l", action: "Move left / right" },
        { combo: "Ctrl + W, then H/J/K/L", action: "Focus another pane" },
        { combo: "J / K", action: "Move the selected item down / up" },
        { combo: "g g / G", action: "Jump to the top / bottom" },
        { combo: "Space / Ctrl + Space", action: "Select / invert selection" },
        { combo: "/ · n / N", action: "Search · next / previous result" },
        { combo: "Esc", action: "Close the current popup" }
    ]

    readonly property var rmpcLibrary: [
        { combo: "a / A", action: "Add selection / add all" },
        { combo: "D", action: "Delete or clear the active pane" },
        { combo: "Ctrl + U / Ctrl + Shift + U", action: "Update database / full rescan" },
        { combo: "R", action: "Add random tracks" },
        { combo: "Ctrl + Z", action: "Open the context menu" },
        { combo: "Ctrl + R", action: "Rename the selected item" },
        { combo: "o i / r", action: "Show information / rate" }
    ]

    readonly property var rmpcQueue: [
        { combo: "Enter", action: "Play the selected queue item" },
        { combo: "d / D", action: "Remove item / clear the queue" },
        { combo: "C", action: "Jump to the currently playing item" },
        { combo: "X", action: "Shuffle the queue" }
    ]

    readonly property var desktopLeft: [
        { heading: "Essentials", entries: essentials },
        { heading: "Focus and navigation", entries: focusBindings },
        { heading: "System", entries: systemBindings }
    ]
    readonly property var desktopRight: [
        { heading: "Move windows and workspaces", entries: movement },
        { heading: "Layout", entries: layoutBindings }
    ]
    readonly property var nvimLeft: [
        { heading: "Editing basics", entries: nvimBasics },
        { heading: "Files and windows", entries: nvimFiles }
    ]
    readonly property var nvimRight: [
        { heading: "Completion and language tools", entries: nvimCompletion },
        { heading: "Terminal", entries: nvimTerminal },
        { heading: "LaTeX", entries: nvimTex }
    ]
    readonly property var yaziLeft: [
        { heading: "Navigation", entries: yaziNavigation },
        { heading: "Files and selection", entries: yaziFiles }
    ]
    readonly property var yaziRight: [
        { heading: "Search, shell, and clipboard", entries: yaziSearch },
        { heading: "Tabs and tasks", entries: yaziTabs }
    ]
    readonly property var rmpcLeft: [
        { heading: "Playback", entries: rmpcPlayback },
        { heading: "Pages", entries: rmpcPages }
    ]
    readonly property var rmpcRight: [
        { heading: "Navigation and selection", entries: rmpcNavigation },
        { heading: "Library", entries: rmpcLibrary },
        { heading: "Queue", entries: rmpcQueue }
    ]

    FileView {
        id: paletteFile
        path: Quickshell.env("HOME") + "/.config/kitty/themes/noctalia.conf"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    component KeyRow: RowLayout {
        required property string combo
        required property string action
        Layout.fillWidth: true
        spacing: 12

        Text {
            Layout.preferredWidth: 215
            text: parent.combo
            color: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            text: parent.action
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
    }

    component ShortcutCard: Rectangle {
        required property string heading
        required property var entries
        Layout.fillWidth: true
        implicitHeight: cardContent.implicitHeight + 28
        radius: 14
        color: Qt.alpha(root.surfaceColor, 0.58)
        border.width: 1
        border.color: Qt.alpha(root.mutedColor, 0.48)

        ColumnLayout {
            id: cardContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: parent.parent.heading
                color: root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: 16
                font.weight: Font.Bold
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.alpha(root.mutedColor, 0.45)
            }
            Repeater {
                model: parent.parent.entries
                KeyRow {
                    required property var modelData
                    combo: modelData.combo
                    action: modelData.action
                }
            }
        }
    }

    component ShortcutPage: Flickable {
        id: page
        required property var leftCards
        required property var rightCards
        contentWidth: width
        contentHeight: pageColumns.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        RowLayout {
            id: pageColumns
            width: page.width - 14
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 16
                Repeater {
                    model: page.leftCards
                    ShortcutCard {
                        required property var modelData
                        heading: modelData.heading
                        entries: modelData.entries
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 16
                Repeater {
                    model: page.rightCards
                    ShortcutCard {
                        required property var modelData
                        heading: modelData.heading
                        entries: modelData.entries
                    }
                }
            }
        }
    }

    FloatingWindow {
        id: shortcutWindow
        visible: true
        title: "Noctiri Shortcuts"
        implicitWidth: 980
        implicitHeight: 720
        minimumSize.width: 720
        minimumSize.height: 480
        maximumSize.width: 1600
        maximumSize.height: 1000
        color: root.backgroundColor
        surfaceFormat.opaque: true

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: root.backgroundColor
            border.width: 1
            border.color: root.accentColor
            focus: true
            Keys.onEscapePressed: root.closeWindow()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 48
                        cursorShape: Qt.SizeAllCursor
                        onPressed: shortcutWindow.startSystemMove()
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "Noctiri shortcuts"
                            color: root.foregroundColor
                            font.family: root.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.Bold
                        }
                        Text {
                            text: "Drag the header to move · choose a tab for app-specific controls"
                            color: root.mutedColor
                            font.family: root.fontFamily
                            font.pixelSize: 13
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 10
                        color: closeMouse.containsMouse ? Qt.alpha(root.urgentColor, 0.22) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: root.foregroundColor
                            font.family: root.fontFamily
                            font.pixelSize: 24
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeWindow()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: root.tabNames
                        Rectangle {
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: 11
                            color: root.activeTab === index
                                ? Qt.alpha(root.accentColor, 0.2)
                                : tabMouse.containsMouse ? Qt.alpha(root.surfaceColor, 0.7) : Qt.alpha(root.surfaceColor, 0.42)
                            border.width: root.activeTab === index ? 1 : 0
                            border.color: root.accentColor
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: root.activeTab === index ? root.accentColor : root.foregroundColor
                                font.family: root.fontFamily
                                font.pixelSize: 14
                                font.weight: root.activeTab === index ? Font.Bold : Font.Medium
                            }
                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = index
                            }
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.activeTab
                    ShortcutPage { leftCards: root.desktopLeft; rightCards: root.desktopRight }
                    ShortcutPage { leftCards: root.nvimLeft; rightCards: root.nvimRight }
                    ShortcutPage { leftCards: root.yaziLeft; rightCards: root.yaziRight }
                    ShortcutPage { leftCards: root.rmpcLeft; rightCards: root.rmpcRight }
                }
            }

            MouseArea {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 22
                height: 22
                cursorShape: Qt.SizeFDiagCursor
                onPressed: shortcutWindow.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
            }
        }

        IpcHandler {
            target: "shortcuts"
            function toggle(): void {
                if (shortcutWindow.visible)
                    root.closeWindow();
                else
                    shortcutWindow.visible = true;
            }
        }
    }
}
