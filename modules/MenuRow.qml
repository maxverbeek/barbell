import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// One line of the audio menu — either a selectable device or a volume slider.
// Both shapes live here because they share the highlight, the hover-selects
// behaviour and the row metrics; splitting them would mean keeping three
// files in sync over four differences.
Item {
    id: root

    required property var row
    property bool active: false
    property string heading: ""

    signal hovered()
    signal clicked()
    signal scrolled(real delta)

    readonly property bool isVolume: row.kind === "volume"
    readonly property bool isSource: row.kind === "source"
        || (isVolume && row.which === "source")
    readonly property bool current: !isVolume
        && row.node === (isSource ? Audio.source : Audio.sink)

    readonly property real level: isSource ? Audio.micVolume : Audio.sinkVolume
    readonly property bool muted: isSource ? Audio.micMuted : Audio.sinkMuted

    implicitHeight: (heading !== "" ? label.implicitHeight + 8 : 0) + 28

    Text {
        id: label
        visible: root.heading !== ""
        text: root.heading
        color: Theme.fgFaint
        font { family: Theme.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 0.6 }
        anchors { left: parent.left; leftMargin: 6; top: parent.top; topMargin: 3 }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 28
        radius: 6
        // Selection is the keyboard's cursor, so it has to be visible without
        // a pointer anywhere near it.
        color: root.active ? Theme.islandActive : "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 8 }
            spacing: 8

            Text {
                text: root.isVolume
                        ? (root.isSource ? (root.muted ? "󰍭" : "󰍬")
                                         : (root.muted ? "󰝟" : "󰕾"))
                    : root.current ? "󰄬"      // the active device
                    : " "
                font { family: Theme.iconFont; pixelSize: 13 }
                color: root.muted && root.isVolume ? Theme.bad
                    : root.current ? Theme.good
                    : Theme.fgDim
                Layout.preferredWidth: 16
            }

            // A device row names the device; a volume row shows a bar.
            Text {
                visible: !root.isVolume
                text: Audio.label(root.row.node)
                color: root.current ? Theme.fg : Theme.fgDim
                font {
                    family: Theme.font
                    pixelSize: 12
                    weight: root.current ? Font.DemiBold : Font.Normal
                }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                visible: root.isVolume
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                Layout.alignment: Qt.AlignVCenter
                radius: 2
                color: Theme.sumiInk4

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.level))
                    height: parent.height
                    radius: parent.radius
                    color: root.muted ? Theme.bad : Theme.accent
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }

            Text {
                visible: root.isVolume
                text: Math.round(root.level * 100)
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: 11 }
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 22
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hovered()
            onClicked: root.clicked()
            onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }
}
