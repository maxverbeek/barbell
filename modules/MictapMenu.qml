import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// mictap as a tab: the recording in progress (Enter stops and saves it), or
// the inputs to start one from, then today's recordings and how far their
// transcription is. The list is fetched when the tab opens, not polled.
Menu {
    id: root
    name: "mictap"

    onOpenChanged: if (open) Mictap.refresh()

    allRows: {
        const out = [];
        if (Mictap.recording)
            out.push({ kind: "stop", section: "Recording" });
        else
            for (const n of Audio.sources) out.push({ kind: "start", node: n, section: "Record from" });
        if (Mictap.listState !== "ok")
            out.push({ kind: Mictap.listState, section: "Today" });
        else if (Mictap.today.length === 0)
            out.push({ kind: "none", section: "Today" });
        for (const r of Mictap.today) out.push({ kind: "rec", rec: r, section: "Today" });
        return out;
    }

    rowText: row => row.kind === "start" ? Audio.label(row.node) : ""
    rowLabel: row => row.kind === "rec" ? `${row.rec.date ?? row.rec.id} ${row.rec.status}` : rowText(row) || row.kind

    activateRow: row => {
        if (row.kind === "stop") Mictap.stop();
        else if (row.kind === "start") Mictap.start(row.node.name);
        else return;
        Menus.close();
    }

    delegate: MictapRow {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        row: modelData
        // Today's recordings are a readout: no cursor where Enter does nothing.
        active: index === root.selected && (modelData.kind === "stop" || modelData.kind === "start")
        onHovered: root.selected = index
        onClicked: { root.selected = index; root.activate(); }

        heading: index === 0
            || root.rows[index - 1].section !== modelData.section
                ? modelData.section : ""
    }
}
