//@ pragma AppId noctiri-doctor

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root

    readonly property string fontFamily: "FantasqueSansM Nerd Font"
    property string report: "Preparing desktop checks…"
    property string processError: ""
    property bool checking: false
    property int passed: 0
    property int warnings: 0
    property int failures: 0

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
    readonly property color warningColor: paletteValue("color3", "#e8c982")
    readonly property color failureColor: paletteValue("color1", "#ffb4ab")
    readonly property color successColor: paletteValue("color2", "#a6d189")

    function parseSummary(output) {
        const match = output.match(/(\d+) passed, (\d+) warning\(s\), (\d+) failure\(s\)/);
        if (!match)
            return;
        passed = Number(match[1]);
        warnings = Number(match[2]);
        failures = Number(match[3]);
    }

    function runDoctor(repair) {
        if (checking)
            return;
        checking = true;
        processError = "";
        report = repair ? "Applying safe user-session repairs…" : "Checking the desktop session…";
        doctorProcess.command = repair ? ["noctiri-doctor", "--repair"] : ["noctiri-doctor"];
        doctorProcess.running = true;
    }

    Component.onCompleted: runDoctor(false)

    FileView {
        id: paletteFile
        path: Quickshell.env("HOME") + "/.config/kitty/themes/noctalia.conf"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    Process {
        id: doctorProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.report = text;
                root.parseSummary(text);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: root.processError = text
        }

        onExited: function(exitCode, exitStatus) {
            root.checking = false;
            if (root.processError.length > 0 && root.report.length === 0)
                root.report = root.processError;
            if (exitCode !== 0 && root.failures === 0 && root.report.indexOf("failure(s)") === -1)
                root.processError = "The doctor command exited with status " + exitCode + ".\n" + root.processError;
        }
    }

    component MetricCard: Rectangle {
        required property string label
        required property int count
        required property color metricColor

        Layout.fillWidth: true
        implicitHeight: 72
        radius: 14
        color: Qt.alpha(root.surfaceColor, 0.55)
        border.width: 1
        border.color: Qt.alpha(metricColor, 0.58)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Text {
                text: parent.parent.count
                color: parent.parent.metricColor
                font.family: root.fontFamily
                font.pixelSize: 28
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: parent.parent.label
                color: root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: 14
            }
        }
    }

    component ActionButton: Rectangle {
        required property string label
        property bool available: true
        property bool primary: false
        signal clicked()

        implicitWidth: 138
        implicitHeight: 40
        radius: 11
        opacity: available ? 1 : 0.45
        color: primary
            ? Qt.alpha(root.accentColor, buttonMouse.containsMouse ? 0.32 : 0.22)
            : Qt.alpha(root.surfaceColor, buttonMouse.containsMouse ? 0.82 : 0.58)
        border.width: 1
        border.color: primary ? root.accentColor : Qt.alpha(root.mutedColor, 0.5)

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: parent.primary ? root.accentColor : root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: parent.available
            hoverEnabled: true
            cursorShape: parent.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: parent.clicked()
        }
    }

    FloatingWindow {
        id: doctorWindow
        visible: true
        title: "Noctiri Doctor"
        implicitWidth: 900
        implicitHeight: 680
        minimumSize.width: 680
        minimumSize.height: 460
        maximumSize.width: 1500
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
            Keys.onEscapePressed: doctorWindow.visible = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 52

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 48
                        cursorShape: Qt.SizeAllCursor
                        onPressed: doctorWindow.startSystemMove()
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "Noctiri Doctor"
                            color: root.foregroundColor
                            font.family: root.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.Bold
                        }
                        Text {
                            text: root.checking ? "Working…" : "Desktop health and safe session recovery"
                            color: root.checking ? root.accentColor : root.mutedColor
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
                        color: closeMouse.containsMouse ? Qt.alpha(root.failureColor, 0.22) : "transparent"
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
                            onClicked: doctorWindow.visible = false
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    MetricCard { label: "passed"; count: root.passed; metricColor: root.successColor }
                    MetricCard { label: "warnings"; count: root.warnings; metricColor: root.warningColor }
                    MetricCard { label: "failures"; count: root.failures; metricColor: root.failureColor }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.alpha(root.surfaceColor, 0.43)
                    border.width: 1
                    border.color: Qt.alpha(root.mutedColor, 0.42)

                    Flickable {
                        id: reportScroll
                        anchors.fill: parent
                        anchors.margins: 14
                        contentWidth: width
                        contentHeight: reportText.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Text {
                            id: reportText
                            width: reportScroll.width - 12
                            text: root.report + (root.processError.length > 0 ? "\n\n" + root.processError : "")
                            color: root.foregroundColor
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        text: "Safe repair only restarts user-session components; it does not reinstall packages."
                        color: root.mutedColor
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    ActionButton {
                        label: "Run checks"
                        primary: true
                        available: !root.checking
                        onClicked: root.runDoctor(false)
                    }
                    ActionButton {
                        label: "Safe repair"
                        available: !root.checking
                        onClicked: root.runDoctor(true)
                    }
                }
            }

            MouseArea {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 22
                height: 22
                cursorShape: Qt.SizeFDiagCursor
                onPressed: doctorWindow.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
            }
        }

        IpcHandler {
            target: "doctor"
            function toggle(): void { doctorWindow.visible = !doctorWindow.visible; }
            function refresh(): void { root.runDoctor(false); }
        }
    }
}
