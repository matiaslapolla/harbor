.pragma library

// Largest size with the window's aspect ratio that fits the box. A window
// without a size fills the box.
function fitSize(width, height, boxWidth, boxHeight) {
  if (!(width > 0) || !(height > 0)) return { width: boxWidth, height: boxHeight }
  var factor = Math.min(boxWidth / width, boxHeight / height)
  return { width: Math.round(width * factor), height: Math.round(height * factor) }
}

// Width of the card row's viewport: every card up to `visible`, and one
// card's width for an empty workspace's placeholder. `maxWidth` is the room
// on screen; the row scrolls past it but never shrinks below one card.
function viewportWidth(count, cardWidth, visible, spacing, maxWidth) {
  var shown = Math.max(1, Math.min(count, visible))
  var width = shown * cardWidth + (shown - 1) * spacing
  return maxWidth > 0 ? Math.min(width, Math.max(cardWidth, maxWidth)) : width
}

// Dock tile width for a label mode; `scale` is the shell's UI scale for the minimums.
function windowTileWidth(labels, tileSize, scale) {
  if (labels === "title") return Math.max(Math.round(tileSize * 2.4), Math.round(110 * scale))
  if (labels === "app") return Math.max(Math.round(tileSize * 1.7), Math.round(72 * scale))
  return tileSize
}
