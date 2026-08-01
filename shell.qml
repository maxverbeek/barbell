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

    // Summoned from niri or wlr-which-key:
    //   qs ipc call menu audio     — toggle the audio menu
    //   qs ipc call menu close     — dismiss whatever is open
    IpcHandler {
        target: "menu"

        function audio(): void { Menus.toggle("audio"); }
        function close(): void { Menus.close(); }
        function current(): string { return Menus.current; }
    }
}
