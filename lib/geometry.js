.pragma library

// Monitors come from `hyprctl monitors -j` (pixel size, scale, transform,
// logical x/y); clients from `hyprctl clients -j` (logical `at` and `size`).

function logicalSize(monitor) {
  var scale = monitor.scale > 0 ? monitor.scale : 1
  var width = monitor.width / scale
  var height = monitor.height / scale
  var rotated = monitor.transform % 2 === 1
  return { width: rotated ? height : width, height: rotated ? width : height }
}

// Largest box with the monitor's aspect ratio that fits maxWidth x maxHeight.
// `factor` converts logical monitor pixels to preview pixels.
function previewSize(monitor, maxWidth, maxHeight) {
  var size = monitor && monitor.width > 0 && monitor.height > 0
    ? logicalSize(monitor) : { width: 1920, height: 1080 }
  var factor = Math.min(maxWidth / size.width, maxHeight / size.height)
  return {
    width: Math.round(size.width * factor),
    height: Math.round(size.height * factor),
    factor: factor
  }
}

function windowRect(client, monitor, factor) {
  if (!client || !client.at || !client.size) return null
  var size = logicalSize(monitor)
  var left = Math.max(0, client.at[0] - monitor.x)
  var top = Math.max(0, client.at[1] - monitor.y)
  var right = Math.min(size.width, client.at[0] - monitor.x + client.size[0])
  var bottom = Math.min(size.height, client.at[1] - monitor.y + client.size[1])
  if (right <= left || bottom <= top) return null
  return {
    x: Math.round(left * factor),
    y: Math.round(top * factor),
    width: Math.round((right - left) * factor),
    height: Math.round((bottom - top) * factor)
  }
}
