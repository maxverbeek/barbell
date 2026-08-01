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
    //
    // Quickshell's DeviceType is None | Wifi | Wired, with no VPN case and no
    // way to reach a vpn/wireguard/tun connection through the model — the gap
    // that ags had too, and the reason this bar exists. So VPN goes through
    // nmcli, re-queried whenever `nmcli monitor` reports movement.

    // Every VPN-ish profile, active or not: { name, type, active }.
    property var tunnels: []

    readonly property var activeTunnels: tunnels.filter(t => t.active)
    readonly property bool vpnActive: activeTunnels.length > 0
    // The bar shows one name. Prefer a real tunnel over tailscale, which is up
    // almost always and so says the least about what's going on.
    readonly property string vpnName: {
        const t = activeTunnels.find(t => t.type !== "tun") ?? activeTunnels[0];
        return t ? tunnelLabel(t) : "";
    }

    // Tailscale is a tun device NetworkManager can see but can't bring up, so
    // it's toggled through its own CLI. Anything else is an nmcli profile.
    function isTailscale(t) { return t.type === "tun" && t.name.startsWith("tailscale"); }

    // Mullvad-style profile names — es-bcn-wg-002, nl-ams-wg-008 — are a
    // country, a city and a server number. Unreadable in a list, and the
    // number rarely matters, so show "Barcelona 002" instead.
    readonly property var cities: ({
        ams: "Amsterdam", atl: "Atlanta", bcn: "Barcelona", got: "Gothenburg",
        mad: "Madrid", mil: "Milan"
    })

    function tunnelLabel(t) {
        if (!t) return "";
        if (isTailscale(t)) return "Tailscale";
        const m = t.name.match(/^([a-z]{2})-([a-z]{3})-wg-(\d+)$/);
        if (m) {
            const city = cities[m[2]] ?? m[2].toUpperCase();
            return `${city} ${m[3]}`;
        }
        // nl982.nordvpn.com.udp → NordVPN nl982
        const nord = t.name.match(/^([a-z]{2}\d+)\.nordvpn\.com/);
        if (nord) return `NordVPN ${nord[1]}`;
        return t.name;
    }

    // Country, for grouping the list.
    function tunnelGroup(t) {
        if (!t) return "";
        if (isTailscale(t)) return "Mesh";
        if (/nordvpn/.test(t.name)) return "NordVPN";
        const m = t.name.match(/^([a-z]{2})-/);
        return m ? m[1].toUpperCase() : "VPN";
    }

    function toggleTunnel(t) {
        if (!t) return;
        if (isTailscale(t)) {
            Quickshell.execDetached(["tailscale", t.active ? "down" : "up"]);
        } else {
            Quickshell.execDetached(["nmcli", "connection", t.active ? "down" : "up", t.name]);
        }
        // nmcli monitor will tell us when it lands; nothing optimistic here.
    }

    // Two queries because `connection show` alone can't tell you which of the
    // listed profiles is up — the --active form is a different list.
    Process {
        id: vpnQuery
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.trim().split("\n")) {
                    const sep = line.lastIndexOf(":");
                    if (sep < 0) continue;
                    const type = line.slice(sep + 1);
                    if (type === "vpn" || type === "wireguard" || type === "tun")
                        found.push({ name: line.slice(0, sep), type: type, active: false });
                }
                root._known = found;
                activeQuery.running = true;
            }
        }
    }

    property var _known: []

    Process {
        id: activeQuery
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                const up = new Set(text.trim().split("\n"));
                root.tunnels = root._known.map(t =>
                    ({ name: t.name, type: t.type, active: up.has(t.name) }));
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
