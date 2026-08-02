import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Services.Notifications as Notif
import ".."
import "../services" as Svc

// Notifications as they arrive, stacked at the top-right corner. No focus and
// no exclusive zone, so they float over whatever you're doing.
//
// Click to dismiss, middle-click to clear the lot. Critical ones don't expire
// on their own — if something claims to be critical it can wait to be read.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Only where you're looking. Same reasoning as the OSD: two monitors
    // showing the same notification is twice the interruption.
    readonly property bool onFocusedScreen:
        Svc.Niri.focusedOutput === "" || Svc.Niri.focusedOutput === modelData.name

    readonly property var items: onFocusedScreen ? Svc.Notifications.active : []

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: 0

    visible: items.length > 0
    // Always top-right, wherever the bar happens to sit. Notifications live in
    // the corner you aren't working in, and tying them to the bar's edge would
    // put them under your hands whenever the bar is at the bottom.
    //
    // The margin is only the gap. The bar claims its height as an exclusive
    // zone, so the compositor already places this surface clear of it —
    // adding barHeight here too pushed it a second 34px down.
    anchors { top: true; right: true }
    margins { top: 12; right: 12 }
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"

    ColumnLayout {
        id: stack
        anchors.fill: parent
        spacing: 8

        Repeater {
            model: root.items

            delegate: Rectangle {
                id: card

                required property var modelData
                required property int index

                readonly property var notif: modelData
                readonly property bool critical:
                    notif.urgency === Notif.NotificationUrgency.Critical

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + 20

                radius: 10
                color: Theme.menuBg
                border {
                    width: 1
                    // Critical earns the only coloured border on screen.
                    color: card.critical ? Theme.bad : Theme.border
                }

                // Slide in from the right rather than appearing — motion says
                // "this is new" without needing a sound.
                opacity: 0
                x: 24
                Component.onCompleted: { opacity = 1; x = 0; }
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: body
                    anchors { fill: parent; margins: 10 }
                    spacing: 10

                    // The app's own image if it sent one, else its icon. Apps
                    // that send neither get nothing rather than a placeholder.
                    IconImage {
                        visible: source !== ""
                        source: {
                            const img = card.notif.image;
                            // notify-send --icon=NAME arrives here as
                            // image://icon/NAME, and that provider only knows
                            // the icon theme — a bundled name like claude-code
                            // renders as the missing-image checkerboard. Unwrap
                            // it and resolve ourselves, customs included; a
                            // name nobody knows shows nothing, not a grid.
                            if (img.startsWith("image://icon/"))
                                return Svc.Icons.resolve(img.slice(13));
                            if (img !== "")
                                return img;
                            return card.notif.appIcon !== ""
                                ? Svc.Icons.resolve(card.notif.appIcon) : "";
                        }
                        implicitSize: 32
                        Layout.alignment: Qt.AlignTop
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: card.notif.summary
                                color: Theme.fg
                                font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Which app, when the summary alone doesn't say.
                            Text {
                                visible: card.notif.appName !== ""
                                text: card.notif.appName
                                color: Theme.fgFaint
                                font { family: Theme.font; pixelSize: 10 }
                            }
                        }

                        Text {
                            visible: text !== ""
                            text: card.notif.body
                            color: Theme.fgDim
                            font { family: Theme.font; pixelSize: 11 }
                            wrapMode: Text.WordWrap
                            // Long bodies get cut rather than growing a card
                            // tall enough to cover the screen.
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            Layout.fillWidth: true
                        }

                        // Whatever the sender offered. Invoking one closes the
                        // notification, same as every other implementation.
                        RowLayout {
                            visible: card.notif.actions.length > 0
                            Layout.topMargin: 4
                            spacing: 6

                            Repeater {
                                model: card.notif.actions

                                delegate: Rectangle {
                                    required property var modelData

                                    implicitWidth: actionText.implicitWidth + 16
                                    implicitHeight: 22
                                    radius: 5
                                    color: actionArea.containsMouse ? Theme.islandHover : Theme.island

                                    Text {
                                        id: actionText
                                        anchors.centerIn: parent
                                        text: modelData.text
                                        color: Theme.fg
                                        font { family: Theme.font; pixelSize: 11 }
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            modelData.invoke();
                                            Svc.Notifications.dismiss(card.notif);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    hoverEnabled: true
                    // Reading takes longer than the timeout allows, so hovering
                    // holds it — the cursor is the only signal we have that
                    // someone is actually looking.
                    onEntered: holdOpen.running = true
                    onExited: holdOpen.running = false
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) Svc.Notifications.dismissAll();
                        else Svc.Notifications.dismiss(card.notif);
                    }
                    // Below the action buttons so they get the click first.
                    z: -1
                }

                // While hovered, keep pushing the expiry back so it stays up.
                Timer {
                    id: holdOpen
                    interval: 400
                    repeat: true
                    onTriggered: expiry.restart()
                }

                // Each card times out on its own clock, so a burst doesn't all
                // vanish at once and the one you're reading isn't cut short by
                // an older one's timer.
                //
                // Stops once the notification is no longer tracked: an action
                // or the sender can close it first, and firing then would reach
                // for an object the server has already destroyed.
                Timer {
                    id: expiry
                    running: !card.critical && interval > 0 && card.notif.tracked
                    interval: Svc.Notifications.timeoutFor(card.notif)
                    onTriggered: Svc.Notifications.expire(card.notif)
                }
            }
        }
    }
}
