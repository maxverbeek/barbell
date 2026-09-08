import QtQuick
import QtQuick.Layouts
import Quickshell
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
            id: pill
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
                // Above the pill's MouseArea, so the herdr glyphs get their
                // own clicks and hover; the pill still gets everything else.
                z: 1

                Text {
                    visible: windows.count === 0
                    text: modelData.idx
                    color: modelData.is_urgent ? Theme.bad : (modelData.is_active ? Theme.fg : Theme.fgDim)
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                Repeater {
                    id: windows
                    // Niri.windows named explicitly so the binding re-runs.
                    model: Niri.windows && Niri.windowsOn(modelData.id)

                    delegate: Item {
                        id: slot
                        required property var modelData

                        // herdr's window is a window of windows. Its icon gives
                        // way to one glyph per agent inside it, sunk into a
                        // well so they read as one window's contents rather
                        // than four more windows.
                        readonly property var agents: Herdr.isWindow(modelData) ? Herdr.ordered : []
                        readonly property bool herdr: agents.length > 0

                        implicitWidth: herdr ? well.implicitWidth : 15
                        implicitHeight: 15

                        Image {
                            visible: !slot.herdr
                            anchors.fill: parent
                            source: Icons.forWindow(slot.modelData)
                            // Not every icon is square — neovim.svg is 602x734
                            // — and stretching one to a 15x15 box renders it
                            // taller and heavier than its square neighbours.
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(15, 15)
                        }

                        // Absolute so the focus underline can't push the icon up.
                        Rectangle {
                            visible: slot.modelData.is_focused && !slot.herdr
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 1
                            width: parent.width - 4
                            height: 2
                            radius: 1
                            color: Theme.accent
                        }

                        Rectangle {
                            id: well
                            visible: slot.herdr
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: glyphs.implicitWidth + 8
                            implicitHeight: 19
                            radius: 5
                            // One shade back from whatever the pill is, in
                            // either theme: darker means further away.
                            color: Qt.rgba(0, 0, 0, Theme.isLight ? 0.08 : 0.25)

                            Row {
                                id: glyphs
                                anchors.centerIn: parent
                                spacing: 4

                                Repeater {
                                    // Four at most; the rest fold into +n below.
                                    model: slot.agents.slice(0, 4)

                                    delegate: Item {
                                        id: glyph
                                        required property var modelData

                                        readonly property string status: modelData.agent_status

                                        implicitWidth: 15
                                        implicitHeight: 15

                                        Image {
                                            anchors.fill: parent
                                            source: Icons.resolve(Icons.agentIcon(glyph.modelData.agent, glyph.status))
                                            fillMode: Image.PreserveAspectFit
                                            sourceSize: Qt.size(15, 15)
                                            opacity: glyph.status === "idle" || glyph.status === "unknown" ? 0.6 : 1
                                        }

                                        // blocked and done are the two states
                                        // where the next move is yours; working
                                        // already shows as the spinner and idle
                                        // shows as nothing.
                                        Rectangle {
                                            visible: glyph.status === "blocked" || glyph.status === "done"
                                            width: 6; height: 6; radius: 3
                                            anchors { right: parent.right; bottom: parent.bottom; margins: -1 }
                                            color: glyph.status === "blocked" ? Theme.warn : Theme.good
                                            border { width: 1; color: pill.color }
                                        }

                                        // herdr's own focused pane: what you'd
                                        // see if you looked at the window.
                                        // Accent when that window has niri's
                                        // focus too, faint when it doesn't.
                                        Rectangle {
                                            visible: glyph.modelData.focused
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.bottom
                                            width: parent.width - 4
                                            height: 2
                                            radius: 1
                                            color: slot.modelData.is_focused ? Theme.accent : Theme.fgFaint
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: Herdr.focus(glyph.modelData)
                                        }
                                    }
                                }

                                Text {
                                    visible: slot.agents.length > 4
                                    text: `+${slot.agents.length - 4}`
                                    font { family: Theme.font; pixelSize: 11 }
                                    anchors.verticalCenter: parent.verticalCenter
                                    // The fold takes the worst of what it hides.
                                    color: {
                                        const s = Herdr.worst(slot.agents.slice(4));
                                        return s === "blocked" ? Theme.warn : s === "done" ? Theme.good : Theme.fgDim;
                                    }
                                }
                            }

                            MouseArea {
                                id: wellHover
                                anchors.fill: parent
                                hoverEnabled: true
                                // Clicks fall through to the glyphs above.
                                acceptedButtons: Qt.NoButton
                            }

                            // What the glyphs stand for, one row per agent under
                            // its project — the same rows the c menu draws.
                            PopupWindow {
                                visible: wellHover.containsMouse
                                anchor.item: well
                                anchor.rect.x: well.width / 2 - implicitWidth / 2
                                anchor.rect.y: Theme.bottom ? -(implicitHeight + 10) : well.height + 10

                                implicitWidth: tip.implicitWidth + 20
                                implicitHeight: tip.implicitHeight + 14
                                color: "transparent"

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: Theme.menuBg
                                    border { width: 1; color: Theme.border }

                                    ColumnLayout {
                                        id: tip
                                        anchors.centerIn: parent
                                        spacing: 3

                                        Repeater {
                                            model: [].concat(...Herdr.groups.map(g => g.agents.map((a, i) => ({
                                                kind: "session", agent: a, section: g.ws.label || g.ws.workspace_id,
                                                title: a.terminal_title_stripped || a.agent, first: i === 0 }))))

                                            delegate: ClaudeRow {
                                                required property var modelData
                                                row: modelData
                                                heading: modelData.first ? modelData.section : ""
                                                Layout.preferredWidth: 300
                                                onClicked: Herdr.focus(modelData.agent)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Niri.focusWorkspace(modelData.idx)
                // Scroll pans the window view sideways. A trackpad sends many
                // small deltas per gesture, so accumulate and step once per
                // notch rather than firing on every event.
                property real acc: 0
                onWheel: wheel => {
                    acc += wheel.angleDelta.y || wheel.angleDelta.x;
                    while (Math.abs(acc) >= 120) {
                        // Wheel-up is positive and pans left, as in a document.
                        Niri.focusColumn(acc > 0 ? -1 : 1);
                        acc -= acc > 0 ? 120 : -120;
                    }
                }
            }
        }
    }
}
