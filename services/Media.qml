pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Whatever is playing, if anything. Native MPRIS — no playerctl subprocess.
Singleton {
    id: root

    readonly property var players: Mpris.players?.values ?? []

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

    // Some players report a title and nothing else; some report neither and
    // are only technically playing. Nothing to say means nothing to show.
    readonly property bool active: playing && title !== ""

    function toggle() { if (player?.canTogglePlaying) player.togglePlaying(); }
    function next() { if (player?.canGoNext) player.next(); }
    function previous() { if (player?.canGoPrevious) player.previous(); }
    function raise() { if (player?.canRaise) player.raise(); }
}
