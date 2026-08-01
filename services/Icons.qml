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

    function custom(name) {
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
        return icon(window.app_id);
    }

    function icon(appId) {
        if (!appId)
            return Quickshell.iconPath(fallback);
        const entry = DesktopEntries.heuristicLookup(appId);
        return resolve(entry?.icon) || resolve(appId) || resolve(appId.toLowerCase()) || Quickshell.iconPath(fallback);
    }
}
