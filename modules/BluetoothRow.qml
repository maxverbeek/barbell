import QtQuick
import QtQuick.Layouts
import ".."
import "../services" as Svc

// One line of the bluetooth menu: a device, or the radio toggle. A device
// shows what kind of thing it is, whether it's connected, and its battery if
// it reports one — which is the whole reason to open this rather than guess.
Item {
    id: root

    required property var row
    property bool active: false
    property string heading: ""

    signal hovered()
    signal clicked()

    readonly property var dev: row.dev ?? null
    readonly property bool connected: dev?.connected ?? false
    readonly property bool busy: dev ? Svc.Bluetooth.busy(dev) : false

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
        color: root.active ? Theme.islandActive : "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 8 }
            spacing: 8

            Text {
                text: root.row.kind === "toggle"
                        ? (Svc.Bluetooth.enabled ? "󰂯" : "󰂲")
                    : Svc.Bluetooth.glyph(root.dev)
                font { family: Theme.iconFont; pixelSize: 13 }
                color: root.row.kind === "toggle"
                        ? (Svc.Bluetooth.enabled ? Theme.accent : Theme.off)
                    : root.connected ? Theme.accent
                    : root.busy ? Theme.warn
                    : Theme.fgDim
                Layout.preferredWidth: 16

                // Mid-connect pulses rather than sitting still, so a pair
                // that's about to fail doesn't look like a dead click.
                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                }
                onVisibleChanged: if (!visible) opacity = 1
            }

            Text {
                text: root.row.kind === "toggle"
                        ? (Svc.Bluetooth.enabled ? "Bluetooth on" : "Bluetooth off")
                    : Svc.Bluetooth.label(root.dev)
                color: root.connected ? Theme.fg : Theme.fgDim
                font {
                    family: Theme.font
                    pixelSize: 12
                    weight: root.connected ? Font.DemiBold : Font.Normal
                }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Only earbuds and mice tend to report this, and it's the number
            // you actually came looking for when they do.
            Text {
                visible: root.dev?.batteryAvailable ?? false
                text: Math.round((root.dev?.battery ?? 0) * 100) + "%"
                color: (root.dev?.battery ?? 1) <= 0.2 ? Theme.bad : Theme.fgFaint
                font { family: Theme.font; pixelSize: 11 }
            }

            // Says what Enter will do, and doubles as the connected marker.
            Text {
                visible: root.row.kind === "device"
                text: root.busy ? "…" : root.connected ? "󰄬" : ""
                font { family: Theme.iconFont; pixelSize: 12 }
                color: root.connected ? Theme.good : Theme.warn
                Layout.preferredWidth: 12
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hovered()
            onClicked: root.clicked()
        }
    }
}
