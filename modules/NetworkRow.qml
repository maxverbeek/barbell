import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import ".."
import "../services" as Svc

// One line of the network menu: a network, the wifi toggle, or the VPN
// readout. A network row turns into a password field when it's the one being
// joined, which keeps the prompt where you're already looking.
Item {
    id: root

    required property var row
    property bool active: false
    property string heading: ""
    property bool asking: false
    property string password: ""

    signal hovered()
    signal clicked()

    readonly property var net: row.net ?? null
    readonly property bool connected: net?.connected ?? false
    readonly property bool connecting: net?.state === ConnectionState.Connecting

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
                text: root.row.kind === "vpn"
                        ? (root.row.tunnel.active ? "󰦝" : "󰦜")
                    : root.row.kind === "more" ? "󰇘"
                    : root.row.kind === "toggle"
                        ? (Svc.Network.wifiEnabled ? "󰖩" : "󰖪")
                    : root.connected ? "󰄬"
                    : root.connecting ? "󰔟"
                    : root.net && root.net.signalStrength >= 0.75 ? "󰤨"
                    : root.net && root.net.signalStrength >= 0.5 ? "󰤥"
                    : root.net && root.net.signalStrength >= 0.25 ? "󰤢"
                    : "󰤟"
                font { family: Theme.iconFont; pixelSize: 13 }
                color: root.row.kind === "vpn"
                        ? (root.row.tunnel.active ? Theme.good : Theme.fgFaint)
                    : root.connected ? Theme.good
                    : root.connecting ? Theme.warn
                    : root.row.kind === "toggle" && !Svc.Network.wifiEnabled ? Theme.off
                    : Theme.fgDim
                Layout.preferredWidth: 16
            }

            Text {
                visible: !root.asking
                text: root.row.kind === "vpn" ? Svc.Network.tunnelLabel(root.row.tunnel)
                    : root.row.kind === "more" ? `${root.row.count} more exits`
                    : root.row.kind === "toggle"
                        ? (Svc.Network.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off")
                    : root.net.name
                color: root.row.kind === "more" ? Theme.fgFaint
                    : root.row.kind === "vpn"
                        ? (root.row.tunnel.active ? Theme.fg : Theme.fgDim)
                    : root.connected ? Theme.fg : Theme.fgDim
                font {
                    family: Theme.font
                    pixelSize: 12
                    weight: root.connected
                        || (root.row.kind === "vpn" && root.row.tunnel.active)
                            ? Font.DemiBold : Font.Normal
                }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Which country an exit is in, when it isn't obvious from the name.
            Text {
                visible: root.row.kind === "vpn" && !root.row.tunnel.active
                text: Svc.Network.tunnelGroup(root.row.tunnel)
                color: Theme.fgFaint
                font { family: Theme.font; pixelSize: 10; letterSpacing: 0.4 }
            }

            // The password field takes over the row it belongs to, so there's
            // no separate dialog to lose track of. Dots rather than glyphs —
            // a menu on a bar is a shoulder-surfable place.
            RowLayout {
                visible: root.asking
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󰌾"
                    font { family: Theme.iconFont; pixelSize: 11 }
                    color: Theme.warn
                }

                Text {
                    text: "•".repeat(root.password.length)
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: 12 }
                    Layout.fillWidth: true
                }

                // A blank field with no hint reads as a frozen menu.
                Text {
                    visible: root.password.length === 0
                    text: "password"
                    color: Theme.fgFaint
                    font { family: Theme.font; pixelSize: 11 }
                }
            }

            // A saved network is one keypress; an unknown secured one will ask.
            Text {
                visible: !root.asking && root.row.kind === "network"
                    && !root.connected && Svc.Network.needsPassword(root.net)
                text: "󰌾"
                font { family: Theme.iconFont; pixelSize: 11 }
                color: Theme.fgFaint
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
