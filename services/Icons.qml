pragma Singleton
import QtQuick
import Quickshell

// App icons come from .desktop entries, same as ags' launcher does it:
// heuristicLookup matches an app_id against desktop files, then iconPath
// resolves the resulting name against the icon theme.
Singleton {
    id: root

    readonly property string fallback: "application-x-executable"

    // A handful of icons no theme here ships (zen-browser, neovim, kubernetes,
    // …). Same directory ags reads them from.
    readonly property string customDir: `${Quickshell.env("HOME")}/.config/ags/icons`
    readonly property var customIcons: ["circle-dashed", "dot", "kubernetes", "memory-stick-symbolic", "neovim", "processor-symbolic", "zen-browser"]

    // Terminal apps all share one app_id, so the title is the only clue.
    readonly property var titleRules: [
        { pattern: /nvim|neovim/i, icon: "neovim" },
        { pattern: /spotify/i, icon: "spotify-client" }
    ]

    // Claude Code prefixes the terminal title with a braille glyph while it is
    // working and with ✳ when it wants input. The title is the only marker —
    // there is no app_id to match on.
    readonly property var claudeIcons: ["claude-code", "claude-spinner-0", "claude-spinner-1", "claude-spinner-2", "claude-spinner-3", "claude-spinner-4", "claude-spinner-5"]

    // Claude renders its spinner as a braille glyph that it updates in place, so
    // the leading character of the title is what says "still working".
    readonly property var thinkingPattern: /^[⠀-⣿]/

    // One timer for the whole bar rather than one per window, and it only ticks
    // while some window is actually mid-thought — a bar that spins forever is
    // pure wakeups. Reading the window list here instead of having delegates
    // report in keeps the count honest: there's nothing to increment, nothing
    // to decrement on destruction, and no way for the two to drift apart.
    readonly property bool anyThinking:
        Object.values(Niri.windows).some(w => thinkingPattern.test(w.title ?? ""))
    readonly property int spinnerFrame: spinner.running ? spinner.frame : 0

    Timer {
        id: spinner

        property int frame: 0

        running: root.anyThinking
        interval: 150
        repeat: true
        onTriggered: frame = (frame + 1) % 6
        // Next spin starts from the beginning rather than wherever it stopped.
        onRunningChanged: if (!running) frame = 0
    }

    function claudeIcon(window) {
        const title = window?.title ?? "";
        if (thinkingPattern.test(title))
            return `claude-spinner-${spinnerFrame}`;
        // No braille means it's waiting on you rather than working.
        if (title.startsWith("✳"))
            return "claude-code";
        return "";
    }

    function custom(name) {
        if (claudeIcons.includes(name))
            return Qt.resolvedUrl(`../icons/${name}.svg`);
        return customIcons.includes(name) ? `file://${customDir}/${name}.svg` : "";
    }

    function resolve(name) {
        if (!name)
            return "";
        // `true` returns empty instead of a broken-image path, so the next
        // candidate still gets a chance.
        return custom(name) || Quickshell.iconPath(name, true);
    }

    function forWindow(window) {
        for (const rule of titleRules) {
            const hit = rule.pattern.test(window.title ?? "") && resolve(rule.icon);
            if (hit)
                return hit;
        }
        return resolve(claudeIcon(window)) || icon(window.app_id);
    }

    function icon(appId) {
        if (!appId)
            return Quickshell.iconPath(fallback);
        const entry = DesktopEntries.heuristicLookup(appId);
        return resolve(entry?.icon) || resolve(appId) || resolve(appId.toLowerCase()) || Quickshell.iconPath(fallback);
    }
}
