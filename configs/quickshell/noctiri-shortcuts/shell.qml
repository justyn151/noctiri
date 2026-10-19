//@ pragma AppId noctiri-shortcuts

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root

    readonly property string fontFamily: "FantasqueSansM Nerd Font"

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

    readonly property var essentials: [
        { combo: "Super + Shift + /", action: "Toggle this shortcut window" },
        { combo: "Super + T", action: "Open Kitty" },
        { combo: "Super + D", action: "Open the app launcher" },
        { combo: "Super + P", action: "Open the wallpaper picker" },
        { combo: "Super + E", action: "Open Yazi in Kitty" },
        { combo: "Super + Shift + S", action: "Take a screenshot" },
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
        { combo: "Super + Shift + Up / Down", action: "Move the focused stacked window" },
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
        color: "transparent"
        surfaceFormat.opaque: false

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: root.backgroundColor
            border.width: 1
            border.color: root.accentColor
            focus: true
            Keys.onEscapePressed: shortcutWindow.visible = false

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
                            text: "Drag this header to move · drag the bottom-right corner to resize"
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
                            onClicked: shortcutWindow.visible = false
                        }
                    }
                }

                Flickable {
                    id: shortcutScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: columns.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    RowLayout {
                        id: columns
                        width: shortcutScroll.width - 14
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 16

                            ShortcutCard { heading: "Essentials"; entries: root.essentials }
                            ShortcutCard { heading: "Focus and navigation"; entries: root.focusBindings }
                            ShortcutCard { heading: "System"; entries: root.systemBindings }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 16

                            ShortcutCard { heading: "Move windows and workspaces"; entries: root.movement }
                            ShortcutCard { heading: "Layout"; entries: root.layoutBindings }
                        }
                    }
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
                shortcutWindow.visible = !shortcutWindow.visible;
            }
        }
    }
}
