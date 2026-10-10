# harbor v1 — spec

Status: approved 2026-10-10. Terms are defined in [CONTEXT.md](../../CONTEXT.md).

## Why

Omarchy's plugin marketplace covers each piece separately and none of them
together (survey on 2026-10-10):

- Workspace numbers with a hover preview: Hoverview, Spaces. Neither knows
  about banks; Hoverview only shows workspaces 1–10.
- Apps of a workspace on hover: Glance Dock. A flat row, no notch, no banks.
- A dock that groups open windows and moves them to a workspace from a context
  menu: none. omarchy-dock has folders of pinned apps; BetterLife moves windows
  by drag in a separate overview.

harbor is one Omarchy shell plugin (`matiaslapolla.harbor`) that does all
three and treats banks as a first-class concept.

## Decisions

1. One plugin with two kinds: `bar-widget` (strip + notch) and `service`
   (dock). The service is not `keepLoaded`, so saved edits hot-reload.
2. The preview and the app row share one surface, the notch, instead of two
   popups: the user asked for both "at the same time" on hover.
3. The notch is a layer-shell window per monitor placed directly under the
   bar's exclusive zone, so it looks attached to the bar's bottom border. A
   mask limits input to the visible notch; the rest of the strip under the
   bar passes clicks through.
4. Groups are manual. Membership is by window address and persists across
   shell reloads, not logouts. A closed window leaves its groups by itself.
5. Moves are silent (`follow = false`).
6. The move menu is a grid of workspace numbers (this bank, then the other
   banks), not nested submenus.
7. Pure logic (banks, groups, dispatch strings, preview geometry) lives in
   `lib/*.js` with no QML dependencies and is tested with `node --test`. QML
   stays thin.
8. Settings for the strip and notch live in the widget's `shell.json` entry.
   Dock settings and groups live in
   `~/.local/state/omarchy/settings/harbor.json`.

## Behaviour

### Strip

- Shows the workspace numbers of the bank that belongs to the bar's monitor,
  in id order, up to `count` (default 10).
- Focused workspace: accent pill. Occupied: full opacity. Empty: dimmed.
- Click: focus that workspace. Scroll: previous or next workspace in the bank.

### Notch

- Opens after the pointer rests `hoverDelayMs` (default 180) on a strip
  button. It slides down from the bar's bottom edge, centered under the
  button, with square top corners and rounded bottom corners.
- While open, moving to another button retargets it: the notch glides
  horizontally and its content changes to that workspace.
- Content: a to-scale preview of the workspace (live window captures; icons
  if `livePreview` is off or capture is not available), then the app row.
- Click a window in the preview or an icon in the app row: focus that window.
  Click the preview background: focus the workspace.
- Closes 220 ms after the pointer leaves both the strip and the notch, sliding
  back up.
- An empty workspace shows the empty preview and the text "Empty".

### Dock

- One dock per monitor, at the bottom edge. Mode `pinned` (default) reserves
  its height so tiled windows move up; mode `autohide` hides it until the
  pointer touches the bottom edge.
- Left side: the groups, as tiles with up to four stacked member icons, the
  group name and a member count. Right side: the windows on this monitor that
  are in no group, in workspace order, each with its workspace number.
- Window tile: left-click focuses it; middle-click closes it; right-click
  opens the window menu.
- Group tile: left-click focuses its first live member, then cycles through
  them on each click; right-click opens the group menu.
- Window menu: "Move to" grid, "Add to group" (existing groups plus "New
  group"), "Remove from <group>" for each group it is in, "Close".
- Group menu: "Move all to" grid, "Rename", "Delete group" (windows stay
  open).
- "New group" and "Rename" take an inline text field in the menu. Enter
  confirms and Escape cancels. A blank name is rejected.
- The menu closes on outside click, Escape, or after any action.

## Out of scope for v1

Drag and drop, pinned (not running) apps, notification badges, restoring
groups after a logout, vertical bars.

## Acceptance criteria

- [ ] `omarchy plugin validate` passes on the repo root.
- [ ] `make check` passes: manifest validation, `qmllint` with no syntax
      errors, and `node --test` over `lib/`.
- [ ] Unit tests cover: bank membership and numbering (including the `0`
      label and a missing monitor), every group operation (create, rename,
      delete, add, remove, prune dead addresses, parse invalid JSON), dispatch
      strings (focus workspace, focus window, silent move, close) with
      injection-safe quoting, and preview geometry scaling.
- [ ] With the strip on the bar, DP-1 shows numbers for workspaces 1–10 and
      HDMI-A-1 shows `1`…`0` for workspaces 11–20.
- [ ] Hovering a strip button opens the notch attached to the bar's bottom
      border with that workspace's preview and app row; moving to the next
      button retargets it; leaving closes it (checked by screenshot).
- [ ] Each monitor shows a dock at the bottom with its windows.
- [ ] From the dock menu: a window moves to another workspace without the
      focus following it (checked with `hyprctl clients`).
- [ ] A group can be created from a window menu, gets a second member, moves
      as a whole to another workspace, and is deleted. Its file state matches
      after each step.
- [ ] The shell log shows no QML errors or warnings from `matiaslapolla.harbor`
      after enabling it and running the checks above.
- [ ] The README documents install, interactions, settings and IPC.
- [ ] A public repo `matiaslapolla/harbor` exists and has the code.
