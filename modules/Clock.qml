import QtQuick
import Quickshell
import ".."

// Date and time. Split so the time can carry more weight than the date —
// the time is what you glance at, the date is context.
Row {
    // SystemClock ticks the bindings for us — no timer, no polling.
    SystemClock { id: clock; precision: SystemClock.Minutes }

    spacing: 6

    Text {
        text: Qt.formatDateTime(clock.date, "ddd d MMM •")
        color: Theme.fgDim
        font { family: Theme.font; pixelSize: 13 }
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.fg
        font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
        anchors.verticalCenter: parent.verticalCenter
    }
}
