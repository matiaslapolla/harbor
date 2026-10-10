import { test } from "node:test"
import assert from "node:assert/strict"
import { load, plain } from "./load.mjs"

const G = load("groups")
const A = "0xaa"
const B = "0xbb"

function withGroup(name = "Work", member = A) {
  return G.createGroup(G.emptyState(), name, member)
}

test("createGroup adds a named group with its first member and returns its id", () => {
  const { state, id } = withGroup()
  assert.equal(id, "g1")
  assert.deepEqual(plain(state.groups), [{ id: "g1", name: "Work", members: [A] }])
})

test("createGroup ids never collide after a delete", () => {
  let { state } = withGroup("One")
  state = G.createGroup(state, "Two", B).state
  state = G.deleteGroup(state, "g1")
  assert.equal(G.createGroup(state, "Three", A).id, "g3")
})

test("createGroup rejects a blank name and leaves the state alone", () => {
  const before = G.emptyState()
  const result = G.createGroup(before, "   ", A)
  assert.equal(result.id, "")
  assert.equal(result.state, before)
})

test("normalizeName trims, collapses whitespace and caps length", () => {
  assert.equal(G.normalizeName("  Deep   work \n"), "Deep work")
  assert.equal(G.normalizeName("x".repeat(80)).length, 40)
  assert.equal(G.normalizeName(42), "")
})

test("renameGroup renames, and ignores a blank name or an unknown id", () => {
  const { state } = withGroup()
  assert.equal(G.renameGroup(state, "g1", "Mail").groups[0].name, "Mail")
  assert.equal(G.renameGroup(state, "g1", " "), state)
  assert.equal(G.renameGroup(state, "nope", "Mail"), state)
})

test("addMember appends once and does not mutate the input", () => {
  const { state } = withGroup()
  const next = G.addMember(state, "g1", B)
  assert.deepEqual(plain(next.groups[0].members), [A, B])
  assert.deepEqual(plain(state.groups[0].members), [A])
  assert.equal(G.addMember(next, "g1", B), next)
})

test("removeMember drops the address and keeps the empty group", () => {
  const { state } = withGroup()
  const next = G.removeMember(state, "g1", A)
  assert.deepEqual(plain(next.groups), [{ id: "g1", name: "Work", members: [] }])
})

test("deleteGroup removes only that group", () => {
  let { state } = withGroup("One")
  state = G.createGroup(state, "Two", B).state
  assert.deepEqual(plain(G.deleteGroup(state, "g1").groups.map((g) => g.id)), ["g2"])
})

test("prune keeps only live addresses and returns the same state when nothing died", () => {
  let { state } = withGroup()
  state = G.addMember(state, "g1", B)
  assert.deepEqual(plain(G.prune(state, [B]).groups[0].members), [B])
  assert.equal(G.prune(state, [A, B, "0xcc"]), state)
})

test("groupsOf lists the groups a window belongs to", () => {
  let { state } = withGroup("One")
  state = G.createGroup(state, "Two", A).state
  state = G.createGroup(state, "Three", B).state
  assert.deepEqual(plain(G.groupsOf(state, A).map((g) => g.name)), ["One", "Two"])
})

test("parse round-trips serialize, dock settings included", () => {
  let { state } = withGroup()
  state = G.setDockOption(state, "mode", "autohide")
  state = G.setDockOption(state, "labels", "title")
  assert.deepEqual(plain(G.parse(G.serialize(state))), plain(state))
})

test("parse falls back to an empty state on invalid input", () => {
  for (const text of ["", "nope", "[]", "null", '{"groups": 3}']) {
    assert.deepEqual(plain(G.parse(text)), plain(G.emptyState()), text)
  }
})

test("parse drops malformed groups and members but keeps valid ones", () => {
  const text = JSON.stringify({
    dock: { mode: "sideways" },
    groups: [
      { id: "g1", name: "Ok", members: ["0xaa", 7, "0xaa", "bogus"] },
      { id: "g2", name: "  " },
      { name: "no id" },
      "junk",
    ],
  })
  const state = plain(G.parse(text))
  assert.deepEqual(state.dock, plain(G.emptyState().dock))
  assert.deepEqual(state.groups, [{ id: "g1", name: "Ok", members: ["0xaa"] }])
})

test("emptyState carries the dock defaults", () => {
  assert.deepEqual(plain(G.emptyState().dock),
    { mode: "pinned", size: "m", labels: "off", badges: true, scope: "monitor" })
})

test("setDockOption sets each option to a valid value", () => {
  const state = G.emptyState()
  assert.equal(G.setDockOption(state, "mode", "autohide").dock.mode, "autohide")
  assert.equal(G.setDockOption(state, "size", "xl").dock.size, "xl")
  assert.equal(G.setDockOption(state, "labels", "app").dock.labels, "app")
  assert.equal(G.setDockOption(state, "badges", false).dock.badges, false)
  assert.equal(G.setDockOption(state, "scope", "workspace").dock.scope, "workspace")
})

test("setDockOption keeps the other options and does not mutate the input", () => {
  const state = G.emptyState()
  const next = G.setDockOption(state, "size", "s")
  assert.equal(next.dock.labels, "off")
  assert.equal(state.dock.size, "m")
})

test("setDockOption accepts booleans given as strings, as IPC sends them", () => {
  const state = G.emptyState()
  assert.equal(G.setDockOption(state, "badges", "false").dock.badges, false)
  assert.equal(G.setDockOption(G.setDockOption(state, "badges", false), "badges", "true").dock.badges, true)
})

test("setDockOption ignores an unknown key, an invalid value or no change", () => {
  const state = G.emptyState()
  assert.equal(G.setDockOption(state, "position", "left"), state)
  assert.equal(G.setDockOption(state, "size", "huge"), state)
  assert.equal(G.setDockOption(state, "badges", "maybe"), state)
  assert.equal(G.setDockOption(state, "mode", "pinned"), state)
})

test("parse fills missing dock options from the defaults (a v1 file)", () => {
  const state = plain(G.parse(JSON.stringify({ dock: { mode: "autohide" }, groups: [] })))
  assert.deepEqual(state.dock, { mode: "autohide", size: "m", labels: "off", badges: true, scope: "monitor" })
})

test("parse replaces only the invalid dock options", () => {
  const text = JSON.stringify({ dock: { mode: "pinned", size: "l", labels: 3, badges: "no", scope: "galaxy" } })
  assert.deepEqual(plain(G.parse(text)).dock, { mode: "pinned", size: "l", labels: "off", badges: true, scope: "monitor" })
})
