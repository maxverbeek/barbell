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

    allRows: {
        const out = [];
        if (Svc.Network.vpnActive)
            out.push({ kind: "vpn", section: "VPN" });
        out.push({ kind: "toggle", section: "Wi-Fi" });
        if (Svc.Network.wifiEnabled)
            for (const n of Svc.Network.networks)
                out.push({ kind: "network", net: n, section: "Wi-Fi" });
        return out;
    }

    // The toggle and the VPN line always survive a filter; only networks are
    // searchable, which is the point of typing in the first place.
    rowText: row => row.kind === "network" ? row.net.name : ""

    anchorOf: section => {
        const first = rows.findIndex(r => r.section === section);
        if (first < 0) return -1;
        const active = rows.findIndex(r => r.section === section
            && r.kind === "network" && r.net.connected);
        return active >= 0 ? active : first;
    }

    activateRow: row => {
        if (row.kind === "toggle") { Svc.Network.toggleWifi(); return; }
        if (row.kind === "vpn") return;              // nothing to do yet
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
