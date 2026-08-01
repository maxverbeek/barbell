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
    // about, plus the scoped ones only the API tells us about. Scoped buckets
    // are dropped once the poll stops answering — a Fable number from an hour
    // ago shown next to live 5h/7d numbers would read as equally current.
    readonly property var windows: {
        const rl = data?.rate_limits ?? {};
        const fromFile = Object.keys(rl).map(k => ({
            key: k,
            used: rl[k]?.used_percentage ?? 0,
            resetsAt: (rl[k]?.resets_at ?? 0) * 1000
        }));
        const apiFresh = now > 0 && apiSeen > 0 && now - apiSeen < 900000;
        const all = apiFresh ? fromFile.concat(scoped) : fromFile;
        return all.map(w => Object.assign({}, w, { projected: projectedAt(w) }));
    }

    // What linear burn says the bucket hits by reset. 40% used with the week
    // 80% gone projects to 50 — fine; 40% used two days in projects to 140 —
    // cooked. This is the number that makes "is that a lot?" answerable, since
    // a percentage means nothing without knowing how much window is left. At
    // the end of a window it converges to the plain used%, so it works as the
    // single risk measure.
    function projectedAt(w) {
        const len = w.key === "five_hour" ? 5 * 3600000 : 7 * 86400000;
        const elapsed = 1 - Math.max(0, w.resetsAt - now) / len;
        // A freshly reset window divides by nearly zero and screams over
        // nothing; below 5% elapsed the pace isn't information yet.
        return elapsed >= 0.05 ? w.used / elapsed : w.used;
    }

    // Per-model weekly limits (Fable, today) never appear in the statusline
    // payload — the OAuth usage endpoint is the only place that reports them.
    // The unscoped entries it also returns are the same 5h/7d numbers the file
    // already pushes on every render, so only the scoped ones are kept.
    property var scoped: []
    property double apiSeen: 0

    Timer {
        // Weekly buckets move slowly; five minutes is generous.
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetch.running = true
    }

    Process {
        id: fetch

        // The token rides in via curl's config-from-stdin rather than argv,
        // where any process could read it out of /proc/*/cmdline.
        command: ["bash", "-c",
            `token=$(jq -r '.claudeAiOauth.accessToken // empty' ~/.claude/.credentials.json 2>/dev/null); ` +
            `[ -n "$token" ] || exit 1; ` +
            `printf 'header = "Authorization: Bearer %s"\\n' "$token" | ` +
            `curl -sf -m 10 -K - -H "anthropic-beta: oauth-2025-04-20" https://api.anthropic.com/api/oauth/usage`]

        stdout: StdioCollector {
            onStreamFinished: root.ingestApi(text)
        }
    }

    function ingestApi(raw) {
        try {
            const limits = JSON.parse(raw)?.limits ?? [];
            scoped = limits
                .filter(l => l.scope)
                .map(l => ({
                    key: l.scope.model?.display_name ?? l.kind,
                    used: l.percent ?? 0,
                    resetsAt: Date.parse(l.resets_at) || 0
                }));
            apiSeen = Date.now();
        } catch (e) {
            // Failed fetch or changed shape: keep what we had; the freshness
            // window in `windows` retires it if this keeps happening.
        }
    }

    // The bucket most likely to actually stop you — highest projected, not
    // highest used. 16% of the week burned in half a day outranks a 5h window
    // at 40% that resets before it matters.
    readonly property var riskiest:
        windows.reduce((a, b) => b.projected > a.projected ? b : a,
                       ({ key: "", used: 0, projected: 0, resetsAt: 0 }))

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

    // The peek card and the widget tooltip both name buckets; one map.
    function bucketName(key) {
        return ({ five_hour: "5h", seven_day: "7d" })[key] ?? key;
    }

    // The claude menu calls this on open, so a peek shows now rather than the
    // last five-minute poll.
    function refresh() { fetch.running = true; }

    // Rounded to whole minutes; a to-the-second countdown on a quota is noise.
    function untilReset(epochMs) {
        if (epochMs <= 0 || now <= 0) return "";
        const mins = Math.round((epochMs - now) / 60000);
        if (mins <= 0) return "now";
        if (mins < 60) return `${mins}m`;
        const h = Math.floor(mins / 60);
        // Weekly windows reset days out; "125h54m" is a subtraction problem,
        // not an answer.
        if (h >= 48) return `${Math.round(h / 24)}d`;
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
