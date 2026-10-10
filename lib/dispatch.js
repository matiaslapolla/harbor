.pragma library

// hyprctl dispatch strings for Hyprland's Lua dispatchers. Inputs are
// validated, never escaped: an invalid id or address yields "" so callers
// skip the call instead of sending a malformed one.

function normalizeAddress(address) {
  var s = String(address === null || address === undefined ? "" : address).trim().toLowerCase()
  if (s.indexOf("0x") !== 0) s = "0x" + s
  return /^0x[0-9a-f]+$/.test(s) ? s : ""
}

function workspaceId(id) {
  var s = String(id)
  return /^[1-9][0-9]*$/.test(s) ? s : ""
}

function focusWorkspace(id) {
  var ws = workspaceId(id)
  return ws ? 'hl.dsp.focus({ workspace = "' + ws + '" })' : ""
}

function focusWindow(address) {
  var addr = normalizeAddress(address)
  return addr ? 'hl.dsp.focus({ window = "address:' + addr + '" })' : ""
}

function moveWindow(address, id) {
  var addr = normalizeAddress(address)
  var ws = workspaceId(id)
  if (!addr || !ws) return ""
  return 'hl.dsp.window.move({ workspace = "' + ws + '", window = "address:' + addr + '", follow = false })'
}

function closeWindow(address) {
  var addr = normalizeAddress(address)
  return addr ? 'hl.dsp.window.close({ window = "address:' + addr + '" })' : ""
}

function argv(command) {
  return command ? ["hyprctl", "dispatch", command] : []
}
