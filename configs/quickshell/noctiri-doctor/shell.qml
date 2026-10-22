//@ pragma AppId noctiri-doctor

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root

    readonly property string fontFamily: "sans-serif"
    property string report: "Preparing desktop checks…"
    property string processError: ""
    property bool checking: false
    property int passed: 0
    property int warnings: 0
    property int failures: 0
    property int activeTab: 0
    property string operation: "health"
    property bool rollbackArmed: false
    readonly property var tabNames: ["Health", "Maintenance", "Memory", "Fonts"]
    readonly property var fontLabels: ["DepartureMono", "Fantasque Sans Mono", "Maple Mono NF", "Cozette · Kitty only"]
    readonly property var fontProfiles: ["departure", "fantasque", "maple", "cozette"]

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

    function cleanOutput(output) {
        return output.replace(/\x1b\[[0-9;]*m/g, "");
    }

    function closeWindow() {
        // This panel is on demand. Hiding its final window would leave an
        // otherwise idle Qt/Quickshell process resident in memory.
        Qt.quit();
    }

    function runProcess(command, message, operationName) {
        if (checking)
            return;
        checking = true;
        operation = operationName;
        rollbackArmed = false;
        processError = "";
        report = message;
        reportScroll.contentY = 0;
        doctorProcess.command = command;
        doctorProcess.running = true;
    }

    function runDoctor(repair) {
        runProcess(
            repair ? ["noctiri-doctor", "--repair"] : ["noctiri-doctor"],
            repair ? "Applying safe user-session repairs…" : "Checking the desktop session…",
            "health"
        );
    }

    function runMaintenance() {
        runProcess(["noctiri", "maintenance"], "Reading snapshots and update state…", "maintenance");
    }

    function runMemory() {
        runProcess(["noctiri", "memory"], "Measuring proportional memory use…", "memory");
    }

    function runStartup(kitty) {
        runProcess(kitty ? ["noctiri", "startup", "--kitty"] : ["noctiri", "startup"],
                   "Checking this login session…", "startup");
    }

    function runFonts() {
        runProcess(["noctiri", "font", "status"], "Reading font selection…", "fonts-status");
    }

    function runNoctiriAction(arguments, message, operationName) {
        runProcess(["env", "NOCTIRI_GUI=true", "noctiri"].concat(arguments), message, operationName);
    }

    function selectTab(index) {
        if (checking)
            return;
        activeTab = index;
        rollbackArmed = false;
        if (index === 0)
            runDoctor(false);
        else if (index === 1)
            runMaintenance();
        else if (index === 2)
            runMemory();
        else
            runFonts();
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
                root.report = root.cleanOutput(text);
                if (root.operation === "health")
                    root.parseSummary(text);
                if (root.operation === "fonts-status") {
                    const match = text.match(/Selected font: (departure|fantasque|maple|cozette)/);
                    if (match)
                        fontChoice.currentIndex = root.fontProfiles.indexOf(match[1]);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: root.processError = root.cleanOutput(text)
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
            Keys.onEscapePressed: root.closeWindow()

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
                            text: root.checking ? "Working…" : root.activeTab === 0
                                ? "Desktop health and safe session recovery"
                                : root.activeTab === 1
                                    ? "Snapshots, updates, and validated rollback"
                                    : "Actual process cost and reclaimable memory"
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
                                : tabMouse.containsMouse ? Qt.alpha(root.surfaceColor, 0.72) : Qt.alpha(root.surfaceColor, 0.42)
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
                                enabled: !root.checking
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.selectTab(index)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.activeTab === 0
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
                    visible: root.activeTab === 0
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

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.activeTab === 1
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        text: "Updates snapshot first. A graphical administrator prompt appears only when a protected file changes."
                        color: root.mutedColor
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    ActionButton {
                        label: "Refresh"
                        available: !root.checking
                        onClicked: root.runMaintenance()
                    }
                    ActionButton {
                        label: "Snapshot"
                        available: !root.checking
                        onClicked: root.runNoctiriAction(["snapshot"], "Creating a configuration snapshot…", "snapshot")
                    }
                    ActionButton {
                        label: "Update"
                        primary: true
                        available: !root.checking
                        onClicked: root.runNoctiriAction(["update"], "Updating Noctiri safely…", "update")
                    }
                    ActionButton {
                        label: root.rollbackArmed ? "Confirm rollback" : "Rollback latest"
                        available: !root.checking
                        onClicked: {
                            if (!root.rollbackArmed) {
                                root.rollbackArmed = true;
                                root.report = "Press Confirm rollback to restore the newest snapshot. A safety snapshot will be created first.";
                            } else {
                                root.runNoctiriAction(["rollback", "latest", "--yes"], "Restoring the newest snapshot…", "rollback");
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.activeTab === 2
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        text: "PSS is the useful application figure because shared libraries are counted proportionally."
                        color: root.mutedColor
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    ActionButton {
                        label: "Refresh memory"
                        primary: true
                        available: !root.checking
                        onClicked: root.runMemory()
                    }
                    ActionButton {
                        label: "Login check"
                        available: !root.checking
                        onClicked: root.runStartup(false)
                    }
                    ActionButton {
                        label: "Check Kitty"
                        available: !root.checking
                        onClicked: root.runStartup(true)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.activeTab === 3
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        text: "Cozette changes Kitty only; Maple remains the UI font. Reopen apps after applying."
                        color: root.mutedColor
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    ComboBox {
                        id: fontChoice
                        Layout.preferredWidth: 220
                        implicitHeight: 38
                        model: root.fontLabels
                        enabled: !root.checking
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        background: Rectangle {
                            radius: 9
                            color: Qt.alpha(root.surfaceColor, 0.72)
                            border.width: 1
                            border.color: root.accentColor
                        }
                        contentItem: Text {
                            leftPadding: 12
                            rightPadding: fontChoice.indicator.width + fontChoice.spacing
                            text: fontChoice.displayText
                            color: root.foregroundColor
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                    ActionButton {
                        label: "Apply font"
                        primary: true
                        available: !root.checking
                        onClicked: root.runNoctiriAction(
                            ["font", "set", root.fontProfiles[fontChoice.currentIndex]],
                            "Applying " + fontChoice.currentText + "…", "fonts-set")
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
            function toggle(): void {
                if (doctorWindow.visible)
                    root.closeWindow();
                else
                    doctorWindow.visible = true;
            }
            function refresh(): void { root.runDoctor(false); }
        }
    }
}
