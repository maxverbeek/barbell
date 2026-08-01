import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

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
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Workspaces { screenName: modelData.name }

            Item { Layout.fillWidth: true }

            Clock {}
        }
    }
}
