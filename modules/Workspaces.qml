import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

RowLayout {
    // Set by Bar so each monitor shows only its own workspaces.
    required property string screenName

    spacing: 6

    Repeater {
        // Referencing Niri.workspaces directly is what makes this re-evaluate;
        // a bare workspacesOn(screenName) call would bind to nothing.
        model: Niri.workspaces.filter(w => w.output === screenName)

        delegate: Rectangle {
            required property var modelData

            implicitWidth: Math.max(24, row.implicitWidth + 12)
            implicitHeight: 22
            radius: 6
            color: modelData.is_active ? Theme.islandActive : (mouse.containsMouse ? Theme.islandHover : Theme.island)

            Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 4

                Text {
                    visible: windows.count === 0
                    text: modelData.idx
                    color: modelData.is_urgent ? Theme.bad : (modelData.is_active ? Theme.fg : Theme.fgDim)
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Repeater {
                    id: windows
                    // Niri.windows named explicitly so the binding re-runs.
                    model: Niri.windows && Niri.windowsOn(modelData.id)

                    delegate: Item {
                        required property var modelData

                        implicitWidth: 15
                        implicitHeight: 15

                        Image {
                            anchors.fill: parent
                            source: Icons.forWindow(modelData)
                            sourceSize: Qt.size(15, 15)
                            opacity: modelData.is_focused ? 1.0 : 0.5
                        }

                        // Absolute so the focus underline can't push the icon up.
                        Rectangle {
                            visible: modelData.is_focused
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 1
                            width: parent.width - 4
                            height: 2
                            radius: 1
                            color: Theme.accent
                        }
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Niri.focusWorkspace(modelData.idx)
            }
        }
    }
}
