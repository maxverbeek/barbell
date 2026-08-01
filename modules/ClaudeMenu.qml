import QtQuick
import QtQuick.Layouts
import ".."
import "../services" as Svc

// Claude limits as the fifth tab. The bar widget only appears when something
// is wrong, and "am I fine?" deserves an answer without waiting to be in
// trouble — so the answer lives where every other question already goes:
// summon the menu, press c, read, Esc. Nothing here acts; it's the one menu
// that's a readout, and j/k still move the cursor because switching tabs
// shouldn't change how your hands work.
Menu {
    id: root
    name: "claude"
    cardWidth: 300

    // A peek should show now, not the last five-minute poll.
    onOpenChanged: if (open) Svc.ClaudeUsage.refresh()

    allRows: {
        const out = Svc.ClaudeUsage.windows.map(w =>
            ({ kind: "bucket", bucket: w, section: "Limits" }));
        if (out.length === 0)
            out.push({ kind: "empty", section: "Limits" });
        return out;
    }

    rowText: row => row.kind === "bucket"
        ? Svc.ClaudeUsage.bucketName(row.bucket.key) : ""

    delegate: ClaudeRow {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        row: modelData
        // Never highlighted: this menu is a readout, and with no activateRow or
        // nudgeRow to reach, a cursor would promise an action that isn't there.
        // j/k still move root.selected, it just doesn't draw.
        active: false

        heading: index === 0
            || root.rows[index - 1].section !== modelData.section
                ? modelData.section : ""
    }
}
