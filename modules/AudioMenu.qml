import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

// The audio menu: pick an output, pick an input, set the levels.
//
// Built keyboard-first. It takes exclusive keyboard focus when it opens, so
// j/k or the arrows move, Enter selects, Esc dismisses, and h/l nudge the
// volume of whatever row you're on — the whole thing is operable without the
// pointer ever entering it. The mouse is the second path, not the first:
// hover moves the selection to whatever you're pointing at, so the two never
// disagree about what's active.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property bool open: Menus.isOpen("audio")

    // Rows are built as one flat list so the keyboard has a single index to
    // walk. Section headers aren't rows: you can't select them, so they're
    // rendered by the delegate when the device above belongs to a new group.
    // Levels first: adjusting volume is the common errand, picking a device
    // the occasional one, so the cursor opens on the thing you came for.
    readonly property var allRows: {
        const out = [];
        out.push({ kind: "volume", which: "sink", section: "Levels" });
        out.push({ kind: "volume", which: "source", section: "Levels" });
        for (const n of Audio.sinks) out.push({ kind: "sink", node: n, section: "Output" });
        for (const n of Audio.sources) out.push({ kind: "source", node: n, section: "Input" });
        return out;
    }

    // `/` opens a filter. Everything downstream — move, jumpSection, the
    // delegate, activate — works off `rows`, so filtering is the only thing
    // search has to do; none of the index arithmetic needs to know about it.
    property bool searching: false
    property string query: ""

    readonly property var rows: {
        if (query === "") return allRows;
        const q = query.toLowerCase();
        // Sliders always match: they're not named things, and losing your
        // volume control because you typed a device name would be daft.
        return allRows.filter(r => r.kind === "volume"
            || Audio.label(r.node).toLowerCase().includes(q));
    }

    property int selected: 0

    // Typing a filter should put the cursor on what you were looking for —
    // the first device that matched, not the slider that always survives the
    // filter. With no query it also has to stay in bounds when devices come
    // and go (a headset connecting rewrites the list under you).
    onRowsChanged: {
        if (query !== "") {
            const first = rows.findIndex(r => r.kind !== "volume");
            selected = first >= 0 ? first : 0;
        } else if (selected >= rows.length) {
            selected = Math.max(0, rows.length - 1);
        }
    }

    // Layer-shell surfaces don't get keyboard input unless they ask. Exclusive
    // means the menu owns the keyboard while it's up, which is what makes Esc
    // and j/k work without the compositor handing keys to the window below.
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive
                                      : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    visible: open
    // Covers the screen so a click anywhere outside the card dismisses it.
    // The card itself is positioned inside this surface rather than the
    // surface being sized to the card.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    function hide() { Menus.close(); }

    // Reset to the top each time it opens, and take the keyboard. Focus has to
    // be claimed after the surface is actually up, hence keying off the change
    // rather than doing it in the open() call.
    onOpenChanged: {
        if (open) {
            selected = 0;               // the output level, the usual errand
            keys.forceActiveFocus();
        }
    }

    function move(delta) {
        if (rows.length === 0) return;
        selected = (selected + delta + rows.length) % rows.length;
    }

    // Where a section's cursor should land: the device in use, so ] from the
    // sliders puts you on the current output and one j moves off it. Without
    // this you'd land on whatever happened to sort first, which since the list
    // stopped reordering is rarely the one you care about.
    function anchorOf(section) {
        const first = rows.findIndex(r => r.section === section);
        if (first < 0) return -1;
        const active = rows.findIndex(r => r.section === section
            && r.kind !== "volume"
            && r.node === (r.kind === "source" ? Audio.source : Audio.sink));
        return active >= 0 ? active : first;
    }

    // [ and ] move between sections, landing on the active device in each.
    // Backward goes to the current section's anchor first when you're below
    // it, so a repeated [ walks up rather than sticking — the way [[ behaves
    // in vim. Neither wraps.
    function jumpSection(dir) {
        if (rows.length === 0) return;
        const here = rows[selected].section;
        if (dir > 0) {
            for (let i = selected + 1; i < rows.length; i++)
                if (rows[i].section !== here) { selected = anchorOf(rows[i].section); return; }
            selected = rows.length - 1;     // already in the last section
        } else {
            const anchor = anchorOf(here);
            if (selected > anchor) { selected = anchor; return; }
            // At or above this section's anchor: go to the previous section.
            let start = selected;
            while (start > 0 && rows[start - 1].section === here) start--;
            if (start === 0) return;
            selected = anchorOf(rows[start - 1].section);
        }
    }

    // Enter on a device row makes it the default; on a volume row it toggles
    // mute, which is the only sensible "activate" for a slider.
    function activate() {
        const row = rows[selected];
        if (!row) return;
        if (row.kind === "sink") Audio.setSink(row.node);
        else if (row.kind === "source") Audio.setSource(row.node);
        else if (row.which === "sink") Audio.toggleSinkMute();
        else Audio.toggleMicMute();
        // Picking a device is the end of a search — drop the filter so the
        // menu is back to normal if you keep it open.
        if (row.kind !== "volume") clearSearch();
    }

    function clearSearch() { searching = false; query = ""; }

    // h/l and the horizontal arrows adjust whichever stream the current row
    // belongs to, so you can land on an output and change its level without
    // first walking down to the slider.
    function nudge(delta) {
        const row = rows[selected];
        if (!row) return;
        const isSource = row.kind === "source"
            || (row.kind === "volume" && row.which === "source");
        if (isSource) Audio.setMicVolume(Audio.micVolume + delta);
        else Audio.setSinkVolume(Audio.sinkVolume + delta);
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            // While typing a filter, letters are text rather than commands.
            // Only the keys that can't be part of a device name stay live:
            // moving the cursor, choosing, and getting out.
            if (root.searching) {
                switch (event.key) {
                case Qt.Key_Escape:
                    // First Esc abandons the search, a second closes the menu —
                    // so a mistyped filter doesn't cost you the whole menu.
                    root.clearSearch();
                    break;
                case Qt.Key_Return: case Qt.Key_Enter:  root.activate(); break;
                case Qt.Key_Down:                      root.move(1); break;
                case Qt.Key_Up:                        root.move(-1); break;
                case Qt.Key_Backspace:
                    root.query = root.query.slice(0, -1);
                    break;
                default:
                    if (event.text && event.text >= " ") root.query += event.text;
                    else return;
                }
                event.accepted = true;
                return;
            }

            switch (event.key) {
            case Qt.Key_Slash:
                root.searching = true;
                root.query = "";
                break;
            case Qt.Key_Escape:                        root.hide(); break;
            case Qt.Key_J: case Qt.Key_Down:           root.move(1); break;
            case Qt.Key_K: case Qt.Key_Up:             root.move(-1); break;
            case Qt.Key_G:
                // g to the top, G (shift) to the bottom, as in vim.
                root.selected = (event.modifiers & Qt.ShiftModifier)
                    ? root.rows.length - 1 : 0;
                break;
            case Qt.Key_H: case Qt.Key_Left:           root.nudge(-0.05); break;
            case Qt.Key_L: case Qt.Key_Right:          root.nudge(0.05); break;
            case Qt.Key_BracketLeft:                   root.jumpSection(-1); break;
            case Qt.Key_BracketRight:                  root.jumpSection(1); break;
            case Qt.Key_Return: case Qt.Key_Enter:
            case Qt.Key_Space:                         root.activate(); break;
            case Qt.Key_M:                             root.activate(); break;
            default: return;                           // let anything else through
            }
            event.accepted = true;
        }

        // Anything not the card dismisses. The bar sits under this overlay,
        // so clicking the speaker icon lands here rather than on the bar —
        // which is the behaviour you want anyway: the second click closes.
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: card
            width: 300
            implicitHeight: content.implicitHeight + 16
            height: implicitHeight
            // Tucked against the bar on the side the status icons live.
            anchors {
                right: parent.right
                rightMargin: 8
                bottom: Theme.bottom ? parent.bottom : undefined
                bottomMargin: Theme.bottom ? Theme.barHeight + 6 : 0
                top: Theme.bottom ? undefined : parent.top
                topMargin: Theme.bottom ? 0 : Theme.barHeight + 6
            }
            color: Theme.menuBg
            radius: 10
            border { width: 1; color: Theme.sumiInk3 }

            // Swallow clicks so they don't reach the dismiss area behind.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: content
                anchors { fill: parent; margins: 8 }
                spacing: 1

                // Only present while filtering — the menu is small enough that
                // a permanent search box would be more furniture than help.
                RowLayout {
                    visible: root.searching
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    Layout.leftMargin: 6
                    spacing: 6

                    Text {
                        text: "/"
                        color: Theme.accent
                        font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
                    }

                    Text {
                        text: root.query
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: 12 }
                        Layout.fillWidth: true
                    }

                    // Silent when a filter matches nothing, and you'd wonder
                    // whether the menu had broken.
                    Text {
                        visible: root.rows.length === 0
                            || !root.rows.some(r => r.kind !== "volume")
                        text: "no match"
                        color: Theme.fgFaint
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }

                Repeater {
                    model: root.rows
                    delegate: MenuRow {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        row: modelData
                        active: index === root.selected
                        // Pointing at something selects it, so the highlight
                        // never disagrees with what Enter would act on.
                        onHovered: root.selected = index
                        onClicked: { root.selected = index; root.activate(); }
                        onScrolled: d => { root.selected = index; root.nudge(d); }

                        // A header sits above the first row of each section.
                        heading: index === 0
                            || root.rows[index - 1].section !== modelData.section
                                ? modelData.section : ""
                    }
                }
            }
        }
    }
}
