import { test } from "node:test"
import assert from "node:assert/strict"
import { load, plain } from "./load.mjs"

const D = load("dispatch")

test("normalizeAddress accepts Hyprland addresses with or without 0x", () => {
  assert.equal(D.normalizeAddress("0x5F66716C0530"), "0x5f66716c0530")
  assert.equal(D.normalizeAddress("5f66716c0530"), "0x5f66716c0530")
  assert.equal(D.normalizeAddress('0xaa" }) os.execute("x'), "")
  assert.equal(D.normalizeAddress(null), "")
})

test("focusWorkspace targets a workspace id", () => {
  assert.equal(D.focusWorkspace(11), 'hl.dsp.focus({ workspace = "11" })')
  assert.equal(D.focusWorkspace("3"), 'hl.dsp.focus({ workspace = "3" })')
})

test("focusWindow targets a window by address", () => {
  assert.equal(D.focusWindow("0xaa"), 'hl.dsp.focus({ window = "address:0xaa" })')
})

test("moveWindow is silent", () => {
  assert.equal(D.moveWindow("0xaa", 4),
    'hl.dsp.window.move({ workspace = "4", window = "address:0xaa", follow = false })')
})

test("closeWindow targets a window by address", () => {
  assert.equal(D.closeWindow("0xaa"), 'hl.dsp.window.close({ window = "address:0xaa" })')
})

test("invalid input yields no command instead of a malformed one", () => {
  assert.equal(D.focusWorkspace(0), "")
  assert.equal(D.focusWorkspace("1 }) os.exit() --"), "")
  assert.equal(D.focusWorkspace(2.5), "")
  assert.equal(D.focusWindow("nope"), "")
  assert.equal(D.moveWindow("0xaa", -1), "")
  assert.equal(D.moveWindow("x", 1), "")
  assert.equal(D.closeWindow(""), "")
})

test("argv wraps a command for hyprctl, or is empty for no command", () => {
  assert.deepEqual(plain(D.argv("hl.dsp.focus({ workspace = \"1\" })")),
    ["hyprctl", "dispatch", 'hl.dsp.focus({ workspace = "1" })'])
  assert.deepEqual(plain(D.argv("")), [])
})
