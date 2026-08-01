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
    readonly property var rows: {
        const out = [];
        out.push({ kind: "volume", which: "sink", section: "Levels" });
        out.push({ kind: "volume", which: "source", section: "Levels" });
        for (const n of Audio.sinks) out.push({ kind: "sink", node: n, section: "Output" });
        for (const n of Audio.sources) out.push({ kind: "source", node: n, section: "Input" });
        return out;
    }

    property int selected: 0

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

    // [ and ] jump between sections. Forward lands on the first row of the
    // next section; backward goes to the top of the current one first, so a
    // repeated [ walks up section by section rather than sticking — the same
    // way [[ behaves in vim.
    function jumpSection(dir) {
        if (rows.length === 0) return;
        const here = rows[selected].section;
        if (dir > 0) {
            for (let i = selected + 1; i < rows.length; i++)
                if (rows[i].section !== here) { selected = i; return; }
            selected = rows.length - 1;     // already in the last section
        } else {
            // Walk back to where this section began.
            let start = selected;
            while (start > 0 && rows[start - 1].section === here) start--;
            if (start < selected) { selected = start; return; }
            // Already at the top of it: go to the start of the previous one.
            if (start === 0) return;
            const prev = rows[start - 1].section;
            let i = start - 1;
            while (i > 0 && rows[i - 1].section === prev) i--;
            selected = i;
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
    }

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
            switch (event.key) {
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
