pragma Singleton
import QtQuick
import Quickshell

// App icons come from .desktop entries, same as ags' launcher does it:
// heuristicLookup matches an app_id against desktop files, then iconPath
// resolves the resulting name against the icon theme.
Singleton {
    id: root

    readonly property string fallback: "application-x-executable"

    // One entry per agent kind herdr can report: its resting mark and how many
    // spinner frames it has. The frames are the glyphs the agent itself cycles
    // in its terminal, rendered by icons/gen-spinner.py, so a working agent in
    // the bar looks like the working agent in its pane. Adding a kind is one
    // line here plus a run of the generator.
    readonly property var agents: ({
        claude: { icon: "claude-code", frames: 6 },
        codex: { icon: "codex", frames: 10 }
    })

    // Icons no theme here ships, bundled so they come from the store path
    // rather than anything in $HOME. The agent marks and frames are among them.
    readonly property var customIcons: ["kubernetes", "neovim", "zen-browser", "md.Obsidian"]

    function bundled(name) {
        return customIcons.includes(name)
            || Object.entries(agents).some(([kind, a]) => name === a.icon || name.startsWith(`${kind}-spinner-`));
    }

    // Terminal apps all share one app_id, so the title is the only clue — but
    // only inside a terminal. A browser tab named "…/nvim/init.lua" is not nvim.
    readonly property var terminalAppIds: ["foot"]

    readonly property var titleRules: [
        { pattern: /nvim|neovim/i, icon: "neovim" },
        { pattern: /spotify/i, icon: "spotify-client" }
    ]

    // Claude Code prefixes the terminal title with a spinner glyph while it is
    // working and with ✳ when it wants input — the title is the only marker,
    // there is no app_id to match on. It updates the glyph in place, so the
    // leading character is what says "still working". The spinner set has
    // changed across versions: braille frames (⠀-⣿) and circle frames (◐◑◒◓).
    readonly property var thinkingPattern: /^[⠀-⣿◐-◓]/

    // One timer for the whole bar rather than one per window, and it only ticks
    // while some window is actually mid-thought — a bar that spins forever is
    // pure wakeups. Reading the window list here instead of having delegates
    // report in keeps the count honest: there's nothing to increment, nothing
    // to decrement on destruction, and no way for the two to drift apart.
    readonly property bool anyThinking:
        Object.values(Niri.windows).some(w => isTerminal(w) && thinkingPattern.test(w.title ?? ""))
        || Herdr.agents.some(a => a.agent_status === "working")
    readonly property int spinnerFrame: spinner.running ? spinner.frame : 0

    Timer {
        id: spinner

        property int frame: 0

        running: root.anyThinking
        interval: 150
        repeat: true
        // One tick for every kind; each takes it modulo its own frame count,
        // so the period only has to be a multiple of all of them.
        onTriggered: frame = (frame + 1) % 30
        // Next spin starts from the beginning rather than wherever it stopped.
        onRunningChanged: if (!running) frame = 0
    }

    // The mark for an agent of `kind` in herdr's status vocabulary: the spinner
    // frame while working, the resting mark otherwise. A kind without a table
    // entry still gets a terminal icon, so state shows before anyone draws it.
    function agentIcon(kind, status) {
        const a = agents[kind];
        if (!a)
            return "utilities-terminal";
        return status === "working" ? `${kind}-spinner-${spinnerFrame % a.frames}` : a.icon;
    }

    // Whether this window is a Claude Code session at all — working or
    // waiting. The title markers are the only signal there is.
    function isTerminal(window) {
        return terminalAppIds.includes(window?.app_id ?? "");
    }

    function isClaude(window) {
        const title = isTerminal(window) ? window.title ?? "" : "";
        return thinkingPattern.test(title) || title.startsWith("✳");
    }

    function claudeIcon(window) {
        const title = isTerminal(window) ? window.title ?? "" : "";
        if (thinkingPattern.test(title))
            return agentIcon("claude", "working");
        // No spinner means it's waiting on you rather than working.
        if (title.startsWith("✳"))
            return agentIcon("claude", "idle");
        return "";
    }

    function custom(name) {
        return bundled(name) ? Qt.resolvedUrl(`../icons/${name}.svg`) : "";
    }

    function resolve(name) {
        if (!name)
            return "";
        // `true` returns empty instead of a broken-image path, so the next
        // candidate still gets a chance.
        return custom(name) || Quickshell.iconPath(name, true);
    }

    function forWindow(window) {
        if (isTerminal(window)) {
            for (const rule of titleRules) {
                const hit = rule.pattern.test(window.title ?? "") && resolve(rule.icon);
                if (hit)
                    return hit;
            }
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
