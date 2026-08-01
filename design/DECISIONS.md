# Design decisions

Working notes from the design session. Rationale lives here so the QML can stay
short.

## The bar shows exceptions, not state

Anything whose value doesn't change what you'd do next belongs in the menu, not
on the bar. CPU at 80% only ever means "open btop", so the bar carries the
trigger and the menu carries the readout.

Consequences:
- No pills. A container implies contents, and a mostly-empty one reads as a
  broken layout rather than a quiet one.
- No reserved space. Nothing is hidden, so nothing needs a slot held open.
- Hairline rules if grouping is ever needed — they separate without enclosing.

Rejected along the way: collapsing clusters (shifts), reserved-width slots
(leaves holes), dimming (F2), shrink-to-dot (G2), one summary dot (throws away
the information the three dots carried). All were ways to compress something
that didn't need to be there.

## Per-component rules

| Component | Drawn when | Notes |
|---|---|---|
| Battery | always | fill + number + state in one element |
| Wifi | off, or on a listed network | see below |
| VPN | up | the thing AstalNetwork couldn't do |
| Bluetooth | off, or a device connected | device-type icon, blue-tinted |
| Speaker | always | one shape, blue when output is bluetooth |
| Mic | in use, or muted | see below |
| CPU / memory | past an interrupt-worthy threshold | shows the number when it appears |
| Kube context | always | wrong-cluster mistakes are expensive |

### Wifi: the listed networks

```
BusinessCenter                    14
OnePlus 5                          9
Researchable: work from anywhere  32   <- boss's hotspot, NOT the office network
UMCG Guest                        10
Plus Ultra Guests                 17
```

Not "public networks" — two of these are personal hotspots. The rule is
*networks that aren't your own*, and the icon appearing is itself the signal.

**Show the name, truncated at 18 characters.** Four of the five fit whole at
that budget, so the ceiling only ever bites the one outlier; it isn't a
compromise imposed on every name.

Abbreviating to the first word was the obvious cheaper option and it's wrong:
`Researchable: work from anywhere` is the boss's hotspot, so rendering it as
`Researchable` would read as the office network. 18 keeps the colon, which is
exactly what distinguishes them. *A shorter label that misleads is worse than a
longer one that doesn't.*

### Bluetooth: a plain bluetooth rune

Use `󰂯 md-bluetooth`, accent-tinted. The device-type glyph was tried first and
rejected: with a headset connected it duplicated the sound icon exactly.

MDI *does* have bluetooth-marked device glyphs (`󰥰 md-headphones_bluetooth`,
`󰦋 md-mouse_bluetooth`, `󰦢 md-speaker_bluetooth`) but at 15px the bluetooth
mark is a 3px speck that reads as a rendering artefact. They only work above
~40px. Rendered and compared before deciding.

Which device is connected lives in the menu.

### Audio: the speaker keeps its shape, the mic carries three states

The speaker is always drawn, always the same glyph, and turns **blue when the
output is bluetooth**. Constant shape matters because it's also the button into
the audio menu — a target that changes shape is a target you have to look at.
Bluetooth sinks report `device.api = "bluez5"`.

The mic is drawn only when something is listening or it's muted:

| state | render | why |
|---|---|---|
| nobody listening | *nothing* | the usual case |
| in use | green mic | active and working, like the VPN |
| muted, idle | red muted-mic | a setting you changed |
| **muted, in use** | **red muted-mic, loudest** | you're talking and nobody can hear you |

The last one is the reason to build this: it's the only mic state that
represents a *mistake* rather than a setting.

Detectable natively — `PwNodeLinkTracker` on `Pipewire.defaultAudioSource`
gives live link groups, so a non-empty list means something is capturing. No
polling, no subprocesses. Verified with `pw-record` on this machine.

## Colour language

- **fg0 / white** — default, healthy, unremarkable
- **green** — active and good (VPN up, charging)
- **yellow** — wants attention (load high, battery low)
- **red** — changed or critical (muted, disconnected)
- **fg2 / grey** — *you* turned it off, which is not an error
- **accent** — focus and interaction

Grey-vs-red is the one addition to the rule the ags bar already followed:
bluetooth disabled on purpose shouldn't look like something broke.

A summary must never look calmer than what it summarises — if a group is ever
collapsed, it takes the worst state among its members.

## Islands

The capsules from the ags bar work — but only around things that are *always
present and always full*. That's workspaces, the always-drawn speaker+battery
pair, and the kube context. Everything conditional stays bare.

That turns the capsule into information rather than decoration: anything not in
a capsule is something that isn't normally there, which gives exceptions a
second signal beyond colour.

## Still open

- Does the clock keep its date, or drop to `12:26`?
- CPU/memory thresholds — 80/85 is a guess.
- Which island arrangement (K1/K2/K3).

## Font

`Inter` was specified in the ags bar but never installed, so it has been
rendering Roboto this whole time. Added to `~/nixconfig/modules/desktop/fonts.nix`;
takes effect on the next rebuild.
