import QtQuick
import QtQuick.Layouts
import ".."
import "../services" as Svc

// Claude limits as the fifth tab, plus every running Claude Code session.
// The bar widget only appears when something is wrong, and "am I fine?"
// deserves an answer without waiting to be in trouble — so the answer lives
// where every other question already goes: summon the menu, press c, read,
// Esc. The sessions are the part that acts: Enter focuses that window in
// niri, and / filters them by title.
Menu {
    id: root
    name: "claude"
    cardWidth: 340

    // A peek should show now, not the last five-minute poll.
    onOpenChanged: if (open) Svc.ClaudeUsage.refresh()

    // Claude Code stamps its terminal title with a spinner glyph — braille
    // while working, ✳ and friends while idle. That prefix is how a session's
    // window is told apart from every other terminal, and it's stripped here so
    // the row shows a name rather than a stuttering character; the icon carries
    // working-vs-waiting instead. If another widget ever wants the session list,
    // this function moves to a service as-is.
    function session(w) {
        const m = /^([⠀-⣿✳✶✻✽·✢]) (.*)/.exec(w.title ?? "");
        return m && { kind: "window", win: w, section: "Sessions",
                      title: m[2], busy: m[1] >= "⠀" && m[1] <= "⣿" };
    }

    allRows: {
        const out = Object.values(Svc.Niri.windows)
            .map(session).filter(Boolean)
            .sort((a, b) => (b.win.focus_timestamp?.secs ?? 0) - (a.win.focus_timestamp?.secs ?? 0));
        for (const w of Svc.ClaudeUsage.windows)
            out.push({ kind: "bucket", bucket: w, section: "Limits" });
        if (out.length === 0)
            out.push({ kind: "empty", section: "Limits" });
        return out;
    }

    rowText: row => row.kind === "bucket" ? Svc.ClaudeUsage.bucketName(row.bucket.key)
        : row.kind === "window" ? row.title
        : ""

    // Focusing is a departure, so the menu closes behind you — same as the
    // media menu's f.
    activateRow: row => {
        if (row.kind !== "window") return;
        Svc.Niri.focusWindow(row.win.id);
        Svc.Menus.close();
    }

    delegate: ClaudeRow {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        row: modelData
        // The cursor only draws on session rows — the buckets are a readout,
        // and a highlight there would promise an action that isn't there.
        active: index === root.selected && modelData.kind === "window"
        onHovered: root.selected = index
        onClicked: { root.selected = index; root.activate(); }

        heading: index === 0
            || root.rows[index - 1].section !== modelData.section
                ? modelData.section : ""
    }
}
