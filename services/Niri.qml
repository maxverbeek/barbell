pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Quickshell ships Hyprland and I3 integrations but not niri. This is the
// whole thing: one long-lived `niri msg --json event-stream`, parsed into two
// properties that every widget binds to.
Singleton {
    id: root

    // Workspace objects straight from niri, sorted by idx.
    property var workspaces: []
    // Window objects keyed by id.
    property var windows: ({})

    // Which output has focus, by connector name — the active workspace's own
    // output. "" until the first event arrives. Used by anything that should
    // appear on one screen rather than all of them.
    readonly property string focusedOutput: {
        const ws = workspaces.find(w => w.is_focused) ?? workspaces.find(w => w.is_active);
        return ws?.output ?? "";
    }

    // Windows on a workspace, in the order they appear on screen.
    //
    // niri reports two position fields in different units:
    // tile_pos_in_workspace_view is pixels but null once a window scrolls out
    // of view, pos_in_scrolling_layout is a [column, row] index. Ranking by
    // which field exists keeps on-screen windows ahead of the rest instead of
    // interleaving pixel offsets with column numbers.
    function focusWindow(id) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(id)]);
    }

    function windowsOn(workspaceId) {
        const rank = w => w.layout?.tile_pos_in_workspace_view ? 0 : (w.layout?.pos_in_scrolling_layout ? 1 : 2);
        const pos = w => w.layout?.tile_pos_in_workspace_view ?? w.layout?.pos_in_scrolling_layout ?? [0, 0];
        return Object.values(windows).filter(w => w.workspace_id === workspaceId).sort((a, b) => {
            if (rank(a) !== rank(b))
                return rank(a) - rank(b);
            const [ax, ay] = pos(a), [bx, by] = pos(b);
            return (ax - bx) || (ay - by) || (a.id - b.id);
        });
    }

    function focusWorkspace(id) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(id)]);
    }

    Process {
        id: events
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => root.handleEvent(line)
        }
        // Survive a niri restart rather than leaving a dead bar behind.
        onExited: reconnect.start()
    }

    Timer {
        id: reconnect
        interval: 1000
        onTriggered: events.running = true
    }

    function handleEvent(line) {
        let event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            return; // a niri upgrade adding fields must never kill the stream
        }

        if (event.WorkspacesChanged) {
            workspaces = event.WorkspacesChanged.workspaces.slice().sort((a, b) => a.idx - b.idx);
        } else if (event.WorkspaceActivated) {
            const { id, focused } = event.WorkspaceActivated;
            const target = workspaces.find(w => w.id === id);
            if (!target)
                return;
            // Activation is per output: only that output's workspaces change.
            workspaces = workspaces.map(w => w.output !== target.output ? w : Object.assign({}, w, {
                is_active: w.id === id,
                is_focused: focused ? w.id === id : w.is_focused
            }));
        } else if (event.WorkspaceActiveWindowChanged) {
            const { workspace_id, active_window_id } = event.WorkspaceActiveWindowChanged;
            workspaces = workspaces.map(w => w.id !== workspace_id ? w : Object.assign({}, w, { active_window_id }));
        } else if (event.WorkspaceUrgencyChanged) {
            const { id, urgent } = event.WorkspaceUrgencyChanged;
            workspaces = workspaces.map(w => w.id !== id ? w : Object.assign({}, w, { is_urgent: urgent }));
        } else if (event.WindowsChanged) {
            const map = {};
            for (const w of event.WindowsChanged.windows)
                map[w.id] = w;
            windows = map;
        } else if (event.WindowOpenedOrChanged) {
            const w = event.WindowOpenedOrChanged.window;
            // niri sends is_focused on the window itself here; if it claims
            // focus, nobody else has it.
            const map = {};
            for (const key in windows)
                map[key] = w.is_focused ? Object.assign({}, windows[key], { is_focused: false }) : windows[key];
            map[w.id] = w;
            windows = map;
        } else if (event.WindowClosed) {
            const map = Object.assign({}, windows);
            delete map[event.WindowClosed.id];
            windows = map;
        } else if (event.WindowFocusChanged) {
            const id = event.WindowFocusChanged.id; // null when nothing is focused
            const map = {};
            for (const key in windows)
                map[key] = Object.assign({}, windows[key], { is_focused: windows[key].id === id });
            windows = map;
        } else if (event.WindowLayoutsChanged) {
            const map = Object.assign({}, windows);
            for (const [id, layout] of event.WindowLayoutsChanged.changes)
                if (map[id])
                    map[id] = Object.assign({}, map[id], { layout });
            windows = map;
        }
    }
}
