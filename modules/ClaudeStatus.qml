import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."
import "../services" as Svc

// Claude rate limits, following the interest rules: plenty of quota is the
// boring case, so it draws nothing at all. What counts as "plenty" is pace,
// not level — 16% of the week gone is fine on Thursday and alarming an hour
// after reset, so the trigger is the projection: what linear burn says the
// bucket hits by its reset.
//
//   on pace to last  — nothing. The answer is "you're fine" and the bar says
//                      it by staying empty.
//   projected >= 100 — the at-risk bucket's used%, with ↗ to say it's the
//                      trend that's the problem, not the level.
//   used >= 70       — shown regardless of pace; close is close.
//   hover            — every bucket, its projection and reset countdown.
//
// Data is only as fresh as the last statusline render (see ClaudeUsage), so a
// stale number greys out rather than lying confidently.
Item {
    id: root

    readonly property var risk: Svc.ClaudeUsage.riskiest

    // The pace trigger needs a floor: minutes after a reset every prompt is
    // "over pace" and the widget would cry wolf over 4%.
    readonly property bool onPace: risk.used >= 20 && risk.projected >= 100

    readonly property bool interesting:
        Svc.ClaudeUsage.known && (risk.used >= 70 || onPace)

    visible: interesting
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 22

    readonly property bool hovered: area.containsMouse

    Row {
        id: row
        spacing: 5
        anchors.verticalCenter: parent.verticalCenter

        // The real mark, not a ✳ stand-in. It brings its own orange, so the
        // number alone carries warn/bad — fading the icon is reserved for
        // stale, where everything should look switched off.
        IconImage {
            source: Svc.Icons.resolve("claude-code")
            implicitSize: 14
            opacity: Svc.ClaudeUsage.stale ? 0.4 : 1
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: label
            // The arrow marks "burning too fast" as distinct from "nearly
            // full" — a low number in warn colour needs the why.
            text: `${Math.round(root.risk.used)}%${root.onPace ? "↗" : ""}`
            font { family: Theme.font; pixelSize: 13 }
            color: Svc.ClaudeUsage.stale ? Theme.off
                : root.risk.used >= 90 || root.risk.projected >= 150 ? Theme.bad
                : Theme.warn
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

            ColumnLayout {
                id: tip
                anchors.centerIn: parent
                spacing: 3

                // Real columns rather than one string per line, so the
                // percents and countdowns line up across buckets. No
                // projection number here — the pace maths lives in the colour
                // and the bar's ↗; a second percentage next to the first read
                // as noise, not information.
                GridLayout {
                    columns: 3
                    rowSpacing: 3
                    columnSpacing: 12

                    Repeater {
                        // One bucket = three cells, and a Repeater makes one
                        // delegate per item — so the model is cells, and each
                        // finds its bucket by division. The grid fills row by
                        // row, keeping every bucket on its own line.
                        model: Svc.ClaudeUsage.windows.length * 3

                        delegate: Text {
                            required property int index
                            readonly property var modelData:
                                Svc.ClaudeUsage.windows[Math.floor(index / 3)]
                            readonly property int cell: index % 3
                            readonly property color tone:
                                modelData.used >= 90 || modelData.projected >= 150 ? Theme.bad
                                : modelData.used >= 70 || modelData.projected >= 100 ? Theme.warn
                                : Theme.fg

                            text: cell === 0 ? Svc.ClaudeUsage.bucketName(modelData.key)
                                : cell === 1 ? `${Math.round(modelData.used)}%`
                                : `resets in ${Svc.ClaudeUsage.untilReset(modelData.resetsAt)}`
                            color: cell === 2 ? Theme.fgDim : tone
                            horizontalAlignment: cell === 1 ? Text.AlignRight : Text.AlignLeft
                            Layout.fillWidth: cell === 1
                            font { family: Theme.font; pixelSize: 11 }
                        }
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
