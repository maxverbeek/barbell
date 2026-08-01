import QtQuick
import ".."
import "../services" as Svc

// Bluetooth, following the interest rules. Powered-on-with-nothing-connected
// is the boring case and the one that's true most of the time, so it stays
// quiet: no glyph at all. The radio being on isn't news; something being
// attached to it is.
//
// One shape throughout — a plain bluetooth glyph, per the design session's
// rejection of the combined bluetooth-plus-headset mark. Which device it is
// belongs in the menu, and the speaker icon already turns accent-coloured
// when audio is actually routed over it.
Item {
    id: root

    readonly property bool busy: Svc.Bluetooth.devices.some(d => Svc.Bluetooth.busy(d))
    // Explicitly off is worth one dim glyph — otherwise "why won't my
    // headphones pair" has no answer on the bar.
    readonly property bool disabled: Svc.Bluetooth.adapter && !Svc.Bluetooth.enabled

    visible: Svc.Bluetooth.anyConnected || busy || disabled
    implicitWidth: visible ? icon.implicitWidth : 0
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        text: "󰂯"
        font { family: Theme.iconFont; pixelSize: 15 }
        color: root.disabled ? Theme.off
            : root.busy ? Theme.warn
            : Theme.accent
        anchors.centerIn: parent

        // Mid-connect is transient; a pulse says "working on it" without
        // needing a spinner.
        SequentialAnimation on opacity {
            running: root.busy
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
        }
        onVisibleChanged: if (!visible) opacity = 1
    }
}
