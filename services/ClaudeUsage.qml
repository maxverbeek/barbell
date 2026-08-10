pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Claude Code's rate-limit state, from the OAuth usage endpoint. It reports
// every bucket — the 5h session window, the weekly all-models window, and the
// scoped (Fable) weekly that never appears anywhere else — so one poll is the
// whole picture, live session or not. The statusline-dump file this used to
// watch is gone: it was only as fresh as the last render, which made a closed
// laptop indistinguishable from a live quota.
//
// Freshness is still part of the contract: a poll that stops answering (no
// network, expired token) leaves numbers that look current. `stale` flips
// after three missed polls; readers grey out rather than lie.
Singleton {
    id: root

    // All buckets the endpoint reports, oldest shape first: session (5h),
    // weekly_all (7d), then scoped ones keyed by their model display name.
    property var buckets: []
    property double apiSeen: 0

    readonly property bool known: apiSeen > 0
    readonly property bool stale: !known || (now > 0 && now - apiSeen > 900000)

    readonly property var windows:
        buckets.map(w => Object.assign({}, w, { projected: projectedAt(w) }))

    // What linear burn says the bucket hits by reset. 40% used with the week
    // 80% gone projects to 50 — fine; 40% used two days in projects to 140 —
    // cooked. This is the number that makes "is that a lot?" answerable, since
    // a percentage means nothing without knowing how much window is left. At
    // the end of a window it converges to the plain used%, so it works as the
    // single risk measure.
    function projectedAt(w) {
        const len = w.group === "session" ? 5 * 3600000 : 7 * 86400000;
        const elapsed = 1 - Math.max(0, w.resetsAt - now) / len;
        // A freshly reset window divides by nearly zero and screams over
        // nothing; below 5% elapsed the pace isn't information yet.
        return elapsed >= 0.05 ? w.used / elapsed : w.used;
    }

    Timer {
        // Weekly buckets move slowly; five minutes is generous.
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: fetch

        // The token rides in via curl's config-from-stdin rather than argv,
        // where any process could read it out of /proc/*/cmdline.
        //
        // The response is also teed to claude-usage-limits.json so the Claude
        // Code statusline can read the buckets without polling the endpoint
        // itself. Two independent pollers on this endpoint is how you earn a
        // 429 — see the throttle note on refresh(). Only a real limits array
        // is written, so an error body never replaces good cached data.
        command: ["bash", "-c",
            `token=$(jq -r '.claudeAiOauth.accessToken // empty' ~/.claude/.credentials.json 2>/dev/null); ` +
            `[ -n "$token" ] || exit 1; ` +
            `body=$(printf 'header = "Authorization: Bearer %s"\\n' "$token" | ` +
            `curl -sf -m 10 -K - -H "anthropic-beta: oauth-2025-04-20" https://api.anthropic.com/api/oauth/usage); ` +
            `printf '%s' "$body" | jq -e '.limits | arrays' >/dev/null 2>&1 && ` +
            `printf '%s' "$body" > "\${XDG_RUNTIME_DIR:-/tmp}/claude-usage-limits.json"; ` +
            `printf '%s' "$body"`]

        stdout: StdioCollector {
            onStreamFinished: root.ingestApi(text)
        }
    }

    function ingestApi(raw) {
        try {
            const limits = JSON.parse(raw)?.limits;
            // An error response is valid JSON too — a 429 body parses fine and
            // has no limits array. Treating it as data would replace the
            // buckets with nothing and stamp the nothing as fresh; only a real
            // limits array counts, anything else keeps what we had and lets
            // the freshness window retire it honestly.
            if (!Array.isArray(limits)) return;
            buckets = limits.map(l => ({
                key: l.scope ? (l.scope.model?.display_name ?? l.kind) : l.kind,
                group: l.group ?? "weekly",
                used: l.percent ?? 0,
                resetsAt: Date.parse(l.resets_at) || 0
            }));
            apiSeen = Date.now();
        } catch (e) {
            // Failed fetch or changed shape: keep what we had.
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

    // The peek card and the widget tooltip both name buckets; one map.
    function bucketName(key) {
        return ({ session: "5h", weekly_all: "7d" })[key] ?? key;
    }

    // The claude menu calls this on open, so a peek shows now rather than the
    // last five-minute poll. Throttled: the usage endpoint 429s under
    // enthusiasm (a day of bar restarts and menu opens earned a block), and a
    // menu reopened three times in a minute doesn't need three fetches.
    property double lastAttempt: 0
    function refresh() {
        if (Date.now() - lastAttempt < 60000) return;
        lastAttempt = Date.now();
        fetch.running = true;
    }

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
}
