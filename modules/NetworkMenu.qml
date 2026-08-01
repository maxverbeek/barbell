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
    // rest to pick from. All of them show — there are only a handful and
    // picking an exit is the reason the menu gets opened.
    //
    // Access points are the long list instead: everything in range is dozens
    // of neighbours' routers, so only the top few (connected and saved sort
    // first) show until you search or expand.
    property bool showAllNetworks: false
    readonly property int networkLimit: 5

    allRows: {
        const out = [];
        const ts = Svc.Network.tunnels;
        for (const t of ts.filter(t => t.active).concat(ts.filter(t => !t.active)))
            out.push({ kind: "vpn", tunnel: t, section: "VPN" });

        out.push({ kind: "toggle", section: "Wi-Fi" });
        if (Svc.Network.wifiEnabled) {
            const ns = Svc.Network.networks;
            const all = showAllNetworks || query !== "";
            for (const n of (all ? ns : ns.slice(0, networkLimit)))
                out.push({ kind: "network", net: n, section: "Wi-Fi" });
            // A way in to the rest of what's in range.
            if (!all && ns.length > networkLimit)
                out.push({ kind: "more", count: ns.length - networkLimit, section: "Wi-Fi" });
        }
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
        if (row.kind === "more") { root.showAllNetworks = true; return; }
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
