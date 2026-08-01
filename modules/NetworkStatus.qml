import QtQuick
import ".."
import "../services"

// Network, following the interest rules:
//   vpn   — drawn only when a tunnel is up. It's an exception, and it's the
//           one thing ags could never tell me.
//   wifi  — always drawn: a dead connection has to be visible without hunting
//           for it.
//   ssid  — only when it isn't the network I'm always on. Home wifi is noise.
Row {
    id: root
    spacing: 5

    signal openMenu()

    // Networks I'm on so routinely that naming them says nothing. Anything
    // else is worth the bar space — that's the whole point of showing it.
    readonly property var familiar: ["Ziggo8410435"]

    Text {
        visible: Network.vpnActive
        text: "󰦝"
        font { family: Theme.iconFont; pixelSize: 15 }
        color: Theme.good
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: !Network.wifiEnabled ? "󰤮"
            : Network.wired ? "󰈁"
            : !Network.wifiConnected ? "󰤯"
            : Network.signal >= 0.75 ? "󰤨"
            : Network.signal >= 0.5 ? "󰤥"
            : Network.signal >= 0.25 ? "󰤢"
            : "󰤟"
        font { family: Theme.iconFont; pixelSize: 15 }
        // Off is a choice; disconnected-but-on is a problem.
        color: !Network.wifiEnabled ? Theme.off
            : (Network.wifiConnected || Network.wired) ? Theme.fg
            : Theme.warn
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        // 18 chars keeps "Researchable: work…" — the colon is what tells it
        // apart from the office network of the same name.
        readonly property string full: Network.ssid
        visible: text !== ""
        text: full === "" || root.familiar.includes(full) ? ""
            : full.length > 18 ? full.slice(0, 18) + "…"
            : full
        color: Theme.fgDim
        font { family: Theme.font; pixelSize: 13 }
        anchors.verticalCenter: parent.verticalCenter
    }
}
