import QtQuick
import Quickshell.Widgets
import ".."
import "../services"

// Which cluster kubectl would talk to. Always drawn when a context is set:
// this is the one indicator whose whole job is stopping a command going to the
// wrong place, so "quiet when boring" doesn't apply — a context you forgot
// you were on is exactly the dangerous case.
//
// Production is the exception worth colour. Everything else reads as neutral.
Row {
    id: root
    spacing: 5

    visible: Kube.context !== ""

    IconImage {
        source: Icons.custom("kubernetes")
        implicitSize: 14
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: Kube.context
        color: Kube.production ? Theme.bad : Theme.fgDim
        font {
            family: Theme.font
            pixelSize: 12
            weight: Kube.production ? Font.DemiBold : Font.Normal
        }
        anchors.verticalCenter: parent.verticalCenter
    }
}
