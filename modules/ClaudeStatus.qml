import QtQuick
import Quickshell
import ".."
import "../services" as Svc

// Claude rate limits, following the interest rules: plenty of quota is the
// boring case, so it draws nothing at all. The widget exists for the two
// moments worth a glance — you're getting close to a limit, or you're about
// to start something big and want to know if there's room.
//
//   < 50%  — nothing. The answer is "you're fine" and the bar says it by
//            staying empty.
//   >= 50% — the fuller bucket as a percentage. Colour walks fg → warn → bad.
//   hover  — every bucket with its reset countdown, since "77%" immediately
//            asks "of which window, and until when".
//
// Data is only as fresh as the last statusline render (see ClaudeUsage), so a
// stale number greys out rather than lying confidently.
Item {
    id: root

    readonly property bool interesting:
        Svc.ClaudeUsage.known && Svc.ClaudeUsage.worst >= 50

    visible: interesting
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 22

    readonly property bool hovered: area.containsMouse

    Row {
        id: row
        spacing: 5
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: "✳"
            font { family: Theme.font; pixelSize: 12 }
            color: label.color
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: label
            text: `${Math.round(Svc.ClaudeUsage.worst)}%`
            font { family: Theme.font; pixelSize: 12 }
            color: Svc.ClaudeUsage.stale ? Theme.off
                : Svc.ClaudeUsage.worst >= 90 ? Theme.bad
                : Svc.ClaudeUsage.worst >= 70 ? Theme.warn
                : Theme.fgDim
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
    }

    // The full picture, one line per bucket. A tooltip rather than a menu:
    // there's nothing to act on here, only to know. Its own window because the
    // bar surface is barHeight tall and clips anything drawn past its edge.
    PopupWindow {
        visible: root.hovered
        anchor.item: root
        anchor.rect.x: root.width / 2 - implicitWidth / 2
        anchor.rect.y: Theme.bottom ? -(implicitHeight + 10) : root.height + 10

        implicitWidth: tip.implicitWidth + 20
        implicitHeight: tip.implicitHeight + 14
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.menuBg
            border { width: 1; color: Theme.sumiInk3 }

            Column {
                id: tip
                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: Svc.ClaudeUsage.windows

                    delegate: Text {
                        required property var modelData
                        text: {
                            // "five_hour" -> "5h", "seven_day" -> "7d"; anything
                            // new shows its raw key rather than hiding.
                            const names = { five_hour: "5h", seven_day: "7d" };
                            const name = names[modelData.key] ?? modelData.key;
                            const reset = Svc.ClaudeUsage.untilReset(modelData.resetsAt);
                            return `${name}  ${Math.round(modelData.used)}%  ·  resets in ${reset}`;
                        }
                        color: modelData.used >= 90 ? Theme.bad
                            : modelData.used >= 70 ? Theme.warn
                            : Theme.fg
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }

                Text {
                    visible: Svc.ClaudeUsage.stale
                    text: "stale — no session rendering"
                    color: Theme.off
                    font { family: Theme.font; pixelSize: 10; italic: true }
                }
            }
        }
    }
}
