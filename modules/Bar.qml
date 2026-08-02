import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import ".."
import "../services"

PanelWindow {
    // Variants injects the screen as `modelData`.
    required property var modelData
    screen: modelData

    anchors { top: !Theme.bottom; bottom: Theme.bottom; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.barBg

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 14

            Workspaces { screenName: modelData.name }

            // Two spacers so media sits in the true centre of the bar rather
            // than wherever the widgets around it leave room.
            Item { Layout.fillWidth: true }

            MediaStatus { Layout.alignment: Qt.AlignVCenter }

            Item { Layout.fillWidth: true }

            // Exceptions and the always-drawn constants, in a fixed order.
            SysStatus { Layout.alignment: Qt.AlignVCenter }

            ClaudeStatus { Layout.alignment: Qt.AlignVCenter }

            KubeContext { Layout.alignment: Qt.AlignVCenter }

            Tray { Layout.alignment: Qt.AlignVCenter }

            // Network, bluetooth and audio as one button into the menus.
            Island { Layout.alignment: Qt.AlignVCenter }

            Battery {
                // No battery on a desktop, and displayDevice is briefly null at startup.
                visible: UPower.displayDevice?.isLaptopBattery ?? false
                percent: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)
                charging: UPower.displayDevice?.state === UPowerDeviceState.Charging
                Layout.alignment: Qt.AlignVCenter
            }

            Clock {}
        }
    }
}
