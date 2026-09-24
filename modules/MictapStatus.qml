import QtQuick
import ".."
import "../services"

// A recording in progress, and nothing when idle. Red while recording, warn
// while the meeting is gone and the stop grace counts down. Click stops,
// right-click discards.
Item {
    id: root

    property real now: Date.now()
    readonly property int secs: Math.max(0, Math.floor((now - (Mictap.status.started_ms ?? now)) / 1000))
    readonly property bool ending: Mictap.status.stopping_in != null
    readonly property color tone: ending ? Theme.warn : Theme.bad

    visible: Mictap.recording
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 22

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Row {
        id: row
        spacing: 5
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: 8; height: 8; radius: 4
            color: root.tone
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Math.floor(root.secs / 60) + ":" + String(root.secs % 60).padStart(2, "0")
            color: root.tone
            font { family: Theme.font; pixelSize: 13 }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? Mictap.discard() : Mictap.stop()
    }
}
