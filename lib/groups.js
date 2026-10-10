.pragma library

// Groups are plain data: { dock: { mode }, groups: [{ id, name, members }], lastId }.
// `lastId` only grows, so a deleted group's id is never handed out again.
// Every operation returns a new state, or the same object when nothing changed.

var DOCK_MODES = ["pinned", "autohide"]
var MAX_NAME = 40
var ADDRESS = /^0x[0-9a-f]+$/

function emptyState() {
  return { dock: { mode: "pinned" }, groups: [], lastId: 0 }
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

function setDockMode(state, mode) {
  if (DOCK_MODES.indexOf(mode) === -1 || state.dock.mode === mode) return state
  return { dock: { mode: mode }, groups: state.groups, lastId: state.lastId }
}

function serialize(state) {
  return JSON.stringify(state, null, 2) + "\n"
}

function parse(text) {
  var state = emptyState()
  var data
  try { data = JSON.parse(text) } catch (e) { return state }
  if (!data || typeof data !== "object" || Array.isArray(data)) return state

  if (data.dock && DOCK_MODES.indexOf(data.dock.mode) !== -1) state.dock.mode = data.dock.mode
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
