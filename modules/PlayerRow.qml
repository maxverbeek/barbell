import QtQuick
import QtQuick.Layouts
import ".."
import "../services" as Svc

// One MPRIS player in the media menu: its state, what it's on, and which app
// it is. The play state is the glyph — a row you'd Enter to pause shows
// playing, same as a checkmark shows the current audio device.
Item {
    id: root

    required property var row
    property bool active: false
    property string heading: ""

    signal hovered()
    signal clicked()

    readonly property bool empty: row.kind === "empty"
    readonly property var player: empty ? null : row.player
    readonly property bool playing: player?.isPlaying ?? false

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
        color: root.active && !root.empty ? Theme.islandActive : "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 8 }
            spacing: 8

            Text {
                text: root.empty ? "󰎈"
                    : root.playing ? "󰐊"
                    : "󰏤"
                font { family: Theme.iconFont; pixelSize: 13 }
                color: root.playing ? Theme.good : Theme.fgFaint
            }

            Text {
                text: {
                    if (root.empty) return "nothing playing";
                    const t = root.player.trackTitle ?? "";
                    const a = root.player.trackArtist ?? "";
                    const track = a !== "" && t !== "" ? `${a} — ${t}` : t;
                    return track !== ""
                        ? `${track}`
                        : root.player.identity;
                }
                color: root.empty ? Theme.fgFaint
                    : root.playing ? Theme.fg
                    : Theme.fgDim
                font { family: Theme.font; pixelSize: 12 }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Which app, when the track alone doesn't say.
            Text {
                visible: !root.empty && (root.player.trackTitle ?? "") !== ""
                text: root.empty ? "" : root.player.identity
                color: Theme.fgFaint
                font { family: Theme.font; pixelSize: 10 }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.empty
            onEntered: root.hovered()
            onClicked: root.clicked()
        }
    }
}
