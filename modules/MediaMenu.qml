import QtQuick
import QtQuick.Layouts
import ".."
import "../services" as Svc

// Every player MPRIS knows about, one row each. The bar's centre widget shows
// only the player that wins; this is where the losers are — the paused
// Spotify behind the browser video, the second browser tab — and where the
// keyboard controls whichever one you point at.
//
// Enter toggles play/pause, h/l are previous/next. The same muscle memory as
// the audio menu: Enter acts, h/l adjust sideways.
Menu {
    id: root
    name: "media"
    cardWidth: 340

    allRows: {
        const out = [];
        for (const p of Svc.Media.players.filter(p => p.canControl))
            out.push({ kind: "player", player: p, section: "Players" });
        // A menu with zero rows has no cursor and nothing to say; one inert
        // row says why it's empty.
        if (out.length === 0)
            out.push({ kind: "empty", section: "Players" });
        return out;
    }

    rowText: row => row.kind === "player"
        ? `${row.player.identity} ${row.player.trackTitle ?? ""}`
        : ""

    activateRow: row => {
        if (row.kind === "player" && row.player.canTogglePlaying)
            row.player.togglePlaying();
    }

    // Sign is all that matters here — the 0.05 is a volume step that h/l
    // happen to carry.
    nudgeRow: (row, delta) => {
        if (row.kind !== "player") return;
        if (delta > 0 && row.player.canGoNext) row.player.next();
        else if (delta < 0 && row.player.canGoPrevious) row.player.previous();
    }

    delegate: PlayerRow {
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
