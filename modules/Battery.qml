import QtQuick
import ".."

// Android 16's battery pill: a solid rounded body where the charge level is a
// coloured fill and the remainder is a light neutral, with the percentage sitting
// on top. No border stroke — what looks like an outline at low charge is just the
// unfilled part showing.
//
// No SVG assets: it's two rectangles, a nub and a text node, so it themes with
// the palette and works at any percentage.
Item {
    id: root

    property int percent: 76
    property bool charging: false

    // Colour of the charged portion. Thresholds are the tuning knob.
    readonly property color level: charging ? Theme.good
        : percent <= 10 ? Theme.bad
        : percent <= 25 ? Theme.warn
        : Theme.fg

    // The remainder. Light enough to read as "the rest of the battery" rather
    // than a hole in it.
    readonly property color rest: Theme.sumiInk4

    implicitWidth: charging ? bolt.x + bolt.width : body.width + 2.5
    implicitHeight: 14

    Rectangle {
        id: body
        width: 26
        height: 14
        anchors.verticalCenter: parent.verticalCenter
        radius: 5
        color: root.rest
        clip: true

        // The charged part is the whole body in the level colour, with the
        // UNCHARGED part masked over it from the right. Drawing it the other way
        // round — a fill that grows from the left — means the fill owns the left
        // corners, and Qt clamps a radius to half the smaller side, so a narrow
        // fill gets a tighter arc than the body and reads as a square block
        // sitting inside a rounded end. Masking leaves the left corners as the
        // body's own at every percentage.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.level
        }

        Rectangle {
            id: uncharged
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: parent.width * (100 - Math.max(0, Math.min(100, root.percent))) / 100
            // Square on the left — the charged/uncharged boundary. The body's
            // clip trims the right end to the rounded outline.
            radius: 0
            color: root.rest
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
        }

        // Kept as an alias so the text clipping below reads naturally.
        readonly property real fillWidth: width - uncharged.width

        // Drawn twice, each copy clipped to one side of the boundary: dark over
        // the charged part, light over the rest. A single Text can't do it —
        // around 50% the boundary runs through the digits and half of them
        // disappear whichever colour you pick.
        Repeater {
            model: 2
            delegate: Item {
                required property int index
                anchors.fill: parent

                Item {
                    x: index === 0 ? 0 : body.fillWidth
                    width: index === 0 ? body.fillWidth : parent.width - body.fillWidth
                    height: parent.height
                    clip: true

                    Text {
                        // Laid out against the body rather than this clip window,
                        // so both copies land in exactly the same place.
                        x: body.width / 2 - width / 2 - parent.x
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.percent
                        font { family: Theme.font; pixelSize: 9; weight: Font.Bold }
                        color: index === 0 ? Theme.bg0 : Theme.fg
                    }
                }
            }
        }
    }

    // The positive terminal. Hidden while charging — the bolt takes over that
    // end of the cell entirely.
    Rectangle {
        id: nub
        visible: !root.charging
        anchors { left: body.right; leftMargin: 0.5; verticalCenter: body.verticalCenter }
        width: 2
        height: 5
        radius: 1
        color: root.rest
    }

    // Charging bolt, straddling the body's right edge. It's knocked out of the
    // cell rather than placed beside it: a background-coloured copy sits behind
    // the glyph and is drawn slightly larger, cutting a clean gap into the fill
    // so the bolt reads as a hole in the battery.
    Item {
        id: bolt
        visible: root.charging
        anchors { verticalCenter: parent.verticalCenter }
        x: body.width - width * 0.52
        width: 13
        height: 13
        z: 1

        // The knockout is drawn as a stroke, not a scaled copy: the bolt is far
        // taller than it is wide, so scaling about the centre opens a wide gap
        // at the sides and almost none where it crosses the top and bottom
        // edges. Offset copies give the same gap in every direction.
        Repeater {
            model: [[-1.5, 0], [1.5, 0], [0, -1.5], [0, 1.5],
                    [-1.1, -1.1], [1.1, -1.1], [-1.1, 1.1], [1.1, 1.1]]
            delegate: Text {
                required property var modelData
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: modelData[0]
                anchors.verticalCenterOffset: modelData[1]
                text: "󱐋"
                font { family: Theme.iconFont; pixelSize: 15 }
                color: Theme.bg0
            }
        }

        Text {
            anchors.centerIn: parent
            text: "󱐋"
            font { family: Theme.iconFont; pixelSize: 15 }
            color: root.level
        }
    }
}
