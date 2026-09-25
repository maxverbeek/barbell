pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// mictap's recording state from its socket: one `subscribe` connection gets a
// status line now and on every change. Commands go through the CLI, like herdr.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/mictap.sock"

    property var status: ({ recording: false })
    readonly property bool recording: status.recording === true

    function start(source) {
        Quickshell.execDetached(source ? ["mictap", "start", "--source", source] : ["mictap", "start"]);
    }
    function stop() { Quickshell.execDetached(["mictap", "stop"]); }
    function discard() { Quickshell.execDetached(["mictap", "discard"]); }

    Socket {
        id: sub
        path: root.socketPath
        onConnectionStateChanged: {
            if (connected) write('{"cmd":"subscribe"}\n');
            else root.status = { recording: false };
        }
        parser: SplitParser {
            onRead: line => { try { root.status = JSON.parse(line); } catch (e) {} }
        }
    }

    // The daemon restarting (or not up yet at login) just means reconnecting.
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!sub.connected) sub.connected = true
    }
}
