pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Kanagawa Wave (dark), and Kanagawa Lotus accents on Catppuccin Latte
// surfaces (light).
//
// The values below are the DEFAULTS and the fallback: the bar renders
// correctly with no external input, so `quickshell -p .` on a bare checkout
// still looks right. Nothing here requires nixconfig.
//
// When nixconfig is driving, theme-toggle writes $XDG_RUNTIME_DIR/theme.json
// ({"variant":"light"|"dark"}) and the bar follows it live. A missing or
// unparseable file means "dark", which is what the constants below already
// spell out — so the two paths agree by construction.
//
// Palette source of truth is nixconfig's
// modules/packages/_definitions/vimPlugins/kanagawa-nvim.nix. Still mirrored
// by hand; only the ~20 semantic colours below need to agree, not the whole
// palette.
Singleton {
    id: root

    readonly property int barHeight: 34
    // The top edge is home now that ags is retired; flip for bottom-bar life.
    // Everything respects this — menus drop from the right edge, OSD and
    // notifications keep clear of it.
    readonly property bool bottom: false

    // --- variant ---------------------------------------------------------
    // "dark" | "light". Set from theme.json when present.
    property string variant: "dark"
    readonly property bool isLight: variant === "light"

    FileView {
        id: themeFile
        path: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/theme.json`
        watchChanges: true
        // No file is the normal standalone case, not a fault.
        printErrors: false
        // Without this the first read waits for a write, so a bar started
        // before the first toggle would ignore an existing file.
        blockLoading: true

        onFileChanged: reload()
        onLoaded: {
            try {
                const v = JSON.parse(themeFile.text()).variant;
                root.variant = (v === "light" || v === "dark") ? v : "dark";
            } catch (e) {
                // Half-written or wrong shape — keep whatever we had.
            }
        }
        onLoadFailed: root.variant = "dark"
    }

    // --- surfaces --------------------------------------------------------
    // Named by ROLE, not by palette slot, because the two variants don't
    // agree on direction: dark recedes toward black, light rises toward
    // white. A literal Lotus transcription put the menu *below* the bar and
    // the whole thing collapsed into one yellow — surfaces need a lightness
    // ramp, and Lotus's own ramp (#f2ecbc/#e7dba0/#d5cea3) barely has one.
    //
    // Light surfaces are Catppuccin Latte, matching the GTK theme, so the bar
    // sits next to GTK apps instead of being a lone yellow panel. Accents
    // below stay Kanagawa Lotus.
    //
    // deep < base < raised: menus float ABOVE the bar in light mode, and sink
    // below it in dark. Same ordering by name, opposite by hex.
    readonly property color base: isLight ? "#e6e9ef" : "#1f1f28"   // the bar
    readonly property color raised: isLight ? "#eff1f5" : "#16161d" // menus, popups
    readonly property color deep: isLight ? "#dce0e8" : "#363646"   // hover, islands
    readonly property color line: isLight ? "#bcc0cc" : "#54546d"   // borders, tracks
    readonly property color selected: isLight ? "#acb0be" : "#2d4f67"

    // --- accents ---------------------------------------------------------
    // Kanagawa Lotus in light, Kanagawa Wave in dark. These read well on
    // Latte surfaces, so only the surfaces changed.
    readonly property color crystalBlue: isLight ? "#4d699b" : "#7e9cd8"
    readonly property color springGreen: isLight ? "#6f894e" : "#98bb6c"
    readonly property color autumnGreen: isLight ? "#6e915f" : "#76946a"
    // Lotus's yellows (#836f4a / #77713f) are desaturated olive: on Latte
    // surfaces they read as grey-brown, i.e. as no warning at all. Latte's own
    // peach carries the "orange" signal, and its darker sibling stays out of
    // the light digits' luminance range.
    readonly property color carpYellow: isLight ? "#fe640b" : "#e6c384"
    readonly property color boatYellow2: isLight ? "#c4600a" : "#c0a36e"
    readonly property color autumnRed: isLight ? "#c84053" : "#c34043"
    readonly property color peachRed: isLight ? "#d7474b" : "#ff5d62"

    // --- semantic --------------------------------------------------------
    readonly property color bg0: base
    readonly property color barBg: Qt.rgba(base.r, base.g, base.b, 0.92)
    readonly property color menuBg: raised
    readonly property color island: Qt.rgba(deep.r, deep.g, deep.b, isLight ? 0.75 : 0.55)
    readonly property color islandHover: deep
    readonly property color islandActive: selected

    // Borders and dividers. `line` in both variants: a border is the same job
    // either way, it just has to sit a step away from its surface.
    readonly property color border: line
    readonly property color track: line

    // Dimmer siblings of good/bad/warn, for fills that sit under light text.
    readonly property color goodDim: autumnGreen
    readonly property color badDim: autumnRed
    readonly property color warnDim: boatYellow2

    // Text on top of a coloured fill (battery bolt). The fills are mid-tone in
    // both variants, so this stays light rather than following the background
    // — on Latte, background-coloured text on a green fill is unreadable.
    readonly property color onFill: isLight ? "#eff1f5" : base

    // Dark text is Catppuccin Mocha, not Kanagawa. fujiWhite is a warm cream
    // that reads yellow next to the cool near-white the old bar used, and eyes
    // calibrated by years of #cdd6f4 see "off", not "warm". Backgrounds and
    // accents stay Kanagawa — the two darks are near-identical, so the seam
    // doesn't show.
    //
    // Light text is Latte's own inks, to match the surfaces. Lotus's greys
    // (#8a8980) washed out on them — section labels have to stay readable,
    // so fgFaint is a real step darker than the Lotus equivalent.
    readonly property color fg: isLight ? "#4c4f69" : "#cdd6f4"
    readonly property color fgDim: isLight ? "#5c5f77" : "#a6adc8"
    readonly property color fgFaint: isLight ? "#7c7f93" : "#6c7086"

    readonly property color accent: crystalBlue   // focus, interaction, bluetooth
    readonly property color good: springGreen     // active and working
    readonly property color warn: carpYellow      // wants attention
    readonly property color bad: peachRed         // changed or critical
    readonly property color off: isLight ? "#8c8fa1" : "#6c7086"  // you turned it off — cool, like the text

    readonly property string font: "Inter"
    readonly property string iconFont: "JetBrainsMono Nerd Font"
}
