pragma Singleton
import QtQuick
import Quickshell

// Catppuccin Mocha, same palette as ~/.config/ags/styles/_variables.scss.
Singleton {
    readonly property int barHeight: 32
    // Sit at the bottom while ags still owns the top edge.
    readonly property bool bottom: true

    readonly property color barBg: "#e61e1e2e"
    readonly property color menuBg: "#181825"
    readonly property color itemBg: "#cc2a2a3a"
    readonly property color itemHover: "#363650"
    readonly property color itemActive: "#494964"

    readonly property color fg: "#cdd6f4"
    readonly property color fgDim: "#a6adc8"
    readonly property color accent: "#89b4fa"
    readonly property color red: "#f38ba8"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"

    readonly property string font: "Inter"
}
