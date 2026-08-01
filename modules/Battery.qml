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

    // Colour of the charged portion. Thresholds are the tuning knob. These are
    // the palette's darker siblings of good/bad/warn — the light digits sit on
    // top of the fill, so the fill has to stay out of their luminance range.
    //
    // The normal fill is lifted above islandActive: the fill must be BRIGHTER
    // than the rest or the pill reads inverted — a brain sees bright as full,
    // and waveBlue2 against sumiInk4 had it exactly backwards.
    readonly property color level: charging ? Theme.autumnGreen
        : percent <= 10 ? Theme.autumnRed
        : percent <= 25 ? Theme.boatYellow2
        : Qt.lighter(Theme.islandActive, 1.45)

    // The remainder, kept well below the fill so the divide is a real step in
    // luminance rather than a hue hint — that step is the analog readout.
    readonly property color rest: Theme.sumiInk3

    // Low charge is the digits' problem too: the coloured fill is a sliver
    // hiding behind them exactly when it matters, so the number itself takes
    // the urgency colour.
    readonly property color digits: charging || percent > 25 ? Theme.fg
        : percent <= 10 ? Theme.bad
        : Theme.warn

    implicitWidth: charging ? bolt.x + bolt.width : body.width + 2.5
    implicitHeight: 14

    Rectangle {
        id: body
        width: 26
        height: 14
        anchors.verticalCenter: parent.verticalCenter
        radius: 5
        color: root.rest

        // How far the charged colour reaches. Never so thin it vanishes: a 1%
        // battery must still show a sliver.
        property real fillWidth: root.percent <= 0 ? 0
            : Math.max(width * Math.min(100, root.percent) / 100, 3)
        Behavior on fillWidth { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }

        // The charged part is a FULL-SIZE rounded rect — so its corners are
        // always the body's own arcs — revealed through a rectangular clip
        // window of fillWidth. The clip only ever makes the straight vertical
        // cut at the colour boundary; it never touches a corner's shape. Any
        // scheme where a child rect's own edge lands on a body corner fails,
        // because Qt clamps a radius to half the rect's smaller side.
        Item {
            width: body.fillWidth
            height: parent.height
            clip: true
            Rectangle {
                width: body.width
                height: body.height
                radius: body.radius
                color: root.level
            }
        }

        // One light Text is enough: both the fill and the remainder are dark,
        // so the boundary can run straight through the digits without eating
        // half of them.
        Text {
            anchors.centerIn: parent
            text: root.percent
            font { family: Theme.font; pixelSize: 9; weight: Font.Bold }
            color: root.digits
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
