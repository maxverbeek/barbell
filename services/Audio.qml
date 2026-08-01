pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Native Pipewire bindings — no pw-mon, no wpctl, no subprocess debouncing.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool sinkMuted: sink?.audio?.muted ?? false
    readonly property real sinkVolume: sink?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0

    // Bluetooth sinks report device.api = "bluez5"; alsa ones say "alsa".
    readonly property bool sinkIsBluetooth: (sink?.properties?.["device.api"] ?? "") === "bluez5"

    // Something is capturing if anything is linked to the default source.
    // This is what makes "your mic is live" possible without polling.
    readonly property bool micInUse: micLinks.linkGroups.length > 0

    // Binding to a node's properties requires tracking it, otherwise the
    // fields stay unpopulated.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }

    PwNodeLinkTracker {
        id: micLinks
        node: root.source
    }

    function setSinkVolume(v) { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v)); }
    function setMicVolume(v) { if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, v)); }
    function toggleSinkMute() { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }
    function toggleMicMute() { if (source?.audio) source.audio.muted = !source.audio.muted; }
}
