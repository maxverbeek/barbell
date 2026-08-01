import QtQuick
import ".."
import "../services" as Svc

// CPU / memory past an interrupt-worthy threshold, per the interest rules:
// normal load is the boring case and draws nothing. When a number appears it
// is the number — the answer to "how bad" without opening btop.
//
// Appears at 80/85, hides again below 70/75: without the gap a machine
// hovering at the threshold would blink the widget every poll.
// ponytail: 80/85 are the guesses from DECISIONS.md, tune when they cry wolf.
Row {
    id: root
    spacing: 8
    visible: cpuHot || memHot

    property bool cpuHot: false
    property bool memHot: false

    readonly property real cpu: Svc.Sysmon.cpu
    readonly property real mem: Svc.Sysmon.mem
    onCpuChanged: cpuHot = cpu >= (cpuHot ? 70 : 80)
    onMemChanged: memHot = mem >= (memHot ? 75 : 85)

    Text {
        visible: root.cpuHot
        text: `cpu ${Math.round(root.cpu)}%`
        color: root.cpu >= 95 ? Theme.bad : Theme.warn
        font { family: Theme.font; pixelSize: 13 }
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        visible: root.memHot
        text: `mem ${Math.round(root.mem)}%`
        color: root.mem >= 95 ? Theme.bad : Theme.warn
        font { family: Theme.font; pixelSize: 13 }
        anchors.verticalCenter: parent.verticalCenter
    }
}
