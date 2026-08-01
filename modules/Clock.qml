import QtQuick
import Quickshell
import ".."

Text {
    // SystemClock ticks the binding for us — no timer, no polling.
    SystemClock { id: clock; precision: SystemClock.Minutes }

    text: Qt.formatDateTime(clock.date, "ddd d MMM • HH:mm")
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: 13
}
