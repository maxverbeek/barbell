import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import ".."
import "../services" as Svc

// Wifi networks and whatever tunnel is up. Scanning only runs while the menu
// is open — a background scan costs power and there's nobody to show it to.
Menu {
    id: root
    name: "network"
    cardWidth: 320

    // Asking for a password turns the row into a field. Kept here rather than
    // in the row so Esc and Enter can be handled with the rest of the keys.
    property var pending: null
    property string password: ""

    onOpenChanged: {
        Svc.Network.scan(open);
        if (!open) cancelPassword();
    }

    function cancelPassword() { pending = null; password = ""; }

    // Active tunnels first so turning one off is always at the top, then the
    // rest to pick from. Eight WireGuard exits is too many to scroll past on
    // the way to wifi, so only the active ones show until you search or the
    // section is expanded.
    property bool showAllTunnels: false

    allRows: {
        const out = [];
        const ts = Svc.Network.tunnels;
        const active = ts.filter(t => t.active);
        const rest = ts.filter(t => !t.active);
        const shown = (showAllTunnels || query !== "") ? active.concat(rest) : active;
        for (const t of shown)
            out.push({ kind: "vpn", tunnel: t, section: "VPN" });
        // A way in when nothing is connected and nothing is expanded.
        if (!showAllTunnels && query === "" && rest.length > 0)
            out.push({ kind: "more", count: rest.length, section: "VPN" });

        out.push({ kind: "toggle", section: "Wi-Fi" });
        if (Svc.Network.wifiEnabled)
            for (const n of Svc.Network.networks)
                out.push({ kind: "network", net: n, section: "Wi-Fi" });
        return out;
    }

    // Networks and tunnels are both searchable — typing "ams" should find
    // Amsterdam whether it's a wifi name or an exit node. The toggles aren't.
    rowText: row => row.kind === "network" ? row.net.name
        : row.kind === "vpn" ? Svc.Network.tunnelLabel(row.tunnel)
        : ""

    anchorOf: section => {
        const first = rows.findIndex(r => r.section === section);
        if (first < 0) return -1;
        const active = rows.findIndex(r => r.section === section
            && r.kind === "network" && r.net.connected);
        return active >= 0 ? active : first;
    }

    activateRow: row => {
        if (row.kind === "toggle") { Svc.Network.toggleWifi(); return; }
        if (row.kind === "more") { root.showAllTunnels = true; return; }
        if (row.kind === "vpn") { Svc.Network.toggleTunnel(row.tunnel); return; }
        const n = row.net;
        if (n.connected) { n.disconnect(); return; }
        if (Svc.Network.needsPassword(n)) { root.pending = n; root.password = ""; return; }
        n.connect();
        root.clearSearch();
    }

    // While a password is being typed the keys belong to the field.
    handleKey: event => {
        if (!root.pending) return false;
        if (event.key === Qt.Key_Escape) { root.cancelPassword(); return true; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.pending.connectWithPsk(root.password);
            root.cancelPassword();
            root.clearSearch();
            return true;
        }
        if (event.key === Qt.Key_Backspace) {
            root.password = root.password.slice(0, -1);
            return true;
        }
        if (event.text && event.text >= " ") { root.password += event.text; return true; }
        return true;      // swallow everything else so nothing navigates away
    }

    delegate: NetworkRow {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        row: modelData
        active: index === root.selected
        asking: root.pending !== null && modelData.kind === "network"
            && modelData.net === root.pending
        password: root.password

        onHovered: if (!root.pending) root.selected = index
        onClicked: { root.selected = index; root.activate(); }

        heading: index === 0
            || root.rows[index - 1].section !== modelData.section
                ? modelData.section : ""
    }
}
