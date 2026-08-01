pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Whatever is playing, if anything. Native MPRIS — no playerctl subprocess.
Singleton {
    id: root

    // playerctld mirrors whichever player was last active under its own MPRIS
    // name, so with it running every player shows up twice — once as itself,
    // once through the mirror, same identity and same track. Drop the mirror:
    // the real players are all here anyway.
    readonly property var players: (Mpris.players?.values ?? [])
        .filter(p => !p.dbusName?.endsWith(".playerctld"))

    // The player to show. Something actually playing wins over something
    // merely open, so starting a video in a browser takes over from a paused
    // Spotify rather than being ignored.
    readonly property var player: {
        const ps = players.filter(p => p.canControl);
        return ps.find(p => p.isPlaying) ?? ps.find(p => p.playbackState === MprisPlaybackState.Paused) ?? null;
    }

    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property string app: player?.identity ?? ""

    // Paused still counts. Requiring `playing` here meant hitting pause deleted
    // the widget out from under the pointer that pressed it, with no way back
    // short of finding the app — and a paused track is still worth a glance.
    // `player` already prefers a playing source, so this can't let a paused
    // player elbow out one that's actually going.
    //
    // Some players report a title and nothing else; some report neither and are
    // only technically playing. Nothing to say means nothing to show.
    readonly property bool active: player !== null && title !== ""

    // The niri window a player lives in, for focusing it. MPRIS doesn't carry
    // a window handle, so this is matching: desktopEntry against app_id gets
    // the real apps, and for browsers — whose app_id says nothing about what's
    // playing — the track title in the window title is the giveaway, since
    // that's what they put there while something plays.
    function windowFor(p) {
        if (!p) return null;
        const wins = Object.values(Niri.windows);
        const entry = (p.desktopEntry || p.identity || "").toLowerCase();
        if (entry !== "") {
            const byApp = wins.find(w =>
                (w.app_id ?? "").toLowerCase().startsWith(entry));
            if (byApp) return byApp;
        }
        const title = p.trackTitle ?? "";
        // Short titles match everything; require enough to mean something.
        if (title.length >= 5)
            return wins.find(w => (w.title ?? "").includes(title)) ?? null;
        return null;
    }

    function toggle() { if (player?.canTogglePlaying) player.togglePlaying(); }
    function next() { if (player?.canGoNext) player.next(); }
    function previous() { if (player?.canGoPrevious) player.previous(); }
    function raise() { if (player?.canRaise) player.raise(); }
}
