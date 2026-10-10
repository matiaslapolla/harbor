# harbor v1.1 — notch cards and dock settings

Status: approved 2026-10-10. Builds on [harbor v1](harbor-v1.md); where the
two disagree, this one wins. Terms are in [CONTEXT.md](../../CONTEXT.md).

## Why

- The to-scale preview shrinks windows to slivers on a wide monitor, and a
  workspace with many windows cannot show them all. Each window gets a card
  of the same width instead, in a row you can drag.
- The dock has a single setting (pinned or autohide) and it is reachable only
  through IPC. It should be editable from the dock itself.

## Decisions

1. The notch's preview becomes a **card row**: one card per window, all the
   same width, in a horizontal `Flickable`. This replaces the to-scale preview.
   The app row is also dropped, because every card already shows the app's
   icon and the window title.
2. The notch shows at most `visibleCards` cards at a time. Any extra cards are
   reached by dragging or with the mouse wheel.
3. The dock settings live in a third kind of dock menu, `dock`. It opens with
   a right-click on the dock background or a left-click on a `⋯` tile at the
   end of the dock. Changes apply at once, and the menu stays open.
4. All dock options sit together under `dock` in `harbor.json`, and one IPC
   method sets any of them. `setDockMode` is removed.
5. The settings controls are the shell's own `ButtonGroup` and `ToggleSwitch`.

## Behaviour

### Notch

- Card: a fixed width `cardWidth` (default 220). The capture area is
  `cardWidth × round(cardWidth × 0.62)`. The live capture is fitted inside
  that area with the window's own aspect ratio, and the app icon stands in
  when there is no capture. Under the capture are the app icon and the
  window title, elided.
- Cards go left to right in the windows' screen order. The focused window's
  card has an accent border.
- The viewport is `min(windows, visibleCards)` cards wide (default 3). A
  horizontal drag scrolls it, and so does the vertical mouse wheel. A thin
  indicator under the row shows the position when the row overflows.
- A click on a card that does not turn into a drag focuses that window.
- Retargeting to another workspace scrolls back to the first card.
- An empty workspace shows one card-sized placeholder that reads "Empty". A
  click on it focuses the workspace.

### Dock settings

| Option | Values | Default |
|---|---|---|
| Size | S, M, L, XL (icons 24, 32, 40, 48 px before UI scale) | M |
| Labels | Off, App (desktop-entry name), Title (window title) | Off |
| Workspace badges | on, off | on |
| Show | This monitor, This workspace (the monitor's active one) | This monitor |
| Auto-hide | on, off | off |

- With labels on, each window tile gets a fixed width and a one-line label
  under its icon. Group tiles keep their own name label.
- "This workspace" limits the loose windows. Groups always show.
- IPC: `setDock <key> <value>` with key `mode`, `size`, `labels`, `badges` or
  `scope`. An invalid key or value changes nothing.

## Acceptance criteria

- [ ] `make check` passes.
- [ ] Unit tests cover: every dock option (valid, invalid, and booleans given
      as strings), parsing a file with missing or invalid dock options, a file
      from v1 (only `mode`), fitting a capture into a card (wide, tall, zero
      size), and the viewport width (no cards, fewer than `visibleCards`, more).
- [ ] The notch shows fixed-width cards for a workspace with windows, and
      "Empty" for one without (checked by screenshot).
- [ ] A workspace with more windows than `visibleCards` overflows, and the
      row can be scrolled (checked by screenshot after scrolling).
- [ ] The dock settings menu opens and shows Size, Labels, Workspace badges,
      Show and Auto-hide (checked by screenshot).
- [ ] Changing Size, Labels and Show changes the dock (checked by screenshot),
      and each change lands in `harbor.json`.
- [ ] The shell log shows no errors from `matiaslapolla.harbor`.
- [ ] The README covers the new settings, the IPC change and the cards.
