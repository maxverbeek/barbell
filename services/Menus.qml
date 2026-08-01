pragma Singleton
import QtQuick
import Quickshell

// Which menu is open, if any. A singleton because two things open menus and
// they must not disagree: clicking the speaker on the bar, and the niri
// keybind coming in over `qs ipc`.
//
// Only one menu is ever open — opening another closes the first, which is
// what you'd expect and saves every menu having to know about the others.
Singleton {
    id: root

    // "" means nothing is open.
    property string current: ""

    function open(name) { current = name; }
    function close() { current = ""; }
    function toggle(name) { current = current === name ? "" : name; }
    function isOpen(name) { return current === name; }
}
