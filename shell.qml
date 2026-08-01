//@ pragma UseQApplication
import Quickshell
import "modules"

ShellRoot {
    // One bar per monitor. Add or remove a screen and Variants creates or
    // destroys the delegate for you — this is the whole hotplug story.
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }
}
