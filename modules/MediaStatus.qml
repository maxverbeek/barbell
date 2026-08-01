import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."
import "../services" as Svc

// What's playing, in the middle of the bar — the one place with room, and the
// one thing transient enough to earn it. Gone entirely when nothing plays.
//
// Transport controls sit beside the title and fade in on hover. They keep
// their space when hidden: anything that resizes on hover moves the title out
// from under the pointer, which unhovers the widget and collapses it again.
Item {
    id: root

    visible: Svc.Media.active
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 22

    // One MouseArea over the whole widget decides this, buttons included — it
    // sits behind them so they take their own clicks while it keeps the hover.
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

        // The space is reserved whether or not the buttons are showing, so they
        // fade rather than expand. Animating the width pushed the title left
        // out from under the pointer, which unhovered the widget, which
        // collapsed it back — a loop you could feel as a flicker.
        RowLayout {
            id: transport

            spacing: 4
            Layout.alignment: Qt.AlignVCenter
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            MediaButton {
                id: prev
                active: root.hovered
                glyph: "󰒮"
                enabled: Svc.Media.player?.canGoPrevious ?? false
                onTriggered: Svc.Media.previous()
            }

            MediaButton {
                id: play
                active: root.hovered
                glyph: Svc.Media.playing ? "󰏤" : "󰐊"
                onTriggered: Svc.Media.toggle()
            }

            MediaButton {
                id: next
                active: root.hovered
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
