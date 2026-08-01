import QtQuick
import QtQuick.Layouts
import ".."

// One transport control. A real hit target rather than a bare glyph — 14px of
// icon is a miserable thing to aim at, so the button is 22px square with the
// glyph centred in it.
Item {
    id: root

    property string glyph: ""
    property bool enabled: true
    readonly property bool hovered: area.containsMouse

    signal triggered()

    implicitWidth: 22
    implicitHeight: 22
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.hovered && root.enabled ? Theme.islandHover : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font { family: Theme.iconFont; pixelSize: 14 }
        color: !root.enabled ? Theme.fgFaint
            : root.hovered ? Theme.fg
            : Theme.fgDim
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        onClicked: root.triggered()
    }
}
