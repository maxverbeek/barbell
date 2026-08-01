import QtQuick
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
                            // The projection only earns a mention when it says
                            // something the level doesn't.
                            const proj = modelData.projected >= modelData.used + 5
                                ? `  →${Math.min(999, Math.round(modelData.projected))}%`
                                : "";
                            return `${name}  ${Math.round(modelData.used)}%${proj}  ·  resets in ${reset}`;
                        }
                        color: modelData.used >= 90 || modelData.projected >= 150 ? Theme.bad
                            : modelData.used >= 70 || modelData.projected >= 100 ? Theme.warn
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
