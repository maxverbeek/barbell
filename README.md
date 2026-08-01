# barbell

A niri bar in [quickshell](https://quickshell.org). It's a **bar** that rings
the **bell** — notifications, OSD, and a keyboard-first menu system summoned by
one bind. Successor to the ags/Astal bar, and to the gpui experiment in
`../gpuitest` before that.

```sh
systemctl --user stop barbell   # the packaged copy owns the notification socket
nix develop
quickshell -p .                 # edits hot-reload, no restart
```

`design/DEVELOPING.md` covers the rest of the local loop — detached runs,
single-widget previews, and the kill/restart traps.

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

**The bar shows exceptions, not state.** Anything whose value doesn't change
what you'd do next belongs in a menu you open deliberately, not on the bar.
CPU at 80% only ever means "go look" — so the bar carries the *trigger* and the
readout lives wherever you'd actually diagnose it. The bar notices, the menu
contextualises, btop investigates. (The resource menu isn't built yet; the bar
trigger is, so today CPU/memory go straight from bar to btop.)

Each component is encoded by when it's *interesting*:

| | drawn when |
|---|---|
| Battery | always |
| Wifi | off, or on a network that isn't yours |
| VPN | up — but never tailscale, on by default = not news |
| Bluetooth | off, or a device connected |
| Speaker | always — it's also the button into the audio menu |
| Mic | in use, or muted |
| CPU / memory | past an interrupt-worthy threshold, and then *with* the number |
| Kube context | always — wrong-cluster mistakes are expensive |
| Claude usage | projected to blow the window, not merely high |

Two of those are worth their exceptions. The mic's loudest state is **muted
while something is listening** — the only mic state that's a *mistake* rather
than a setting. And Claude usage keys on pace rather than level: 16% five days
out is fine, 60% on reset day is not, so what surfaces is the linear
projection, with `↗` saying the trend is the problem.

Corollaries that keep getting reused:

- A container implies contents, so an empty one reads as broken. Capsules wrap
  only what's always present and always full — which makes *anything not in a
  capsule something that isn't normally there.*
- A summary must never look calmer than what it summarises.
- Grey is "you turned it off", red is "it broke". Deliberate isn't an error.
- A shorter label that misleads is worse than a longer one that doesn't — hence
  18 chars for SSIDs, enough to keep the colon in `Researchable: work from…`.
- If the UI needs a legend, the encoding is wrong.

Rejected on the way here, all of them ways to compress something that didn't
need to be on the bar at all: pills, reserved-width slots (leaves holes),
dimming instead of hiding, shrink-to-dot, collapsing clusters (shifts), and one
summary dot (throws away the information the three dots carried).
`design/DECISIONS.md` has the full reasoning.

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
- **Singletons are lazily instantiated**, so a `FileView` that works standalone
  reads empty until something has actually constructed the singleton.
- **`pkill -x quickshell` never matches** (store path), and `pkill -f` matches
  your own shell. Kill by PID. Never glob `/nix/store`.
- `nix flake` ignores untracked files — `git add -N` before blaming the overlay.
- Not every icon is square: `neovim.svg` is 602×734, so an `Image` without
  `PreserveAspectFit` renders it taller and heavier than its neighbours.
- **Don't add `barHeight` to a popup's margin.** The bar claims it as an
  exclusive zone, so the compositor already places surfaces clear of it.
