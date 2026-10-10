# harbor

Workspaces, a notch and a dock for the [Omarchy](https://omarchy.org) shell,
built for setups where each monitor owns its own bank of workspaces
([split-monitor-workspaces](https://github.com/zjeffer/split-monitor-workspaces)).

- **Strip.** The bar shows the workspace numbers of its own monitor. With
  DP-1 on 1–10 and HDMI-A-1 on 11–20, both bars read `1 … 0`, and those are
  the keys you press.
- **Notch.** Rest the pointer on a number and a notch drops from the bar's
  bottom border. It has a live, to-scale preview of that workspace and a row
  with its apps. Slide along the numbers and the notch follows.
- **Dock.** A dock at the bottom of each monitor lists its windows. You can
  put windows into named groups by hand. Right-click any window or group to
  move it to a workspace on any monitor, without your focus going with it.

Each monitor's bank comes from Hyprland, so a single-monitor setup works too:
the strip then shows that monitor's workspaces.

## Install

```sh
omarchy plugin add https://github.com/matiaslapolla/harbor.git --enable --yes
```

To hack on it, clone it anywhere and run `./install.sh`. That symlinks the
checkout into `~/.config/omarchy/plugins/`.

The strip replaces the stock workspace numbers. Take `omarchy.workspaces`
(or any other workspaces widget) out of `bar.layout` in
`~/.config/omarchy/shell.json`.

Needs Hyprland 0.56+ (Lua dispatchers) and Omarchy's Quickshell shell.

## Interactions

| Where | Action | What it does |
|---|---|---|
| strip | click | focus that workspace |
| strip | scroll | previous / next workspace in this bank |
| strip | rest the pointer | drop the notch for that workspace |
| notch | click a window or an app icon | focus that window |
| notch | click the empty preview | focus the workspace |
| dock window | left / middle / right | focus / close / menu |
| dock group | left / right | focus its windows in turn / menu |

The window menu has a **Move to** grid with one row per monitor, **Add to
group** (an existing group or a new one, named inline) and **Remove from**
for each group the window is in. It also has **Close window**. The group menu
has **Move all to**, **Rename** and **Delete group**. Deleting a group does
not close its windows. Escape or a click outside closes the menu.

Groups hold window addresses, so they persist across shell restarts but not
across logouts. When a window closes, it leaves its groups. An empty group
stays until you delete it.

## Settings

The strip and notch settings go under the widget's entry in
`~/.config/omarchy/shell.json`, or through Setup > Plugins:

```json
{ "id": "matiaslapolla.harbor", "count": 10, "hoverDelayMs": 180, "livePreview": true, "previewWidth": 420 }
```

| Key | Default | Meaning |
|---|---|---|
| `count` | `10` | how many workspaces of the bank the strip shows |
| `hoverDelayMs` | `180` | how long the pointer rests on a number before the notch drops |
| `livePreview` | `true` | live window captures in the preview; `false` draws app icons |
| `previewWidth` | `420` | preview width in pixels |

The dock mode and the groups are in
`~/.local/state/omarchy/settings/harbor.json`. Change the dock mode over IPC:
`pinned` reserves space at the bottom, and `autohide` slides the dock in when
the pointer touches the bottom edge.

## IPC

```sh
omarchy-shell harbor setDockMode autohide
omarchy-shell harbor windows                 # JSON: address, appClass, title, workspaceId, monitor
omarchy-shell harbor groups                  # JSON
omarchy-shell harbor createGroup "Deep work" 0x5f66716c0530   # prints the new id
omarchy-shell harbor addToGroup g1 0x5f66708cf1f0
omarchy-shell harbor removeFromGroup g1 0x5f66708cf1f0
omarchy-shell harbor renameGroup g1 "Focus"
omarchy-shell harbor moveGroup g1 3
omarchy-shell harbor moveWindow 0x5f66708cf1f0 12
omarchy-shell harbor deleteGroup g1
```

Workspace arguments are Hyprland workspace ids (12 is `2` on the second bank).

## Glass bars

Do not use the theme's accent colour on the bar if you run a glass bar such as
True Glass. It keys that colour out, so the strip marks the focused workspace
with a pill.

## Development

```sh
make check   # manifest validation, qmllint syntax gate, node --test over lib/
```

Banks, groups, dispatch strings and preview geometry are plain JavaScript in
`lib/`, with tests in `test/`. The QML files only wire them to Quickshell.
