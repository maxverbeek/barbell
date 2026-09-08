pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Agents running inside herdr, from its socket. herdr multiplexes every agent
// into one terminal window whose title never carries a spinner, so the title
// heuristics in Icons are blind to anything in it; this is the other source
// for the session list, and herdr's own idle/working/blocked/done states are
// richer than a glyph anyway (`done` is "finished while you weren't looking",
// which the title could never say).
//
// The socket is newline-delimited JSON with one quirk that shapes everything
// here: a connection takes exactly one request. So `snap` is a throwaway per
// snapshot and `sub` is the long-lived event stream. Status changes need one
// subscription per pane, and there's no wildcard, so when the set of agent
// panes changes the stream is torn down and reopened with the new list.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("HOME") + "/.config/herdr/herdr.sock"

    // Agent records as herdr reports them: agent (kind), agent_status, cwd,
    // pane_id, workspace_id, terminal_title_stripped. Status is patched in
    // place from events; everything else comes from the last snapshot.
    property var agents: []
    // {workspace_id, label, number, focused} for every herdr workspace.
    property var workspaces: []
    // herdr titles its window "<hostname>: <workspace>", which is how the bar
    // tells the herdr window from every other terminal.
    property string hostname: ""

    // One entry per herdr workspace that has an agent in it, in herdr's order.
    // Shell-only workspaces aren't news and don't appear anywhere.
    readonly property var groups: workspaces
        .map(ws => ({ ws, agents: agents.filter(a => a.workspace_id === ws.workspace_id) }))
        .filter(g => g.agents.length > 0)

    // The same agents flattened in that order: what the pill draws, one glyph
    // each, so two kinds in one workspace both show their mark.
    readonly property var ordered: [].concat(...groups.map(g => g.agents))

    readonly property var wanting: agents.filter(a => a.agent_status === "blocked" || a.agent_status === "done")

    // Worst first, so a group folds to the state that needs you most.
    readonly property var severity: ["blocked", "done", "working", "unknown", "idle"]
    function worst(list) {
        return list.map(a => a.agent_status).sort((a, b) => severity.indexOf(a) - severity.indexOf(b))[0] ?? "idle";
    }

    function isWindow(w) {
        return hostname !== "" && (w?.app_id ?? "") === "foot" && (w.title ?? "").startsWith(hostname + ": ");
    }

    function focusWindow() {
        const w = Object.values(Niri.windows).find(root.isWindow);
        if (w) Niri.focusWindow(w.id);
    }

    // Both halves: herdr switches to the pane, niri switches to herdr. Focusing
    // also marks the agent seen, which is what turns `done` back into `idle`.
    function focus(agent) {
        Quickshell.execDetached(["herdr", "agent", "focus", agent.pane_id]);
        focusWindow();
    }

    function focusWorkspace(ws) {
        Quickshell.execDetached(["herdr", "workspace", "focus", ws.workspace_id]);
        focusWindow();
    }

    Process {
        running: true
        command: ["hostname"]
        stdout: StdioCollector { onStreamFinished: root.hostname = text.trim() }
    }

    // Snapshot: connect, ask, read one line, done.
    Socket {
        id: snap
        path: root.socketPath
        onConnectionStateChanged: if (connected) write('{"id":"snap","method":"session.snapshot","params":{}}\n')
        onError: { root.agents = []; root.workspaces = []; }
        parser: SplitParser {
            onRead: line => {
                snap.connected = false;
                try {
                    root.ingest(JSON.parse(line).result.snapshot);
                } catch (e) {
                    root.agents = []; root.workspaces = [];
                }
            }
        }
    }

    function ingest(s) {
        agents = s.agents ?? [];
        workspaces = s.workspaces ?? [];
        // The stream only knows the panes it was opened with.
        if (sub.paneIds !== agents.map(a => a.pane_id).join(","))
            sub.connected = false;
    }

    // Lifecycle events arrive in bursts (a new stream replays recent ones), and
    // every one of them means "snapshot again". Once, after the burst.
    Timer {
        id: resync
        interval: 100
        onTriggered: snap.connected = true
    }

    Socket {
        id: sub
        path: root.socketPath

        property string paneIds: ""

        onConnectionStateChanged: {
            if (connected) {
                paneIds = root.agents.map(a => a.pane_id).join(",");
                const subs = ["pane.agent_detected", "pane.closed", "pane.exited", "pane.updated", "pane.focused",
                              "workspace.created", "workspace.closed", "workspace.focused", "workspace.renamed"]
                    .map(type => ({ type }));
                for (const a of root.agents)
                    subs.push({ type: "pane.agent_status_changed", pane_id: a.pane_id });
                write(JSON.stringify({ id: "sub", method: "events.subscribe", params: { subscriptions: subs } }) + "\n");
                // Subscribe first, snapshot second: nothing slips between them.
                resync.restart();
            } else {
                // Dropped by us (pane set changed) or by herdr (it quit): either
                // way the snapshot decides what's true now, and retry reopens.
                resync.restart();
            }
        }

        parser: SplitParser {
            onRead: line => {
                let msg;
                try { msg = JSON.parse(line); } catch (e) { return; }
                if (!msg.event) return;
                if (msg.event === "pane_agent_status_changed") {
                    const d = msg.data;
                    root.agents = root.agents.map(a => a.pane_id !== d.pane_id ? a
                        : Object.assign({}, a, { agent_status: d.agent_status,
                              terminal_title_stripped: d.title ?? a.terminal_title_stripped }));
                } else {
                    resync.restart();
                }
            }
        }
    }

    // herdr not running is the normal case on a fresh login: keep knocking,
    // cheaply. The same timer brings the stream back after a resubscribe.
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!sub.connected) sub.connected = true
    }
}
