import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."
import "../services" as Svc

// What's playing, in the middle of the bar — the one place with room, and the
// one thing transient enough to earn it. Gone entirely when nothing plays.
//
// Transport controls slide in beside the title on hover rather than replacing
// it: swapping text for buttons in the same slot means one of them is always
// off-centre, and you lose sight of what you're skipping away from.
Item {
    id: root

    visible: Svc.Media.active
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 22

    // One MouseArea spanning the whole widget decides this. Asking the buttons
    // whether they're hovered too would be circular — they only exist while
    // hovered, so they'd keep themselves alive.
    readonly property bool hovered: area.containsMouse

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        // Album art when the player offers it, a note when it doesn't. Rounded
        // so a square cover doesn't fight the rest of the bar.
        ClippingRectangle {
            visible: Svc.Media.art !== ""
            implicitWidth: 16
            implicitHeight: 16
            radius: 3
            color: "transparent"
            Layout.alignment: Qt.AlignVCenter

            Image {
                anchors.fill: parent
                source: Svc.Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Text {
            visible: Svc.Media.art === ""
            text: "󰎈"
            font { family: Theme.iconFont; pixelSize: 13 }
            color: Theme.fgDim
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            // Artist first reads better at a glance than title first — you
            // usually know the album and are checking the track.
            text: Svc.Media.artist !== ""
                ? `${Svc.Media.artist} — ${Svc.Media.title}`
                : Svc.Media.title
            color: root.hovered ? Theme.fg : Theme.fgDim
            font { family: Theme.font; pixelSize: 12 }
            elide: Text.ElideRight
            Layout.maximumWidth: 260
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Slides out from nothing, so the bar's centre only shifts while
        // you're pointing at it.
        RowLayout {
            id: transport
            readonly property bool hovered: prev.hovered || play.hovered || next.hovered

            spacing: 4
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.hovered ? implicitWidth : 0
            opacity: root.hovered ? 1 : 0
            visible: Layout.preferredWidth > 0
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on opacity { NumberAnimation { duration: 140 } }

            MediaButton {
                id: prev
                glyph: "󰒮"
                enabled: Svc.Media.player?.canGoPrevious ?? false
                onTriggered: Svc.Media.previous()
            }

            MediaButton {
                id: play
                glyph: Svc.Media.playing ? "󰏤" : "󰐊"
                onTriggered: Svc.Media.toggle()
            }

            MediaButton {
                id: next
                glyph: "󰒭"
                enabled: Svc.Media.player?.canGoNext ?? false
                onTriggered: Svc.Media.next()
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // Below the buttons so they take their own clicks.
        z: -1
        onClicked: mouse => {
            // Middle-click pauses; left-click raises the player, which is what
            // you want when you're hunting for the tab it's playing in.
            if (mouse.button === Qt.MiddleButton) Svc.Media.toggle();
            else Svc.Media.raise();
        }
        // No wheel handler: on a trackpad a stray two-finger drag would skip
        // the track, and an accidental skip is far worse than no shortcut.
    }
}
