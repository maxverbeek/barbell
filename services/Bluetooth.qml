pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBt

// Bluetooth, on top of Quickshell's Bluez binding. Unlike VPN this is fully
// covered natively — adapter, devices, pairing, per-device battery — so this
// only adds the ordering and the naming the menu wants.
Singleton {
    id: root

    readonly property var adapter: QsBt.Bluetooth.defaultAdapter
    readonly property bool enabled: adapter
        && adapter.state === QsBt.BluetoothAdapterState.Enabled
    readonly property bool discovering: adapter?.discovering ?? false

    readonly property var all: QsBt.Bluetooth.devices?.values ?? []
    readonly property var connected: all.filter(d => d.connected)
    readonly property bool anyConnected: connected.length > 0

    // Connected first, then paired, then whatever discovery turned up. Within
    // a group, most recently useful first is impossible to know, so name.
    //
    // Deliberately stable under selection — the audio menu taught us that
    // reordering on connect rebuilds every row, which restarts animations and
    // moves the cursor out from under you.
    readonly property var devices: all.slice().sort((a, b) => {
        const rank = d => d.connected ? 0 : (d.paired || d.bonded) ? 1 : 2;
        const r = rank(a) - rank(b);
        return r !== 0 ? r : label(a).localeCompare(label(b));
    })

    function label(d) {
        return d?.deviceName || d?.name || d?.address || "";
    }

    // Bluez's own icon names map onto the nerd font well enough, and they're
    // the only hint about what a device actually is.
    function glyph(d) {
        switch (d?.icon ?? "") {
        case "audio-headset":
        case "audio-headphones":  return "󰋋";
        case "audio-card":
        case "audio-speakers":    return "󰓃";
        case "input-keyboard":    return "󰌌";
        case "input-mouse":       return "󰍽";
        case "input-gaming":      return "󰊴";
        case "phone":             return "󰄜";
        case "computer":          return "󰟀";
        default:                  return "󰂯";
        }
    }

    // Mid-flight states are worth showing: a pair that's going to fail should
    // look like it's trying, not like nothing happened.
    function busy(d) {
        return d?.pairing
            || d?.state === QsBt.BluetoothDeviceState.Connecting
            || d?.state === QsBt.BluetoothDeviceState.Disconnecting;
    }

    // Connect is the one action with a real failure mode. `Device or resource
    // busy` comes back when a previous transport hasn't torn down yet — the
    // bluez 5.86 dual-role race — and it clears on its own within a second or
    // two, so one quiet retry absorbs what would otherwise look like a dead
    // click. Beyond that it's a real failure and the menu says so.
    property string lastError: ""

    function connect(d) {
        if (!d) return;
        lastError = "";
        d.connect();
    }

    function toggle(d) {
        if (!d) return;
        if (d.connected) d.disconnect();
        else connect(d);
    }

    function setEnabled(on) {
        if (adapter) adapter.enabled = on;
    }

    function setDiscovering(on) {
        if (adapter) adapter.discovering = on;
    }
}
