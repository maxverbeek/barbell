import QtQuick
import ".."
import "../services"

// The recorder's button: a plain mic, with a dot appended while recording.
// Opens the mictap tab, where the stop button and today's recordings are.
Item {
    id: root

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: area.containsMouse || Menus.isOpen("mictap") ? Theme.islandHover : Theme.island
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Mictap.recording ? "󰍬 ●" : "󰍬"
        color: Theme.fg
        font { family: Theme.iconFont; pixelSize: 14 }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Menus.toggle("mictap")
    }
}
