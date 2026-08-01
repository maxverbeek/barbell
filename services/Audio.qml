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

    // Every real output and input, for the device switcher. Filtering on the
    // node type rather than on `audio` — that stays null until the object is
    // tracked, and the tracker below is fed from these lists, so testing it
    // here would leave both permanently empty.
    readonly property var sinks: (Pipewire.nodes?.values ?? [])
        .filter(n => !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
        .sort(byLikelihood)
    readonly property var sources: (Pipewire.nodes?.values ?? [])
        .filter(n => !n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource)
        .sort(byLikelihood)

    // Pipewire lists every HDMI port whether or not a monitor is plugged in,
    // and the availability flag lives on the ALSA card profile, which isn't
    // exposed here. So rather than filter them out, sink them: headphones and
    // speakers first, dead display ports last. The list stays honest — every
    // device is still reachable — but the top of it is the useful part.
    function rank(node) {
        if (node === sink || node === source) return 0;      // current, always first
        const api = node?.properties?.["device.api"] ?? "";
        if (api === "bluez5") return 1;                      // headphones you just paired
        if (/hdmi|displayport/i.test(label(node))) return 3;  // usually nothing attached
        return 2;
    }

    function byLikelihood(a, b) {
        const d = rank(a) - rank(b);
        return d !== 0 ? d : label(a).localeCompare(label(b));
    }

    // What to call a device in a list. description is the human-readable one
    // ("Philips S7505"); name is the pipewire id, a last resort.
    //
    // Onboard audio is named after the silicon — "Raptor Lake-P/U/H cAVS
    // Speaker" — which says nothing at a glance and pushes the part that does
    // ("Speaker") off the end of a narrow menu. Strip the chipset.
    function label(node) {
        const raw = node?.description || node?.nickname || node?.name || "";
        return raw.replace(/^.*\bcAVS\s+/, "")
                  .replace(/\s*\(V4L2\)$/, "");
    }

    // Switching default device. Pipewire moves existing streams itself.
    function setSink(node) { if (node) Pipewire.preferredDefaultAudioSink = node; }
    function setSource(node) { if (node) Pipewire.preferredDefaultAudioSource = node; }

    // Binding to a node's properties requires tracking it, otherwise the
    // fields stay unpopulated. The switcher needs every device populated, not
    // just the active pair, or the list comes up blank until you select one.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
            .concat(root.sinks).concat(root.sources)
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
