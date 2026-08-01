pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Wifi comes from Quickshell's own NetworkManager backend. VPN does not:
// DeviceType is None | Wifi | Wired, with no VPN case and no way to reach a
// vpn/wireguard/tun connection through the model. That gap is the reason this
// bar exists at all — ags had the same blind spot — so VPN is read out of
// nmcli directly, re-queried whenever `nmcli monitor` says something moved.
Singleton {
    id: root

    // --- wifi ----------------------------------------------------------
    readonly property var wifiDevice: {
        const ds = Networking.devices?.values ?? [];
        for (const d of ds) if (d.type === DeviceType.Wifi) return d;
        return null;
    }

    // The connected network, if any. `networks` holds every network in range,
    // so this is the one flagged connected rather than a "current" property.
    readonly property var activeNetwork: {
        const ns = wifiDevice?.networks?.values ?? [];
        for (const n of ns) if (n.connected) return n;
        return null;
    }

    readonly property string ssid: activeNetwork?.name ?? ""
    readonly property bool wifiConnected: activeNetwork !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    // 0..1. Four glyph buckets is as much as the bar can express.
    readonly property real signal: activeNetwork?.signalStrength ?? 0

    readonly property bool wired: {
        const ds = Networking.devices?.values ?? [];
        for (const d of ds) if (d.type === DeviceType.Wired && d.connected) return true;
        return false;
    }

    // Everything in range, strongest first, with the connected one pinned to
    // the top. Networks with no name are hidden SSIDs you can't pick anyway.
    readonly property var networks: {
        const ns = (wifiDevice?.networks?.values ?? []).filter(n => n.name);
        return ns.slice().sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            // Saved networks above unknown ones at similar strength: they're
            // one keypress to join, the others want a password.
            if (a.known !== b.known) return a.known ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
    }

    // Scanning is only worth doing while something is looking at the list.
    function scan(on) {
        if (wifiDevice) wifiDevice.scannerEnabled = on;
    }

    function toggleWifi() { Networking.wifiEnabled = !Networking.wifiEnabled; }

    // Open networks and saved ones connect directly; anything else needs a
    // password, which the menu collects before calling connectWithPsk.
    function needsPassword(n) {
        return n && !n.known && n.security !== WifiSecurityType.Open;
    }

    // --- vpn -----------------------------------------------------------
    property bool vpnActive: false
    property string vpnName: ""

    // Both real VPN profiles and tun devices count: tailscale shows up as a
    // plain `tun`, not `vpn`, and it's the one that's up most of the time.
    Process {
        id: vpnQuery
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                for (const line of text.trim().split("\n")) {
                    const sep = line.lastIndexOf(":");
                    if (sep < 0) continue;
                    const type = line.slice(sep + 1);
                    if (type === "vpn" || type === "wireguard" || type === "tun") {
                        name = line.slice(0, sep);
                        break;
                    }
                }
                root.vpnActive = name !== "";
                root.vpnName = name;
            }
        }
    }

    // nmcli monitor is silent at rest and prints a line per change, so this is
    // an event stream rather than a poll — the re-query only runs on movement.
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: vpnQuery.running = true }
        // NetworkManager restarts take the monitor down with them.
        onExited: reconnect.start()
    }

    Timer {
        id: reconnect
        interval: 2000
        onTriggered: monitor.running = true
    }

    Component.onCompleted: vpnQuery.running = true
}
