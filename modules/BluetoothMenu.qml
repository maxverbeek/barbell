import QtQuick
import QtQuick.Layouts
import ".."
import "../services" as Svc

// Devices, and whether the radio is on. Discovery only runs while the menu is
// open — scanning is expensive and there's nobody watching otherwise.
Menu {
    id: root
    name: "bluetooth"
    cardWidth: 320

    onOpenChanged: Svc.Bluetooth.setDiscovering(open && Svc.Bluetooth.enabled)

    allRows: {
        const out = [{ kind: "toggle", section: "Bluetooth" }];
        if (Svc.Bluetooth.enabled)
            for (const d of Svc.Bluetooth.devices)
                out.push({
                    kind: "device",
                    dev: d,
                    // Devices you've paired are the ones you'll pick again;
                    // everything else is whatever the scan happened to find.
                    section: (d.paired || d.bonded) ? "Paired" : "Nearby"
                });
        return out;
    }

    rowText: row => row.kind === "device" ? Svc.Bluetooth.label(row.dev) : ""

    anchorOf: section => {
        const first = rows.findIndex(r => r.section === section);
        if (first < 0) return -1;
        const active = rows.findIndex(r => r.section === section
            && r.kind === "device" && r.dev.connected);
        return active >= 0 ? active : first;
    }

    // Enter connects or disconnects. Pairing happens implicitly on first
    // connect, which is what bluez does anyway — a separate "pair" step would
    // be a distinction without a difference here.
    activateRow: row => {
        if (row.kind === "toggle") {
            Svc.Bluetooth.setEnabled(!Svc.Bluetooth.enabled);
            return;
        }
        Svc.Bluetooth.toggle(row.dev);
        root.clearSearch();
    }

    // d disconnects without leaving the row, x forgets the device. Forgetting
    // is the one destructive action here, so it wants its own key rather than
    // sharing Enter.
    handleKey: event => {
        if (root.searching) return false;
        const row = root.rows[root.selected];
        if (!row || row.kind !== "device") return false;
        if (event.key === Qt.Key_D) { row.dev.disconnect(); return true; }
        if (event.key === Qt.Key_X) { row.dev.forget(); return true; }
        return false;
    }

    delegate: BluetoothRow {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        row: modelData
        active: index === root.selected

        onHovered: root.selected = index
        onClicked: { root.selected = index; root.activate(); }

        heading: index === 0
            || root.rows[index - 1].section !== modelData.section
                ? modelData.section : ""
    }
}
