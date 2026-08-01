import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."
import "../services" as Svc

// What's playing, in the middle of the bar — the one place with room, and the
// one thing transient enough to earn it. Gone entirely when nothing plays, so
// the centre is empty the rest of the time.
//
// Hovering swaps the text for transport controls rather than putting them
// beside it: three buttons permanently on the bar for something you press
// twice a day is the wrong trade, and the text is the thing you glance at.
Item {
    id: root

    visible: Svc.Media.active
    implicitWidth: visible ? Math.min(content.implicitWidth, 320) : 0
    implicitHeight: 20

    readonly property bool hovered: area.containsMouse

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 8

        // Album art when the player offers it, a note when it doesn't. Small
        // enough to read as a marker rather than a thumbnail.
        IconImage {
            visible: Svc.Media.art !== ""
            source: Svc.Media.art
            implicitSize: 16
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            visible: Svc.Media.art === ""
            text: "󰎈"
            font { family: Theme.iconFont; pixelSize: 13 }
            color: Theme.fgDim
            Layout.alignment: Qt.AlignVCenter
        }

        // Text and controls occupy the same slot, so hovering doesn't shift
        // the bar's centre.
        Item {
            Layout.preferredWidth: Math.max(label.implicitWidth, transport.implicitWidth)
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: label
                anchors.centerIn: parent
                opacity: root.hovered ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 120 } }

                // Artist first reads better at a glance than title first —
                // you usually know the album and are checking the track.
                text: Svc.Media.artist !== ""
                    ? `${Svc.Media.artist} — ${Svc.Media.title}`
                    : Svc.Media.title
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: 12 }
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 300)
            }

            RowLayout {
                id: transport
                anchors.centerIn: parent
                spacing: 10
                opacity: root.hovered ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Repeater {
                    model: [
                        { glyph: "󰒮", act: () => Svc.Media.previous(), can: Svc.Media.player?.canGoPrevious ?? false },
                        { glyph: Svc.Media.playing ? "󰏤" : "󰐊", act: () => Svc.Media.toggle(), can: true },
                        { glyph: "󰒭", act: () => Svc.Media.next(), can: Svc.Media.player?.canGoNext ?? false }
                    ]

                    delegate: Text {
                        required property var modelData

                        text: modelData.glyph
                        font { family: Theme.iconFont; pixelSize: 14 }
                        color: !modelData.can ? Theme.fgFaint
                            : btn.containsMouse ? Theme.fg
                            : Theme.fgDim
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            id: btn
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            enabled: modelData.can
                            onClicked: modelData.act()
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // Below the transport buttons so they win the click.
        z: -1
        onClicked: mouse => {
            // Middle-click is the quick pause; left-click raises the player,
            // which is what you want when you're trying to find the tab.
            if (mouse.button === Qt.MiddleButton) Svc.Media.toggle();
            else Svc.Media.raise();
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) Svc.Media.next();
            else Svc.Media.previous();
        }
    }
}
