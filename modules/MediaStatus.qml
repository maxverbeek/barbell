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

    // A hoverEnabled MouseArea swallows hover rather than passing it down, so
    // the buttons' own areas have to count too: once they enable, the pointer
    // sitting on one no longer reaches `area` at all. Reading only `area` made
    // the buttons fade in, steal the hover, fade out, and hand it back — an
    // oscillation you could see as a half-hovered flicker over the controls.
    readonly property bool hovered:
        area.containsMouse || prev.hovered || play.hovered || next.hovered

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        // Ghost of the transport controls, same width, on the mirror side. The
        // controls reserve their space even when invisible (see below), which
        // pushed the title left of the bar's true centre — visibly off, since
        // this widget's whole job is to sit in the middle. Balancing the row
        // instead of shifting it keeps the no-move-on-hover invariant intact.
        Item { Layout.preferredWidth: transport.implicitWidth; implicitHeight: 1 }

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
            font { family: Theme.iconFont; pixelSize: 14 }
            color: Theme.fgDim
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            // Artist first reads better at a glance than title first — you
            // usually know the album and are checking the track.
            text: Svc.Media.artist !== ""
                ? `${Svc.Media.artist} — ${Svc.Media.title}`
                : Svc.Media.title
            // Paused sits back a shade, so a stopped track doesn't read the same
            // as one that's playing when you're only glancing at the bar.
            color: root.hovered ? Theme.fg
                : Svc.Media.playing ? Theme.fgDim
                : Theme.fgFaint
            font { family: Theme.font; pixelSize: 13 }
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
