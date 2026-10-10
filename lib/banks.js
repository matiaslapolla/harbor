.pragma library

// A bank is the set of workspaces one monitor owns. Items in `workspaces`
// are { id, monitor } with `monitor` as a monitor name (or null).

// One bank per row of number keys: 1…9, 0.
var BANK_SIZE = 10

function labelFor(number) {
  return number === BANK_SIZE ? "0" : String(number)
}

function bankFor(workspaces, monitorName, count) {
  if (!workspaces || !monitorName) return []
  var ids = []
  for (var i = 0; i < workspaces.length; i++) {
    var ws = workspaces[i]
    if (ws && ws.id > 0 && ws.monitor === monitorName && ids.indexOf(ws.id) === -1) ids.push(ws.id)
  }
  ids.sort(function(a, b) { return a - b })
  return ids.slice(0, Math.max(0, count)).map(function(id, index) {
    return { id: id, label: labelFor(index + 1) }
  })
}

function labelOf(workspaces, workspaceId) {
  for (var i = 0; i < (workspaces || []).length; i++) {
    if (workspaces[i].id !== workspaceId) continue
    var bank = bankFor(workspaces, workspaces[i].monitor, BANK_SIZE)
    for (var j = 0; j < bank.length; j++) if (bank[j].id === workspaceId) return bank[j].label
  }
  return String(workspaceId)
}

// Id of the workspace `step` places away from `currentId`, wrapping around.
// An id outside the bank steps from the start; an empty bank yields -1.
function neighbour(bank, currentId, step) {
  if (!bank || bank.length === 0) return -1
  var index = -1
  for (var i = 0; i < bank.length; i++) if (bank[i].id === currentId) index = i
  if (index === -1) return bank[0].id
  var next = ((index + step) % bank.length + bank.length) % bank.length
  return bank[next].id
}

// Every monitor's bank, `firstMonitor` first and the rest by name.
function banksByMonitor(workspaces, firstMonitor, count) {
  var names = []
  for (var i = 0; i < (workspaces || []).length; i++) {
    var name = workspaces[i] && workspaces[i].monitor
    if (name && names.indexOf(name) === -1) names.push(name)
  }
  names.sort(function(a, b) {
    if (a === firstMonitor) return -1
    if (b === firstMonitor) return 1
    return a < b ? -1 : a > b ? 1 : 0
  })
  return names.map(function(name) {
    return { monitor: name, slots: bankFor(workspaces, name, count) }
  })
}
