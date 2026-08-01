pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Claude Code's rate-limit state, which exists nowhere on disk on its own — no
// API to ask, and the session transcripts don't record it. The only place it
// surfaces is the JSON blob handed to the statusline command on every render,
// so ~/.claude/hooks/usage-dump.sh tees that blob here and this watches it.
//
// Consequence worth remembering: this is only as fresh as the last statusline
// render. With no Claude running the file just sits there, so `stale` is part
// of the contract rather than an error case — a quota number from yesterday
// looks exactly like a current one, and that's the way to read it wrong.
Singleton {
    id: root

    readonly property string path: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/claude-usage.json`

    property var data: ({})

    readonly property real fiveHour: pct("five_hour")
    readonly property real sevenDay: pct("seven_day")
    readonly property double fiveHourReset: reset("five_hour")
    readonly property double sevenDayReset: reset("seven_day")

    readonly property string model: data?.model?.display_name ?? ""
    readonly property real cost: data?.cost?.total_cost_usd ?? 0

    // Whether we have anything at all. An empty file and a missing one are the
    // same thing to a reader.
    readonly property bool known: data?.rate_limits !== undefined

    function pct(window) {
        return data?.rate_limits?.[window]?.used_percentage ?? 0;
    }

    function reset(window) {
        return (data?.rate_limits?.[window]?.resets_at ?? 0) * 1000;
    }

    // Whatever buckets the payload actually reports, rather than the two we know
    // about — if a Fable session adds its own, it shows up here without a change.
    readonly property var windows: {
        const rl = data?.rate_limits ?? {};
        return Object.keys(rl).map(k => ({
            key: k,
            used: rl[k]?.used_percentage ?? 0,
            resetsAt: (rl[k]?.resets_at ?? 0) * 1000
        }));
    }

    // The fullest bucket is what actually constrains you, and it's the number
    // worth a glance — being at 80% of the week matters whether or not this
    // particular 5h block is fresh.
    readonly property real worst:
        windows.reduce((m, w) => Math.max(m, w.used), 0)

    // Ticks so the countdown and the staleness check stay honest without every
    // reader running its own timer. A minute is plenty for a 5-hour window.
    property double now: 0
    Timer {
        running: true
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    // No statusline render in a while means nothing is driving the file. Ten
    // minutes is longer than any gap between renders in a live session and
    // short enough that a closed laptop shows as stale rather than as truth.
    readonly property bool stale: !known || (now > 0 && lastSeen > 0 && now - lastSeen > 600000)
    property double lastSeen: 0

    // Rounded to whole minutes; a to-the-second countdown on a quota is noise.
    function untilReset(epochMs) {
        if (epochMs <= 0 || now <= 0) return "";
        const mins = Math.round((epochMs - now) / 60000);
        if (mins <= 0) return "now";
        if (mins < 60) return `${mins}m`;
        const h = Math.floor(mins / 60);
        return mins % 60 === 0 ? `${h}h` : `${h}h${mins % 60}m`;
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        // Missing file is the normal state before the first render, not a fault.
        printErrors: false
        // Without this the first read waits for a write, so a bar started
        // between renders shows nothing despite a perfectly good file on disk.
        blockLoading: true

        onFileChanged: reload()
        // Qualified: an unqualified text() would resolve against the singleton.
        onLoaded: root.ingest(file.text())
        onLoadFailed: root.data = ({})
    }

    function ingest(raw) {
        try {
            const parsed = JSON.parse(raw);
            data = parsed;
            // The file's own mtime would be better, but FileView doesn't expose
            // it; a write is what woke us, so now is close enough.
            lastSeen = Date.now();
            if (now === 0) now = lastSeen;
        } catch (e) {
            // A half-written file would throw, but the hook renames into place
            // atomically, so this really means the payload shape changed.
            data = ({});
        }
    }
}
