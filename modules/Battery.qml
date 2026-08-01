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

    // Thresholds are the tuning knob; colour reinforces the fill, never replaces it.
    readonly property color state: charging ? Theme.green
        : percent <= 10 ? Theme.red
        : percent <= 25 ? Theme.yellow
        : Theme.fg

    implicitWidth: body.width + cap.width + (charging ? glyph.width + 2 : 0)
    implicitHeight: 15

    // Drawn as a solid pill with the EMPTY part masked out in the background
    // colour, rather than a fill that grows from the left. The filled region then
    // has no shape of its own — it's just the body showing through — so it
    // inherits the body's rounded corners for free at every percentage. Growing
    // a fill instead means hand-managing its corners, which leaves a curved
    // sliver near 100% and a stub indistinguishable from the border near 0%.
    Rectangle {
        id: body
        width: 26
        height: 13
        anchors.verticalCenter: parent.verticalCenter
        radius: 4
        color: root.state
        opacity: 0.95
        clip: true

        readonly property real bw: 1.25
        // The level is read against the INTERIOR — the span between the borders,
        // not the outer width. Measuring against the outer width makes the mask
        // start behind the border, so every percentage reads a little low and
        // 100% still shows a sliver of empty.
        readonly property real inner: width - bw * 2
        // Where the filled region ends — the text halves clip against this.
        readonly property real filled: bw + inner * Math.min(100, root.percent) / 100

        // Masks the empty part. Runs to the outer edge on the right so the
        // body's clip trims it to the rounded outline with no corner maths;
        // only its left edge — the boundary you actually see — is positioned.
        Rectangle {
            id: empty
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: Math.max(0, parent.width - parent.filled)
            radius: 0
            color: Theme.bg0
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
        }

        // The outline, drawn as a sibling ON TOP of the mask. A Rectangle's own
        // `border` paints underneath its children, so the mask would eat its
        // inner edge and the empty side would look thin or broken.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1.25
            border.color: root.state
            z: 1
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
                z: 2   // above the outline

                // 0 = filled side (clip to the fill), 1 = empty side (clip past it)
                Item {
                    x: index === 0 ? 0 : body.filled
                    width: index === 0 ? body.filled : parent.width - body.filled
                    height: parent.height
                    clip: true

                    Text {
                        // Positioned against the body, not this clip window, so
                        // both copies land in exactly the same place.
                        x: body.width / 2 - width / 2 - parent.x
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.percent
                        font { family: Theme.font; pixelSize: 9; weight: Font.DemiBold }
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
        width: 2
        height: 5
        radius: 1
        color: root.state
        opacity: 0.95
    }

    // Charging bolt, sitting past the terminal.
    Text {
        id: glyph
        visible: root.charging
        anchors { left: cap.right; leftMargin: 2; verticalCenter: parent.verticalCenter }
        text: "󱐋"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: root.state
    }
}
