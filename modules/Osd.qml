import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services" as Svc

// Volume and mute feedback, for when the change came from a key rather than
// from the menu. Appears on change, fades after a moment, never takes focus.
//
// Deliberately not shown when the audio menu is open — the menu already has a
// slider you're looking at, and a second readout of the same number is noise.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // What triggered this, so the icon matches the thing you changed.
    property string kind: ""      // "sink" | "source"
    property bool showing: false

    readonly property bool isSource: kind === "source"
    readonly property real level: isSource ? Svc.Audio.micVolume : Svc.Audio.sinkVolume
    readonly property bool muted: isSource ? Svc.Audio.micMuted : Svc.Audio.sinkMuted

    // No keyboard focus and no exclusive zone: this floats over whatever you
    // were doing without disturbing it.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: 0

    visible: showing
    anchors { bottom: Theme.bottom; top: !Theme.bottom; left: true; right: true }
    margins { bottom: Theme.bottom ? Theme.barHeight + 24 : 0
              top: Theme.bottom ? 0 : Theme.barHeight + 24 }
    implicitHeight: 44
    color: "transparent"

    // Only on the screen you're looking at. Two monitors flashing the same
    // pill is twice the interruption for the same information.
    readonly property bool onFocusedScreen:
        Svc.Niri.focusedOutput === "" || Svc.Niri.focusedOutput === modelData.name

    function flash(which) {
        // The menu is a better readout than this is.
        if (Svc.Menus.current !== "" || !onFocusedScreen) return;
        kind = which;
        showing = true;
        hide.restart();
    }

    Timer { id: hide; interval: 1400; onTriggered: root.showing = false }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 200
        height: 36
        radius: 18
        color: Theme.menuBg
        border { width: 1; color: Theme.sumiInk3 }
        opacity: root.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Row {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 10

            Text {
                text: root.isSource
                        ? (root.muted ? "󰍭" : "󰍬")
                    : root.muted ? "󰝟"
                    : root.level >= 0.5 ? "󰕾"
                    : root.level > 0 ? "󰖀"
                    : "󰕿"
                font { family: Theme.iconFont; pixelSize: 15 }
                color: root.muted ? Theme.bad : Theme.fg
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 108
                height: 4
                radius: 2
                color: Theme.sumiInk4
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.level))
                    height: parent.height
                    radius: parent.radius
                    color: root.muted ? Theme.bad : Theme.accent
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }

            Text {
                // Muted says so rather than showing a number that's a lie
                // about what you'll hear.
                text: root.muted ? "mute" : Math.round(root.level * 100)
                color: root.muted ? Theme.bad : Theme.fgDim
                font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
                horizontalAlignment: Text.AlignRight
                width: 30
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Volume and mute changes from anywhere — hardware keys, wpctl, the menu,
    // another app — all land as property changes here, so there's nothing to
    // hook into the keybinds themselves.
    //
    // The initial value arriving at startup would flash the OSD for no reason,
    // so nothing shows until the first change after a short settle.
    property bool ready: false
    Timer { running: true; interval: 2500; onTriggered: root.ready = true }

    Connections {
        target: Svc.Audio
        enabled: root.ready
        function onSinkVolumeChanged() { root.flash("sink"); }
        function onSinkMutedChanged() { root.flash("sink"); }
        function onMicVolumeChanged() { root.flash("source"); }
        function onMicMutedChanged() { root.flash("source"); }
    }
}
