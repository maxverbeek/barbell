//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import "modules"
import "services"

ShellRoot {
    // One bar per monitor. Add or remove a screen and Variants creates or
    // destroys the delegate for you — this is the whole hotplug story.
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    // Menus follow the same per-screen pattern: each screen gets one, and only
    // the screen with the pointer/focus shows it.
    Variants {
        model: Quickshell.screens
        delegate: AudioMenu {}
    }

    Variants {
        model: Quickshell.screens
        delegate: NetworkMenu {}
    }

    Variants {
        model: Quickshell.screens
        delegate: BluetoothMenu {}
    }

    // Volume feedback for changes that came from a key rather than a menu.
    Variants {
        model: Quickshell.screens
        delegate: Osd {}
    }

    // Summoned from niri or wlr-which-key. One bind is enough — the menus are
    // tabs on one surface, so s/w/b crosses between them once you're in:
    //
    //   qs ipc call menu open      — open on sound, the usual errand
    //   qs ipc call menu audio     — or land directly on one
    //   qs ipc call menu network
    //   qs ipc call menu bluetooth
    //   qs ipc call menu close     — dismiss whatever is open
    IpcHandler {
        target: "menu"

        function open(): void { Menus.toggle("audio"); }
        function audio(): void { Menus.toggle("audio"); }
        function network(): void { Menus.toggle("network"); }
        function bluetooth(): void { Menus.toggle("bluetooth"); }
        function close(): void { Menus.close(); }
        function current(): string { return Menus.current; }
        // What the open menu is actually showing. Screenshots can't always be
        // trusted (screencopy breaks); this asks the live instance instead.
        function dump(): string { return Menus.describe ? Menus.describe() : ""; }
    }
}
