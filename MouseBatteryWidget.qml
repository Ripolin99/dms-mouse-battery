import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "mouse-battery"

    readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")
    readonly property string dpiScript: pluginDir + "mouse-dpi.sh"
    readonly property string batteryScript: pluginDir + "battery-query.sh"

    readonly property int pollInterval: (pluginData.pollInterval || 60) * 1000
    readonly property string upowerType: pluginData.upowerType || "mouse"
    readonly property string hideWhenAbsent: pluginData.hideWhenAbsent === undefined ? "true" : String(pluginData.hideWhenAbsent)
    readonly property string forcedBackend: pluginData.dpiBackend || ""
    readonly property string forcedDevice: pluginData.dpiDevice || ""
    readonly property var presetDpi: parsePresetList(pluginData.presetDpi)

    function parsePresetList(raw) {
        const fallback = [400, 600, 800, 1200, 1600, 2000, 2400, 3200, 4000, 4800, 6400, 8000]
        if (raw === undefined || raw === null || raw === "") return fallback
        let arr = Array.isArray(raw) ? raw : String(raw).split(/[,\s]+/)
        arr = arr.map(v => {
            if (typeof v === "object" && v && v.value !== undefined) return parseInt(v.value, 10)
            return parseInt(v, 10)
        }).filter(n => !isNaN(n) && n > 0)
        return arr.length > 0 ? arr : fallback
    }

    property bool batteryPresent: false
    property int percentage: 0
    property string deviceModel: ""
    property string deviceState: ""
    property string upowerIcon: ""

    property string dpiBackend: "none"
    property int currentDpi: -1

    readonly property bool visibleNow: batteryPresent || hideWhenAbsent !== "true"

    function shellEscape(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function envPrefix() {
        let env = ""
        if (forcedBackend && forcedBackend !== "auto")
            env += "MOUSE_DPI_BACKEND=" + shellEscape(forcedBackend) + " "
        if (forcedDevice)
            env += "MOUSE_DPI_DEVICE=" + shellEscape(forcedDevice) + " "
        return env
    }

    function refreshBattery() {
        Proc.runCommand(
            "mouseBattery.battery",
            ["sh", "-c", shellEscape(batteryScript) + " " + shellEscape(upowerType)],
            (stdout, exitCode) => {
                if (exitCode !== 0) {
                    batteryPresent = false
                    return
                }
                const data = {}
                stdout.split("\n").forEach(line => {
                    const eq = line.indexOf("=")
                    if (eq > 0) data[line.slice(0, eq)] = line.slice(eq + 1).trim()
                })
                if (!data.path) {
                    batteryPresent = false
                    return
                }
                batteryPresent = true
                percentage = parseInt(data.percentage || "0", 10)
                deviceModel = data.model || ""
                deviceState = data.state || ""
                upowerIcon = data.icon || ""
            },
            50
        )
    }

    function refreshDpi() {
        Proc.runCommand(
            "mouseBattery.dpiDetect",
            ["sh", "-c", envPrefix() + shellEscape(dpiScript) + " detect"],
            (stdout) => { dpiBackend = (stdout || "").trim() || "none" },
            50
        )
        Proc.runCommand(
            "mouseBattery.dpiGet",
            ["sh", "-c", envPrefix() + shellEscape(dpiScript) + " get"],
            (stdout) => {
                const v = parseInt((stdout || "").trim(), 10)
                if (!isNaN(v) && v > 0) currentDpi = v
            },
            50
        )
    }

    function setDpi(value) {
        const v = Math.round(value)
        Proc.runCommand(
            "mouseBattery.dpiSet",
            ["sh", "-c", envPrefix() + shellEscape(dpiScript) + " set " + shellEscape(String(v))],
            (_stdout, exitCode) => {
                if (exitCode === 0) {
                    currentDpi = v
                    if (typeof ToastService !== "undefined")
                        ToastService.showInfo("Mouse DPI", "Set to " + v + " DPI")
                } else if (typeof ToastService !== "undefined") {
                    ToastService.showError("Mouse DPI", "Failed to set DPI (backend: " + dpiBackend + ")")
                }
            },
            50
        )
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refreshBattery()
    }

    Component.onCompleted: {
        refreshBattery()
        refreshDpi()
    }

    function batteryColor(pct, state) {
        if (state === "charging" || state === "fully-charged" || state === "pending-charge")
            return Theme.primary
        if (pct <= 15) return Theme.error
        if (pct <= 30) return Theme.warning !== undefined ? Theme.warning : Theme.error
        return Theme.surfaceText
    }

    function batteryIcon(pct, state) {
        if (state === "charging") return "battery_charging_full"
        if (pct >= 90) return "battery_full"
        if (pct >= 75) return "battery_6_bar"
        if (pct >= 60) return "battery_5_bar"
        if (pct >= 45) return "battery_4_bar"
        if (pct >= 30) return "battery_3_bar"
        if (pct >= 20) return "battery_2_bar"
        if (pct >= 10) return "battery_1_bar"
        return "battery_alert"
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            visible: root.visibleNow

            DankIcon {
                name: "mouse"
                size: Theme.iconSize - 6
                color: root.batteryColor(root.percentage, root.deviceState)
                anchors.verticalCenter: parent.verticalCenter
            }

            DankIcon {
                name: root.batteryIcon(root.percentage, root.deviceState)
                size: Theme.iconSize - 8
                color: root.batteryColor(root.percentage, root.deviceState)
                anchors.verticalCenter: parent.verticalCenter
                visible: root.batteryPresent
            }

            StyledText {
                text: root.batteryPresent ? (root.percentage + "%") : "—"
                color: root.batteryColor(root.percentage, root.deviceState)
                font.pixelSize: Theme.fontSizeMedium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            visible: root.visibleNow

            DankIcon {
                name: "mouse"
                size: Theme.iconSize - 6
                color: root.batteryColor(root.percentage, root.deviceState)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.batteryPresent ? (root.percentage + "%") : "—"
                color: root.batteryColor(root.percentage, root.deviceState)
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 360
    popoutHeight: 320

    popoutContent: Component {
        PopoutComponent {
            id: popoutRoot

            headerText: root.deviceModel || "Mouse"
            detailsText: root.batteryPresent
                ? ("Battery: " + root.percentage + "% — " + (root.deviceState || "unknown"))
                : "No wireless mouse detected"
            showCloseButton: true

            Component.onCompleted: {
                root.refreshBattery()
                root.refreshDpi()
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledRect {
                    width: parent.width
                    height: 40
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "speed"
                            size: Theme.iconSize - 8
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "DPI"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        StyledText {
                            text: root.currentDpi > 0 ? (root.currentDpi + " DPI") : "—"
                            color: Theme.primary
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "(" + root.dpiBackend + ")"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: root.dpiBackend === "none"
                    text: "No DPI backend detected. Install <b>solaar</b> (Logitech) or <b>libratbag</b> (generic) to enable DPI control."
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                }

                Grid {
                    id: presetGrid
                    width: parent.width
                    columns: 4
                    spacing: Theme.spacingS
                    visible: root.dpiBackend !== "none"

                    readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

                    Repeater {
                        model: root.presetDpi
                        StyledRect {
                            readonly property bool selected: modelData === root.currentDpi
                            width: presetGrid.cellWidth
                            height: 36
                            radius: Theme.cornerRadius
                            color: presetArea.containsMouse
                                ? (selected ? Qt.darker(Theme.primaryContainer, 1.1) : Theme.surfaceContainerHighest)
                                : (selected ? Theme.primaryContainer : Theme.surfaceContainerHigh)
                            border.width: selected ? 2 : 0
                            border.color: Theme.primary

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                color: parent.selected ? Theme.primaryText : Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: presetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setDpi(modelData)
                            }
                        }
                    }
                }

                StyledRect {
                    width: parent.width
                    height: 36
                    radius: Theme.cornerRadius
                    color: refreshArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                    visible: root.dpiBackend !== "none"

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        DankIcon {
                            name: "refresh"
                            size: Theme.iconSize - 10
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: "Refresh"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.refreshBattery()
                            root.refreshDpi()
                        }
                    }
                }
            }
        }
    }
}
