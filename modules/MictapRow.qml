import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// One line of the mictap tab: the running recording with its stop button, an
// input to start from, or one of today's recordings with its transcription.
Item {
    id: root

    required property var row
    property bool active: false
    property string heading: ""

    signal hovered()
    signal clicked()

    property real now: Date.now()
    Timer {
        interval: 1000
        running: root.row.kind === "stop"
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    function clock(ms) {
        const s = Math.max(0, Math.floor(ms / 1000));
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, pad = n => String(n).padStart(2, "0");
        return (h ? h + ":" + pad(m) : m) + ":" + pad(s % 60);
    }

    readonly property string title: {
        switch (row.kind) {
        case "stop":
            return clock(now - (Mictap.status.started_ms ?? now))
                + (Mictap.status.app ? "  " + Mictap.status.app : "");
        case "start": return Audio.label(row.node);
        // Onboard mics are named after the chip; drop it, as Audio.label does.
        case "track": return row.track.name.replace(/^.*\bcAVS\s+/, "");
        case "rec": return row.rec.date ? row.rec.date.slice(11) : "not uploaded yet";
        case "loading": return "Loading...";
        case "error": return "Server unreachable";
        default: return "Nothing recorded today";
        }
    }

    readonly property string detail: {
        const r = row.rec;
        if (row.kind === "start") return row.node === Audio.source ? "default" : "";
        if (row.kind === "track") return row.track.key === "mic" ? "mic" : "meeting audio";
        if (row.kind !== "rec") return "";
        if (r.status === "transcribing")
            return `transcribing ${Math.floor(r.done_ms / 60000)}/${Math.ceil(r.total_ms / 60000)} min`;
        if (r.status === "done") return r.transcript ? "done" : "no speech";
        return r.status;
    }

    readonly property bool actionable: row.kind === "stop" || row.kind === "start"

    implicitHeight: (heading !== "" ? label.implicitHeight + 8 : 0) + 28

    Text {
        id: label
        visible: root.heading !== ""
        text: root.heading
        color: Theme.fgFaint
        font { family: Theme.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 0.6 }
        anchors { left: parent.left; leftMargin: 6; top: parent.top; topMargin: 3 }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 28
        radius: 6
        color: root.active ? Theme.islandActive : "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
            spacing: 8

            Text {
                text: root.row.kind === "stop" ? "●"
                    : root.row.kind === "start" || root.row.track?.key === "mic" ? "󰍬"
                    : root.row.kind === "track" ? "󰕾"
                    : root.row.kind === "rec" ? "󰈙" : " "
                font { family: Theme.iconFont; pixelSize: 13 }
                color: root.actionable ? Theme.fg : Theme.fgDim
                Layout.preferredWidth: 16
            }

            Text {
                text: root.title
                color: root.row.kind === "rec" || root.row.kind === "track" || root.actionable ? Theme.fg : Theme.fgFaint
                font { family: Theme.font; pixelSize: 12 }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: root.detail !== ""
                text: root.detail
                color: Theme.fgDim
                font { family: Theme.font; pixelSize: 11 }
            }

            // The stop control reads as a button, not as more status text.
            Rectangle {
                visible: root.row.kind === "stop"
                implicitWidth: stop.implicitWidth + 16
                implicitHeight: 20
                radius: 5
                color: "transparent"
                border { width: 1; color: Theme.fg }

                Text {
                    id: stop
                    anchors.centerIn: parent
                    text: "Stop & save"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: 11; weight: Font.DemiBold }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hovered()
            onClicked: root.clicked()
        }
    }
}
