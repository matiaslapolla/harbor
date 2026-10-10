# harbor v1 — plan

Spec: [docs/specs/harbor-v1.md](../specs/harbor-v1.md).

## Layout

```
manifest.json      bar-widget + service
BarWidget.qml      strip; owns one Notch per bar instance
Notch.qml          layer-shell surface under the bar: preview + app row
Service.qml        one Dock per screen (Variants over Quickshell.screens), groups store, IPC
Dock.qml           dock surface for one screen
DockMenu.qml       window/group context menu (PopupWindow + focus grab)
WorkspaceGrid.qml  workspace-number grid used by the menu
AppIcon.qml        desktop-entry icon with a monogram fallback
lib/banks.js       bank membership, numbering, labels
lib/groups.js      immutable group operations + parse/serialize
lib/dispatch.js    hyprctl dispatch strings, quoting
lib/geometry.js    preview scaling
test/*.test.mjs    node --test, loads lib/*.js through vm (QML JS has no exports)
Makefile           check = validate + qmllint + test
install.sh         symlink into ~/.config/omarchy/plugins and enable
```

## Steps

1. Scaffold: manifest, Makefile, install.sh, test loader. Commit.
2. `lib/` with tests, red then green, one module at a time. Commit each.
3. Strip: replace `io.github.derluke.dual-monitor-workspaces` in `shell.json`
   (back up first). Verify numbers per monitor by screenshot. Commit.
4. Notch: preview + app row, hover lifecycle, slide animation. Verify by
   moving the cursor with `hl.dsp.cursor.move` and taking screenshots. Commit.
5. Dock: windows per monitor, pinned and autohide. Commit.
6. Menu + groups: move grid, group operations, persistence. Verify with
   `hyprctl clients -j` and the state file. Commit.
7. README, then `code-review`, then the gate.
8. `gh repo create matiaslapolla/harbor --public`, push `main`.

## Risks

- `HyprlandToplevel.lastIpcObject` goes stale (Hoverview notes this). Geometry
  for the preview comes from `hyprctl clients -j`, refreshed on open and on
  window events.
- Screencopy of windows on hidden workspaces can be blank. Fall back to the
  icon tile when the capture has no content.
- A layer surface under the bar must not block clicks on apps: the input mask
  is the notch rectangle only, and empty while closed.
