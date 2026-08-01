# Running the bar locally

## The normal loop

```sh
nix develop
quickshell -p .        # edits hot-reload, no restart
```

`QT_QPA_PLATFORMTHEME=gtk3` is required or every app icon resolves empty — Qt
has no platform theme on NixOS by default, so QIcon falls back to hicolor.
The devShell and the packaged wrapper both set it; only a bare invocation from
a plain shell needs it spelled out.

## Two bars, one D-Bus name

`barbell.service` is a systemd **user** unit running the *packaged* copy from
the nix store. It is the bar you normally live with, and `Restart=always` means
`kill <pid>` accomplishes nothing — systemd brings it straight back. Stop the
unit:

```sh
systemctl --user stop barbell     # dev session
systemctl --user start barbell    # hand the desktop back
```

Skip that and the dev copy comes up half functional, because the service
already owns `org.freedesktop.Notifications`:

```
WARN quickshell.service.notifications: Could not register notification server
     at org.freedesktop.Notifications, presumably because one is already registered.
```

Quickshell retries when the name frees up, so a dev copy that is already
running claims notifications on its own once the service stops — the order
doesn't matter. Whoever starts last loses the race; that was also true back
when ags was still around.

Both bars claim an exclusive zone, so two at once also means a clipped or
pushed-down panel and a misleading screenshot.

Tell them apart by config path, never by process name:

```sh
pgrep -a quickshell
# …/bin/quickshell -p .                       <- your working copy
# …/bin/quickshell -p /nix/store/…-source      <- the service
```

## Killing instances

`pgrep -x quickshell` and `pkill -x quickshell` **both fail** — the binary sits
under a store path and `-x` won't match, so "kill then relaunch" silently
becomes "relaunch" and previews stack up until they cover half the screen.

`pkill -f` is worse: the pattern matches the invoking shell too, and it killed
the terminal four times in one session. Kill by PID instead:

```sh
for p in $(ps aux | grep bp.qml | grep -v grep | awk '{print $2}'); do kill $p; done
```

Related, and the reason there's a hook enforcing it: **never glob
`/nix/store`.** `ls /nix/store/*/bin/grim` and friends take the shell down with
them. Resolve one path with `command -v`, or go through `nix develop -c`.

## Detached, with a log

A foreground `quickshell` dies with the shell that started it. `setsid` plus a
redirect keeps it up while you work:

```sh
QT_QPA_PLATFORMTHEME=gtk3 setsid quickshell -p . > /tmp/qs.log 2>&1 < /dev/null &
sleep 4; tail -8 /tmp/qs.log
```

`< /dev/null` matters, or it can stop on `SIGTTIN` trying to read the terminal.
A clean start ends in `INFO: Configuration Loaded`; quickshell also keeps its
own log at the `by-id` path it prints on startup. Two warnings are permanent
noise — the host-portal `Could not register app ID` line, and the notification
line whenever the service is also up. To cut the rest:

```sh
... | grep -viE "portal|Shell ID|Saving logs|register"
```

## Hot reload, and when it lies

Saving reloads. The caveat that cost two debugging rounds: occasionally it
just doesn't, and you end up reading pixels for a change that was never
loaded. **If a visual change doesn't appear, restart before you debug the QML.**

Singletons are lazily instantiated, which produces a related puzzle: a
`FileView` that works standalone reads as empty inside a singleton, because
nothing had constructed the singleton before the timer read it.

## Previewing one widget

A whole bar is a slow way to look at one glyph. A throwaway `ShellRoot` that
imports the single module and instantiates it at several hand-set states —
this is how the battery shape was iterated:

```qml
//@ pragma UseQApplication
import QtQuick
import Quickshell
import "."
import "modules"

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            anchors { bottom: true; left: true; right: true }
            implicitHeight: 32
            color: Theme.barBg
            Row {
                anchors.centerIn: parent
                spacing: 18
                Battery { percent: 100; charging: true }
                Battery { percent: 24 }
                Battery { percent: 8 }
            }
        }
    }
}
```

**It has to live at the project root.** Quickshell scopes modules to the config
folder, so a preview in `design/` cannot resolve `Theme` or `modules` no matter
how you spell the import. Keep it at the root, use the real token names
(`Theme.barBg`, not `bg0`), and delete it before committing.

```sh
quickshell -p battpreview.qml
```

Then screenshot the panel region and zoom, because defects invisible at 26×13
are obvious at 5×:

```sh
grim -g "820,1080 300x90" -s 8 out.png
```

`grim -g` takes **logical** coordinates — this screen is 2880×1800 physical,
1920×1200 logical at 1.5×. `niri msg action screenshot-window --id N` grabs a
window by id without focusing it.

## Talking to a running instance

Quickshell addresses instances by config path, and the store path changes every
rebuild, so the wrapper hides it:

```sh
barbell ipc call menu open
barbell ipc call menu dump     # state as text
```

Against a working copy the path is the checkout:

```sh
quickshell ipc -p ~/Personal/barbell call menu open
```

`dump` exists because wlr screencopy returns frozen, byte-identical frames
while the session is locked. When a screenshot can't be trusted, the text can.

## Packaging

`nix build` produces the `barbell` wrapper; nixconfig consumes this repo as a
`git+file` flake input, so the update flow is commit here →
`nix flake update barbell` there → rebuild. The file input is deliberate: a
rebuild picks up committed-but-unpushed work.

`nix flake` **ignores untracked files** — a new file that "isn't applying" is
usually just untracked. `git add -N` is enough.
