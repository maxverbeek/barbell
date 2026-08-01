import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// Pick an output, pick an input, set the levels. The panel and the whole
// keyboard model come from Menu; this is only what's audio about it.
Menu {
    id: root
    name: "audio"

    // Levels first: adjusting volume is the common errand, picking a device
    // the occasional one, so the cursor opens on the thing you came for.
    allRows: {
        const out = [];
        out.push({ kind: "volume", which: "sink", section: "Levels" });
        out.push({ kind: "volume", which: "source", section: "Levels" });
        for (const n of Audio.sinks) out.push({ kind: "sink", node: n, section: "Output" });
        for (const n of Audio.sources) out.push({ kind: "source", node: n, section: "Input" });
        return out;
    }

    // Sliders aren't named things, so they never match a query — and never get
    // filtered out either. Losing your volume control because you typed a
    // device name would be daft.
    rowText: row => row.kind === "volume" ? "" : Audio.label(row.node)

    // ] from the sliders should land on the device in use, not on whatever
    // sorts first — since the list stopped reordering, those differ.
    anchorOf: section => {
        const first = rows.findIndex(r => r.section === section);
        if (first < 0) return -1;
        const active = rows.findIndex(r => r.section === section
            && r.kind !== "volume"
            && r.node === (r.kind === "source" ? Audio.source : Audio.sink));
        return active >= 0 ? active : first;
    }

    // Enter on a device row makes it the default; on a volume row it toggles
    // mute, the only sensible "activate" for a slider.
    activateRow: row => {
        if (row.kind === "sink") Audio.setSink(row.node);
        else if (row.kind === "source") Audio.setSource(row.node);
        else if (row.which === "sink") Audio.toggleSinkMute();
        else Audio.toggleMicMute();
        // Picking a device is the end of a search.
        if (row.kind !== "volume") root.clearSearch();
    }

    // h/l adjust whichever stream the current row belongs to, so you can land
    // on an output and change its level without walking down to the slider.
    nudgeRow: (row, delta) => {
        const isSource = row.kind === "source"
            || (row.kind === "volume" && row.which === "source");
        if (isSource) Audio.setMicVolume(Audio.micVolume + delta);
        else Audio.setSinkVolume(Audio.sinkVolume + delta);
    }

    // m mutes whatever row you're on without having to walk to its slider.
    // Not while searching, where it's just a letter in the query.
    handleKey: event => {
        if (root.searching || event.key !== Qt.Key_M) return false;
        const row = root.rows[root.selected];
        if (!row) return true;
        const isSource = row.kind === "source"
            || (row.kind === "volume" && row.which === "source");
        if (isSource) Audio.toggleMicMute();
        else Audio.toggleSinkMute();
        return true;
    }

    delegate: MenuRow {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        row: modelData
        active: index === root.selected
        // Pointing at something selects it, so the highlight never disagrees
        // with what Enter would act on.
        onHovered: root.selected = index
        onClicked: { root.selected = index; root.activate(); }
        onScrolled: d => { root.selected = index; root.nudge(d); }

        heading: index === 0
            || root.rows[index - 1].section !== modelData.section
                ? modelData.section : ""
    }
}
