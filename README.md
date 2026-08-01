# barbarella

A niri bar in [quickshell](https://quickshell.org). Successor experiment to the
gpui one in `../gpuitest`.

```sh
nix develop
quickshell -p .        # edits hot-reload, no restart
```

Currently anchors to the **bottom** edge so it can run alongside ags. Flip
`Theme.bottom` to move it up.

## Layout

```
shell.qml            Variants over Quickshell.screens -> one Bar per monitor
Theme.qml            Catppuccin palette, ported from ags' _variables.scss
modules/Bar.qml      the PanelWindow (layer-shell surface)
modules/Workspaces.qml
modules/Clock.qml
services/Niri.qml    niri IPC event stream -> workspaces + windows
services/Icons.qml   app_id -> .desktop entry -> icon theme
```

## What quickshell gives you for free

Pipewire, Bluetooth, UPower, SystemTray, Mpris, Notifications, and (as of 0.3)
`Quickshell.Networking` with wifi scan/connect/PSK/forget. Multi-monitor is
`Variants { model: Quickshell.screens }` — screens appearing and disappearing
just create and destroy delegates.

## What it doesn't

- **niri.** Only Hyprland and I3 ship built in, hence `services/Niri.qml`.
- **VPN.** `Networking`'s `DeviceType` is `None | Wifi | Wired` only, so the
  VPN indicator (the thing AstalNetwork couldn't do) still needs writing —
  `nmcli monitor` or a NetworkManager DBus watch. `tailscale0` shows up as
  type `tun` in `nmcli -t -f NAME,TYPE connection show --active`.

## Gotchas hit so far

- **Bindings track properties, not function results.** `model: Niri.workspacesOn(name)`
  never updates; `model: Niri.workspaces.filter(...)` does, because it names the
  property. This cost a debugging round — the pills simply stopped following focus.
- **Qt has no platform theme on NixOS**, so `QIcon` falls back to hicolor and
  app icons come up empty. `QT_QPA_PLATFORMTHEME=gtk3` makes it read the GTK
  settings where Papirus is configured. Set in the flake.
- `zen-browser` and friends aren't in any installed theme; they come from
  `~/.config/ags/icons/`, same as ags uses.

## Measured (idle, 20s, this machine)

| | CPU | RSS |
|---|---|---|
| ags | 0.0% | 5 MB |
| quickshell | 0.3% | 154 MB |
| gpui | 5.8% | 121 MB |

## Not done yet

CPU/mem pills w/ hover reveal, kube context, battery, wifi + VPN indicator,
volume/mic, bluetooth, popover menu. See `../gpuitest` for reference
implementations of all of them.
