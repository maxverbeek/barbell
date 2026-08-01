import QtQuick
import ".."

// Battery drawn as one element carrying three channels at once: fill width is
// the level, the number is the exact value, fill colour is the state. The
// number sits inside the outline with the fill passing behind it, so no
// separate percentage label is needed.
//
// Deliberately not 100 SVGs: it is a rounded rect, a fill rect and a text node,
// so it themes with the palette for free and any percentage works.
Item {
    id: root

    property int percent: 76
    property bool charging: false
    property bool saver: false

    // Thresholds are the tuning knob; colour reinforces the fill, never replaces it.
    readonly property color state: charging ? Theme.green
        : percent <= 10 ? Theme.red
        : percent <= 25 ? Theme.yellow
        : Theme.fg

    implicitWidth: body.width + cap.width + (charging || saver ? glyph.width + 3 : 0)
    implicitHeight: 15

    Rectangle {
        id: body
        width: 34
        height: 16
        anchors.verticalCenter: parent.verticalCenter
        radius: 5
        color: "transparent"
        border.width: 1.5
        border.color: root.state
        opacity: 0.95

        Rectangle {
            id: fill
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1.5 }
            width: Math.max(2, (parent.width - 3) * Math.min(100, root.percent) / 100)
            radius: 3.5
            color: root.state
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
        }

        // The number is drawn twice, each copy clipped to one side of the fill
        // edge: dark over the filled part, light over the empty part. A single
        // Text can't do this — at 50% the fill cuts through the digits and half
        // of them go invisible whichever colour you pick.
        //
        // Both copies are laid out identically against the body and only the
        // *clip window* differs, so the two halves always line up exactly.
        Repeater {
            model: 2
            delegate: Item {
                required property int index
                anchors.fill: parent
                anchors.margins: 1.5
                clip: true

                // 0 = filled side (clip to the fill), 1 = empty side (clip past it)
                Item {
                    x: index === 0 ? 0 : fill.width - 1.5
                    width: index === 0 ? fill.width - 1.5 : parent.width - (fill.width - 1.5)
                    height: parent.height
                    clip: true

                    Text {
                        // Positioned relative to the body, not to this clip window,
                        // so both copies sit in the same place.
                        x: (body.width - 3) / 2 - width / 2 - parent.x
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.percent
                        font { family: Theme.font; pixelSize: 10; weight: Font.DemiBold }
                        color: index === 0 ? Theme.bg0 : root.state
                    }
                }
            }
        }
    }

    // The nub on the positive terminal.
    Rectangle {
        id: cap
        anchors { left: body.right; verticalCenter: body.verticalCenter }
        width: 2.5
        height: 6
        radius: 1
        color: root.state
        opacity: 0.95
    }

    Text {
        id: glyph
        visible: root.charging || root.saver
        anchors { left: cap.right; leftMargin: 3; verticalCenter: parent.verticalCenter }
        text: root.charging ? "" : "+"
        font.family: Theme.font
        font.pixelSize: 11
        color: root.state
    }
}
