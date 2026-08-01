import QtQuick
import QtQuick.Layouts
import ".."
import "../services" as Svc

// The connectivity indicators as one button rather than three glyphs you have
// to aim at individually. A 14px icon is a miserable click target, and there
// were three of them side by side each opening a different menu — so a miss
// didn't just do nothing, it opened the wrong thing.
//
// Everything in here opens the audio menu, because that's the one worth
// reaching for most often and s/w/b switches between the three in a keystroke
// once you're in. Readouts that open nothing — kube, battery, clock — stay
// outside: inside the island means clickable, and that only stays true if
// nothing unclickable lives here.
Item {
    id: root

    implicitWidth: content.implicitWidth + 20
    implicitHeight: 24

    readonly property bool hovered: area.containsMouse

    Rectangle {
        anchors.fill: parent
        radius: 6
        // Sits slightly out from the bar at rest so it reads as a control, and
        // lifts on hover. Any of the three menus being open counts too — leaving
        // it lit is what tells you where the panel came from, including after
        // s/w/b switched you to a different one.
        color: root.hovered || Svc.Menus.current !== ""
            ? Theme.islandHover
            : Theme.island
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 10

        NetworkStatus { Layout.alignment: Qt.AlignVCenter }

        BluetoothStatus { Layout.alignment: Qt.AlignVCenter }

        AudioStatus { Layout.alignment: Qt.AlignVCenter }
    }

    // One target across the whole island. The children keep their own areas for
    // the gestures a click can't express — middle-click to mute, wheel to
    // change volume — and this sits behind them so those still land.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        z: -1
        onClicked: Svc.Menus.toggle("audio")
    }
}
