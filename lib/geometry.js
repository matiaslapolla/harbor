.pragma library

// Largest size with the window's aspect ratio that fits the box. A window
// without a size fills the box.
function fitSize(width, height, boxWidth, boxHeight) {
  if (!(width > 0) || !(height > 0)) return { width: boxWidth, height: boxHeight }
  var factor = Math.min(boxWidth / width, boxHeight / height)
  return { width: Math.round(width * factor), height: Math.round(height * factor) }
}

// Width of the card row's viewport: every card up to `visible`, and one
// card's width for an empty workspace's placeholder.
function viewportWidth(count, cardWidth, visible, spacing) {
  var shown = Math.max(1, Math.min(count, visible))
  return shown * cardWidth + (shown - 1) * spacing
}
