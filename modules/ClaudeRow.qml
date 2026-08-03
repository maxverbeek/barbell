import QtQuick
import Quickshell.Widgets
import ".."
import "../services" as Svc

// One rate-limit bucket — name, fill bar, the figures — or one Claude Code
// session window, which is just its title. The notch on a bucket's bar is
// where the window's clock stands — fill left of the notch means under pace,
// past it means on course to run out. The gap between them is the whole
// story, which is more than the two numbers say on their own.
Item {
    id: root

    required property var row
    property bool active: false
    property string heading: ""

    signal hovered()
    signal clicked()

    readonly property bool empty: row.kind === "empty"
    readonly property bool isWindow: row.kind === "window"
    readonly property var bucket: row.kind === "bucket" ? row.bucket : null

    // Same lines the bar widget draws with: on pace to run out is warn,
    // running out well before reset (or nearly full) is bad.
    readonly property color tone: !bucket ? Theme.fgFaint
        : bucket.used >= 90 || bucket.projected >= 150 ? Theme.bad
        : bucket.used >= 70 || bucket.projected >= 100 ? Theme.warn
        : Theme.accent

    implicitHeight: (heading !== "" ? label.implicitHeight + 8 : 0) + 28

    Text {
        id: label
        visible: root.heading !== ""
        text: root.heading
        color: Theme.fgFaint
        font { family: Theme.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 0.6 }
        anchors { left: parent.left; leftMargin: 6; top: parent.top; topMargin: 3 }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 28
        radius: 6
        color: root.active ? Theme.islandActive : "transparent"

        // The same mark the bar draws: the spinner frames while the session is
        // working, the plain logo while it waits on you. Two states one glyph
        // can't tell apart — ✳ animates too, so a still logo is the only way
        // "idle" reads as idle at a glance.
        IconImage {
            id: glyph
            visible: root.isWindow
            source: root.isWindow ? Svc.Icons.resolve(Svc.Icons.claudeIcon(root.row.win)) : ""
            implicitSize: 14
            opacity: root.row.busy ? 1 : 0.55
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
        }

        Text {
            id: name
            text: root.empty ? "no data"
                : root.isWindow ? root.row.title
                : Svc.ClaudeUsage.bucketName(root.bucket.key)
            color: root.empty ? Theme.fgFaint : Theme.fg
            font { family: Theme.font; pixelSize: 12 }
            // A session row is all title, a bucket row leaves room for the bar.
            width: root.isWindow ? parent.width - 28 : 48
            elide: Text.ElideRight
            anchors {
                left: root.isWindow ? glyph.right : parent.left
                leftMargin: 6
                verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            id: track
            visible: root.bucket !== null
            anchors { left: name.right; right: figures.left; rightMargin: 10
                      verticalCenter: parent.verticalCenter }
            height: 4
            radius: 2
            color: Theme.track

            Rectangle {
                width: parent.width * Math.min(1, (root.bucket?.used ?? 0) / 100)
                height: parent.height
                radius: parent.radius
                color: root.tone
            }

            Rectangle {
                visible: root.bucket && root.bucket.projected !== root.bucket.used
                x: parent.width * Math.min(1,
                       (root.bucket?.used ?? 0) / Math.max(1, root.bucket?.projected ?? 1))
                   - width / 2
                width: 2
                height: 8
                radius: 1
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fgFaint
            }
        }

        Text {
            id: figures
            text: !root.bucket ? ""
                : `${Math.round(root.bucket.used)}%  ·  ${Svc.ClaudeUsage.untilReset(root.bucket.resetsAt)}`
            color: root.tone === Theme.accent ? Theme.fgDim : root.tone
            font { family: Theme.font; pixelSize: 11 }
            // Fixed width, right-aligned: "3h12m" and "5d" are different sizes,
            // and natural width would let each row's countdown decide where the
            // track ends — bars that stop in three different places.
            width: 84
            horizontalAlignment: Text.AlignRight
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.empty
            onEntered: root.hovered()
            onClicked: root.clicked()
        }
    }
}
