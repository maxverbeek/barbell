pragma Singleton
import QtQuick
import Quickshell

// Kanagawa Wave — the same palette as nvim, foot and rofi.
//
// Source of truth is ~/nixconfig/modules/packages/_definitions/vimPlugins/
// kanagawa-nvim.nix (passthru.colors.term). Mirrored here by hand; if the bar
// is ever built through that flake, generate this file from it instead.
Singleton {
    readonly property int barHeight: 32
    // Sit at the bottom while ags still owns the top edge.
    readonly property bool bottom: true

    // --- raw palette ---------------------------------------------------
    readonly property color sumiInk: "#1f1f28"   // background
    readonly property color sumiInk0: "#16161d"  // darker
    readonly property color sumiInk3: "#363646"  // elevated
    readonly property color sumiInk4: "#54546d"  // borders
    readonly property color waveBlue1: "#223249" // hover
    readonly property color waveBlue2: "#2d4f67" // selection / active

    readonly property color fujiWhite: "#dcd7ba" // primary text
    readonly property color oldWhite: "#c8c093"  // secondary text
    readonly property color fujiGray: "#727169"  // dimmed text

    readonly property color crystalBlue: "#7e9cd8"
    readonly property color springBlue: "#7fb4ca"
    readonly property color springGreen: "#98bb6c"
    readonly property color autumnGreen: "#76946a"
    readonly property color carpYellow: "#e6c384"
    readonly property color boatYellow2: "#c0a36e"
    readonly property color autumnRed: "#c34043"
    readonly property color samuraiRed: "#e82424"
    readonly property color peachRed: "#ff5d62"
    readonly property color surimiOrange: "#ffa066"
    readonly property color oniViolet: "#957fb8"
    readonly property color waveAqua2: "#7aa89f"

    // --- semantic ------------------------------------------------------
    readonly property color bg0: sumiInk
    readonly property color barBg: Qt.rgba(sumiInk.r, sumiInk.g, sumiInk.b, 0.92)
    readonly property color menuBg: sumiInk0
    readonly property color island: Qt.rgba(sumiInk3.r, sumiInk3.g, sumiInk3.b, 0.55)
    readonly property color islandHover: sumiInk3
    readonly property color islandActive: waveBlue2

    // Text is Catppuccin Mocha, not Kanagawa. fujiWhite is a warm cream that
    // reads yellow next to the cool near-white the old bar used, and eyes
    // calibrated by years of #cdd6f4 see "off", not "warm". Backgrounds and
    // accents stay Kanagawa — the two darks are near-identical, so the seam
    // doesn't show.
    readonly property color fg: "#cdd6f4"
    readonly property color fgDim: "#a6adc8"
    readonly property color fgFaint: "#6c7086"

    readonly property color accent: crystalBlue   // focus, interaction, bluetooth
    readonly property color good: springGreen     // active and working
    readonly property color warn: carpYellow      // wants attention
    readonly property color bad: peachRed         // changed or critical
    readonly property color off: "#6c7086"        // you turned it off — cool, like the text

    readonly property string font: "Inter"
    readonly property string iconFont: "JetBrainsMono Nerd Font"
}
