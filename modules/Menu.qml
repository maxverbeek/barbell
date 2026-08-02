import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

// The shell every menu shares: the panel, the keyboard model, `/` search,
// section jumping, click-outside dismissal.
//
// A menu supplies `name`, an `allRows` list and a `delegate`, plus whatever
// `activate` and `nudge` should do for its own rows. Everything else — the
// index arithmetic, the filter, focus handling — lives here once rather than
// being copied per menu.
//
// Built keyboard-first: it takes exclusive keyboard focus when it opens, so
// j/k or the arrows move, Enter selects, Esc dismisses. The mouse is the
// second path — hover moves the selection, so the two never disagree about
// what's active.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Which menu this is, as Menus knows it.
    required property string name
    // Every row, unfiltered. Each needs at least { section }.
    required property var allRows
    // Component used to draw one row. Gets `row`, `active`, `heading`.
    required property Component delegate

    // What Enter does on the current row, and what h/l adjust. Menus that
    // have nothing to nudge simply don't override it.
    property var activateRow: row => {}
    property var nudgeRow: (row, delta) => {}
    // Text a row is matched against while searching. Rows returning "" are
    // never filtered out — that's how the audio sliders survive a query.
    property var rowText: row => ""

    property int cardWidth: 300

    // Extra bindings, per menu. Returns true if it took the key.
    property var handleKey: event => false

    readonly property bool open: Menus.isOpen(name)

    property bool searching: false
    property string query: ""

    readonly property var rows: {
        if (query === "") return allRows;
        const q = query.toLowerCase();
        return allRows.filter(r => {
            const t = rowText(r);
            return t === "" || t.toLowerCase().includes(q);
        });
    }

    property int selected: 0

    // Typing a filter should put the cursor on what you were looking for —
    // the first row that actually matched, not one of the always-present rows
    // the filter can't remove. With no query it just has to stay in bounds
    // when the list changes underneath (a device connecting rewrites it).
    onRowsChanged: {
        if (query !== "") {
            const first = rows.findIndex(r => rowText(r) !== "");
            selected = first >= 0 ? first : 0;
        } else if (selected >= rows.length) {
            selected = Math.max(0, rows.length - 1);
        }
    }

    // Layer-shell surfaces don't get keyboard input unless they ask.
    // Exclusive means the menu owns the keyboard while it's up, which is what
    // makes Esc and j/k work rather than reaching the window below.
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive
                                      : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    visible: open
    // Covers the screen so a click anywhere outside the card dismisses.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    function hide() { Menus.close(); }
    function clearSearch() { searching = false; query = ""; }

    // Focus has to be claimed once the surface is actually up, hence keying
    // off the change rather than doing it wherever open() is called.
    onOpenChanged: {
        if (open) {
            clearSearch();
            selected = initialRow();
            keys.forceActiveFocus();
            Menus.describe = describe;
        }
    }

    // Text dump of what's on screen, for `qs ipc call menu dump`.
    function describe() {
        const out = [`${name}  card ${cardWidth}x${Math.round(card.height)}`
            + (searching ? `  /${query}` : "")];
        let section = "";
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].section !== section) {
                section = rows[i].section;
                out.push(`  [${section}]`);
            }
            out.push(`  ${i === selected ? ">" : " "} ${rowLabel(rows[i])}`);
        }
        return out.join("\n");
    }

    // How a row reads in the dump. Menus override it to name their own rows.
    property var rowLabel: row => rowText(row) || row.kind

    // Where the cursor starts. Overridden by menus that want somewhere
    // specific — the audio menu opens on the output level.
    property var initialRow: () => 0

    function move(delta) {
        if (rows.length === 0) return;
        selected = (selected + delta + rows.length) % rows.length;
    }

    // Where a section's cursor should land. A menu can point this at its
    // active row so [ and ] land somewhere meaningful rather than on whatever
    // sorts first.
    property var anchorOf: section => rows.findIndex(r => r.section === section)

    // [ and ] move between sections. Backward goes to the current section's
    // anchor first when you're below it, so a repeated [ walks up rather than
    // sticking — the way [[ behaves in vim. Neither wraps.
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
            let start = selected;
            while (start > 0 && rows[start - 1].section === here) start--;
            if (start === 0) return;
            selected = anchorOf(rows[start - 1].section);
        }
    }

    function activate() {
        const row = rows[selected];
        if (row) activateRow(row);
    }

    function nudge(delta) {
        const row = rows[selected];
        if (row) nudgeRow(row, delta);
    }

    function nudgeStep(event) {
        return (event.modifiers & Qt.ShiftModifier) ? 0.01 : 0.05;
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            // A menu that's collecting text — a wifi password — needs the keys
            // before any of the navigation does, including Enter and Esc.
            if (root.handleKey(event)) { event.accepted = true; return; }

            // While typing a filter, letters are text rather than commands.
            // Only the keys that can't be part of a name stay live: moving the
            // cursor, choosing, and getting out.
            if (root.searching) {
                // Ctrl-j/k move without leaving the home row. Checked before
                // the switch because their event.text is a control character
                // that must never reach the query.
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) root.move(1);
                    else if (event.key === Qt.Key_K) root.move(-1);
                    else return;
                    event.accepted = true;
                    return;
                }
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

            // s/w/b cross between the menus without closing and reopening.
            // One summon gets you in; from there they're tabs. Checked before
            // the per-menu keys so a menu can't shadow the way out of itself.
            switch (event.key) {
            case Qt.Key_S: Menus.open("audio");     event.accepted = true; return;
            case Qt.Key_W: Menus.open("network");   event.accepted = true; return;
            case Qt.Key_B: Menus.open("bluetooth"); event.accepted = true; return;
            // p for player — m would be the obvious letter, but the audio menu
            // spends m on mute and a key that switches menus from two of the
            // tabs and mutes from the third is worse than a less obvious one.
            case Qt.Key_P: Menus.open("media");     event.accepted = true; return;
            case Qt.Key_C: Menus.open("claude");    event.accepted = true; return;
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
            // Shift for fine adjustment: one point instead of five.
            case Qt.Key_H: case Qt.Key_Left:           root.nudge(-root.nudgeStep(event)); break;
            case Qt.Key_L: case Qt.Key_Right:          root.nudge(root.nudgeStep(event)); break;
            case Qt.Key_BracketLeft:                   root.jumpSection(-1); break;
            case Qt.Key_BracketRight:                  root.jumpSection(1); break;
            case Qt.Key_Return: case Qt.Key_Enter:
            case Qt.Key_Space:                         root.activate(); break;
            default:
                // Anything the menu itself wants to handle.
                if (!root.handleKey(event)) return;
            }
            event.accepted = true;
        }

        // Anything not the card dismisses. The bar sits under this overlay, so
        // clicking the icon that opened it lands here rather than on the bar —
        // which is the behaviour you want anyway: the second click closes.
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: card
            width: root.cardWidth
            implicitHeight: content.implicitHeight + 16
            height: implicitHeight
            // Tucked against the bar on the side the status icons live. No
            // barHeight in the margins: this surface spans the screen *minus*
            // exclusive zones, so the compositor has already cleared the bar —
            // adding it here again left a bar-sized ghost gap.
            anchors {
                right: parent.right
                rightMargin: 8
                bottom: Theme.bottom ? parent.bottom : undefined
                bottomMargin: Theme.bottom ? 6 : 0
                top: Theme.bottom ? undefined : parent.top
                topMargin: Theme.bottom ? 0 : 6
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

                // The menus are tabs on one surface, so which one you're
                // in and how to reach the others is visible rather than
                // remembered. The letter is the key that gets you there.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    Layout.leftMargin: 2
                    spacing: 2

                    Repeater {
                        model: [
                            { menu: "audio",     key: "s", glyph: "󰕾" },
                            { menu: "network",   key: "w", glyph: "󰤨" },
                            { menu: "bluetooth", key: "b", glyph: "󰂯" },
                            { menu: "media",     key: "p", glyph: "󰎈" },
                            { menu: "claude",    key: "c", glyph: "✳" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool here: modelData.menu === root.name

                            Layout.fillWidth: true
                            implicitHeight: 22
                            radius: 5
                            color: here ? Theme.islandActive : "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: modelData.glyph
                                    font { family: Theme.iconFont; pixelSize: 12 }
                                    color: parent.parent.here ? Theme.fg : Theme.fgFaint
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: modelData.key
                                    font { family: Theme.font; pixelSize: 10 }
                                    color: parent.parent.here ? Theme.fgDim : Theme.fgFaint
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Menus.open(modelData.menu)
                            }
                        }
                    }
                }

                // Only present while filtering — the menus are small enough
                // that a permanent search box would be furniture.
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
                        visible: !root.rows.some(r => root.rowText(r) !== "")
                        text: "no match"
                        color: Theme.fgFaint
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }

                Repeater {
                    model: root.rows
                    delegate: root.delegate
                }
            }
        }
    }
}
