import QtQuick
import Quickshell.Widgets
import ".."
import "../services" as Svc

// Agents that need you, and nothing else. Working is not news and idle is not
// news; herdr's `blocked` (a question or approval is on screen) and `done`
// (finished while you were elsewhere) are the two states where the next move
// is yours, so those are the only ones that earn a place on the bar. Click
// goes to the most urgent one: blocked before done.
Item {
    id: root

    readonly property var wanting: Svc.Herdr.wanting
    readonly property var first: wanting.find(a => a.agent_status === "blocked") ?? wanting[0] ?? null
    readonly property color tone: first?.agent_status === "blocked" ? Theme.warn : Theme.good

    visible: first !== null
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 22

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        IconImage {
            source: root.first ? Svc.Icons.resolve(Svc.Icons.agentIcon(root.first.agent, root.first.agent_status)) : ""
            implicitSize: 14
            anchors.verticalCenter: parent.verticalCenter

            // The same dot the pill draws, so one mark means one thing.
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors { right: parent.right; bottom: parent.bottom; margins: -1 }
                color: root.tone
                border { width: 1; color: Theme.barBg }
            }
        }

        Text {
            visible: root.wanting.length > 1
            text: root.wanting.length
            color: root.tone
            font { family: Theme.font; pixelSize: 13 }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        onClicked: if (root.first) Svc.Herdr.focus(root.first)
    }
}
