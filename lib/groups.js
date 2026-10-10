.pragma library

// Groups are plain data: { dock: { <option>: value }, groups: [{ id, name, members }], lastId }.
// `lastId` only grows, so a deleted group's id is never handed out again.
// Every operation returns a new state, or the same object when nothing changed.

// Allowed values per dock option; the first one is the default.
var DOCK_OPTIONS = {
  mode: ["pinned", "autohide"],
  size: ["m", "s", "l", "xl"],
  labels: ["off", "app", "title"],
  badges: [true, false],
  scope: ["monitor", "workspace"]
}
var MAX_NAME = 40
var ADDRESS = /^0x[0-9a-f]+$/

function defaultDock() {
  var dock = {}
  for (var key in DOCK_OPTIONS) dock[key] = DOCK_OPTIONS[key][0]
  return dock
}

function emptyState() {
  return { dock: defaultDock(), groups: [], lastId: 0 }
}

// The allowed value `value` stands for, or undefined. IPC sends booleans as strings.
function dockValue(key, value) {
  var allowed = DOCK_OPTIONS.hasOwnProperty(key) ? DOCK_OPTIONS[key] : null
  if (!allowed) return undefined
  if (value === "true") value = true
  else if (value === "false") value = false
  return allowed.indexOf(value) === -1 ? undefined : value
}

function normalizeName(name) {
  if (typeof name !== "string") return ""
  return name.replace(/\s+/g, " ").trim().slice(0, MAX_NAME)
}

function withGroups(state, groups, lastId) {
  return { dock: state.dock, groups: groups, lastId: lastId === undefined ? state.lastId : lastId }
}

function createGroup(state, name, firstMember) {
  var clean = normalizeName(name)
  if (!clean) return { state: state, id: "" }
  var id = "g" + (state.lastId + 1)
  var group = { id: id, name: clean, members: firstMember ? [firstMember] : [] }
  return { state: withGroups(state, state.groups.concat([group]), state.lastId + 1), id: id }
}

function updateGroup(state, id, change) {
  var changed = false
  var groups = state.groups.map(function(group) {
    if (group.id !== id) return group
    var updated = change(group)
    if (updated !== group) changed = true
    return updated
  })
  return changed ? withGroups(state, groups) : state
}

function renameGroup(state, id, name) {
  var clean = normalizeName(name)
  if (!clean) return state
  return updateGroup(state, id, function(group) {
    return group.name === clean ? group : { id: group.id, name: clean, members: group.members }
  })
}

function deleteGroup(state, id) {
  var groups = state.groups.filter(function(group) { return group.id !== id })
  return groups.length === state.groups.length ? state : withGroups(state, groups)
}

function addMember(state, id, address) {
  return updateGroup(state, id, function(group) {
    if (!address || group.members.indexOf(address) !== -1) return group
    return { id: group.id, name: group.name, members: group.members.concat([address]) }
  })
}

function removeMember(state, id, address) {
  return updateGroup(state, id, function(group) {
    if (group.members.indexOf(address) === -1) return group
    var members = group.members.filter(function(member) { return member !== address })
    return { id: group.id, name: group.name, members: members }
  })
}

function prune(state, aliveAddresses) {
  var next = state
  for (var i = 0; i < state.groups.length; i++) {
    var group = state.groups[i]
    for (var j = 0; j < group.members.length; j++) {
      if (aliveAddresses.indexOf(group.members[j]) === -1) next = removeMember(next, group.id, group.members[j])
    }
  }
  return next
}

function groupsOf(state, address) {
  return state.groups.filter(function(group) { return group.members.indexOf(address) !== -1 })
}

function setDockOption(state, key, value) {
  var clean = dockValue(key, value)
  if (clean === undefined || state.dock[key] === clean) return state
  var dock = {}
  for (var k in state.dock) dock[k] = state.dock[k]
  dock[key] = clean
  return { dock: dock, groups: state.groups, lastId: state.lastId }
}

function serialize(state) {
  return JSON.stringify(state, null, 2) + "\n"
}

function parse(text) {
  var state = emptyState()
  var data
  try { data = JSON.parse(text) } catch (e) { return state }
  if (!data || typeof data !== "object" || Array.isArray(data)) return state

  if (data.dock && typeof data.dock === "object") {
    for (var key in DOCK_OPTIONS) {
      if (DOCK_OPTIONS[key].indexOf(data.dock[key]) !== -1) state.dock[key] = data.dock[key]
    }
  }
  if (Array.isArray(data.groups)) {
    for (var i = 0; i < data.groups.length; i++) {
      var raw = data.groups[i]
      if (!raw || typeof raw !== "object" || !/^g[0-9]+$/.test(raw.id)) continue
      var name = normalizeName(raw.name)
      if (!name) continue
      var members = []
      var source = Array.isArray(raw.members) ? raw.members : []
      for (var j = 0; j < source.length; j++) {
        if (typeof source[j] === "string" && ADDRESS.test(source[j]) && members.indexOf(source[j]) === -1) members.push(source[j])
      }
      state.groups.push({ id: raw.id, name: name, members: members })
      state.lastId = Math.max(state.lastId, Number(raw.id.slice(1)))
    }
  }
  if (typeof data.lastId === "number" && data.lastId > state.lastId) state.lastId = Math.floor(data.lastId)
  return state
}
