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

    // Summoned from niri or wlr-which-key:
    //   qs ipc call menu audio     — toggle the audio menu
    //   qs ipc call menu network   — toggle the network menu
    //   qs ipc call menu close     — dismiss whatever is open
    IpcHandler {
        target: "menu"

        function audio(): void { Menus.toggle("audio"); }
        function network(): void { Menus.toggle("network"); }
        function close(): void { Menus.close(); }
        function current(): string { return Menus.current; }
        // What the open menu is actually showing. Screenshots can't always be
        // trusted (screencopy breaks); this asks the live instance instead.
        function dump(): string { return Menus.describe ? Menus.describe() : ""; }
    }
}
