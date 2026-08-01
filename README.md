# barbell

A niri bar in [quickshell](https://quickshell.org). It's a **bar** that rings
the **bell** — notifications, OSD, and a keyboard-first menu system summoned by
one bind. Successor to the ags/Astal bar, and to the gpui experiment in
`../gpuitest` before that.

```sh
nix develop
quickshell -p .        # edits hot-reload, no restart
```

Packaged: `nix build` gives a `barbell` wrapper that runs the bar from the
store; `barbell ipc call menu open` talks to the running instance without
knowing any store path. nixconfig consumes this as a `git+file` flake input —
commit here, `nix flake update barbell` there.

## The keyboard is the interface

`barbell ipc call menu open` (bound to Mod+; in niri) opens the audio menu.
From anywhere inside:

- `s` / `w` / `b` / `p` / `c` — sound, wifi, bluetooth, player, claude tabs
- `j`/`k`, `g`/`G`, `[`/`]` — rows, ends, sections (`]` lands on the active device)
- `h`/`l` — nudge: volume on audio rows, prev/next on players
- `/` — search (`Ctrl-j/k` to move while typing), `Enter` — act, `Esc` — out
- `m` — mute (audio), `f` — focus the player's window (media)

## Interest rules

The bar only speaks when something is worth saying: no bluetooth glyph when
merely powered, no SSID for networks you're always on, no VPN shield for
tailscale (on by default = not news), no Claude percentage while you're on
pace to last the window. Colour carries urgency; the mic pulses only when
you're muted *while something is listening*.

## Layout

```
shell.qml              Variants over Quickshell.screens + the menu IpcHandler
Theme.qml              Kanagawa ground, Catppuccin text, all semantic tokens
modules/Bar.qml        the PanelWindow; Island.qml groups the connectivity icons
modules/Menu.qml       the whole keyboard model — menus only supply rows
modules/*Menu.qml      audio / network / bluetooth / media / claude
services/Niri.qml      niri IPC event stream -> workspaces + windows
services/ClaudeUsage.qml  statusline-hook file + OAuth usage endpoint
```

## Gotchas that cost a debugging round

- **Bindings track properties, not function results** — name the property.
- **Reordering a Repeater model rebuilds every delegate**, restarting
  animations. Keep list order stable; mark the active row instead.
- A **hoverEnabled MouseArea swallows hover** rather than passing it down.
- **Pipewire.ready is false at startup**; filter sinks on `PwNodeType`, never
  on a property that starts empty.
- `QT_QPA_PLATFORMTHEME=gtk3` or every app icon comes up empty (set in flake).
- wlr screencopy returns frozen frames while the session is locked —
  `barbell ipc call menu dump` exists so state is checkable blind.
