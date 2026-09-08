import QtQuick
import QtQuick.Layouts
import ".."
import "../services" as Svc

// Claude limits as the fifth tab, plus every running agent session. The bar
// widget only appears when something is wrong, and "am I fine?" deserves an
// answer without waiting to be in trouble — so the answer lives where every
// other question already goes: summon the menu, press c, read, Esc. The
// sessions are the part that acts: Enter focuses that agent, in herdr and in
// niri, and / filters them by title or by project.
Menu {
    id: root
    name: "claude"
    cardWidth: 340

    // A peek should show now, not the last five-minute poll.
    onOpenChanged: if (open) Svc.ClaudeUsage.refresh()

    // A Claude Code session in a bare terminal stamps its title with a spinner
    // glyph — braille or circles while working, ✳ and friends while idle. That
    // prefix is how the window is told apart from every other terminal, and
    // it's stripped here so the row shows a name rather than a stuttering
    // character; the icon carries working-vs-waiting instead. Sessions inside
    // herdr never reach this path: herdr's window has no spinner in its title.
    function session(w) {
        const m = /^([⠀-⣿◐-◓✳✶✻✽·✢]) (.*)/.exec(w.title ?? "");
        return m && { kind: "session", win: w, section: "Windows",
                      title: m[2], busy: Svc.Icons.thinkingPattern.test(m[1]) };
    }

    // herdr's sessions first, one section per herdr workspace named for its
    // project — that's the level you think at — then bare windows, then limits.
    allRows: {
        const out = [];
        for (const g of Svc.Herdr.groups)
            for (const a of g.agents)
                out.push({ kind: "session", agent: a, section: g.ws.label || g.ws.workspace_id,
                           title: a.terminal_title_stripped || a.agent });
        const windows = Object.values(Svc.Niri.windows)
            .map(session).filter(Boolean)
            .sort((a, b) => (b.win.focus_timestamp?.secs ?? 0) - (a.win.focus_timestamp?.secs ?? 0));
        out.push(...windows);
        for (const w of Svc.ClaudeUsage.windows)
            out.push({ kind: "bucket", bucket: w, section: "Limits" });
        if (out.length === 0)
            out.push({ kind: "empty", section: "Limits" });
        return out;
    }

    // The section rides along so /argo finds the agent by project when its
    // conversation title says something else.
    rowText: row => row.kind === "bucket" ? Svc.ClaudeUsage.bucketName(row.bucket.key)
        : row.kind === "session" ? `${row.title} ${row.section}`
        : ""
    rowLabel: row => row.kind === "session" ? row.title : rowText(row) || row.kind

    // Focusing is a departure, so the menu closes behind you — same as the
    // media menu's f.
    activateRow: row => {
        if (row.kind !== "session") return;
        if (row.agent)
            Svc.Herdr.focus(row.agent);
        else
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
        active: index === root.selected && modelData.kind === "session"
        onHovered: root.selected = index
        onClicked: { root.selected = index; root.activate(); }

        heading: index === 0
            || root.rows[index - 1].section !== modelData.section
                ? modelData.section : ""
    }
}
