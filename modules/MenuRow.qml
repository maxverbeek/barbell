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


    // Drag target. Setting a level explicitly rather than nudging, so the
    // pointer position is the value.
    function setFraction(f) {
        const v = Math.max(0, Math.min(1, f));
        if (isSource) Audio.setMicVolume(v);
        else Audio.setSinkVolume(v);
    }

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

            // The grab area is the full row height, not the 4px bar — a hairline
            // is a miserable drag target. The bar is drawn inside it.
            Item {
                id: slider
                visible: root.isVolume
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real fraction:
                    Math.max(0, Math.min(1, root.level))

                Rectangle {
                    id: track
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    height: 4
                    radius: 2
                    color: Theme.sumiInk4

                    Rectangle {
                        width: track.width * slider.fraction
                        height: parent.height
                        radius: parent.radius
                        color: root.muted ? Theme.bad : Theme.accent
                        // The animation is for keyboard nudges and external
                        // changes; during a drag it would lag the pointer, so
                        // it's off while the grab is live.
                        Behavior on width {
                            enabled: !drag.pressed
                            NumberAnimation { duration: 90 }
                        }
                    }
                }

                // Only while dragging, so a static menu stays clean.
                Rectangle {
                    visible: drag.pressed
                    width: 10
                    height: 10
                    radius: 5
                    color: root.muted ? Theme.bad : Theme.accent
                    x: track.width * slider.fraction - width / 2
                    anchors.verticalCenter: track.verticalCenter
                }

                MouseArea {
                    id: drag
                    anchors.fill: parent
                    hoverEnabled: true
                    // Jump to where you pressed, then track the pointer. Keeping
                    // the press and the move on one handler means a click and a
                    // drag are the same gesture.
                    onPressed: mouse => { root.hovered(); root.setFraction(mouse.x / width); }
                    onPositionChanged: mouse => { if (pressed) root.setFraction(mouse.x / width); }
                    onEntered: root.hovered()
                    onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
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

        // Sits behind the slider's own handler, so on a volume row this only
        // catches the icon and the readout; the drag area takes the middle.
        MouseArea {
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            onEntered: root.hovered()
            onClicked: root.clicked()
            onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }
}
