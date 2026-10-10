import { test } from "node:test"
import assert from "node:assert/strict"
import { load, plain } from "./load.mjs"

const { bankFor, labelFor, neighbour, banksByMonitor } = load("banks")

const workspaces = [
  { id: 12, monitor: "HDMI-A-1" },
  { id: 2, monitor: "DP-1" },
  { id: 1, monitor: "DP-1" },
  { id: 11, monitor: "HDMI-A-1" },
  { id: -98, monitor: "DP-1" },
  { id: 3, monitor: null },
]

test("bankFor keeps the monitor's positive workspaces in id order", () => {
  assert.deepEqual(plain(bankFor(workspaces, "DP-1", 10)), [
    { id: 1, number: 1, label: "1" },
    { id: 2, number: 2, label: "2" },
  ])
})

test("bankFor numbers a second monitor's bank from 1", () => {
  assert.deepEqual(plain(bankFor(workspaces, "HDMI-A-1", 10)).map((s) => [s.id, s.label]), [[11, "1"], [12, "2"]])
})

test("bankFor caps the bank at count", () => {
  assert.equal(bankFor(workspaces, "DP-1", 1).length, 1)
})

test("bankFor returns an empty bank for an unknown or missing monitor", () => {
  assert.equal(bankFor(workspaces, "eDP-1", 10).length, 0)
  assert.equal(bankFor(workspaces, "", 10).length, 0)
  assert.equal(bankFor(null, "DP-1", 10).length, 0)
})

test("labelFor shows the tenth workspace as 0, like its key", () => {
  assert.equal(labelFor(1), "1")
  assert.equal(labelFor(9), "9")
  assert.equal(labelFor(10), "0")
})

test("neighbour steps through the bank and wraps", () => {
  const bank = bankFor(workspaces, "DP-1", 10)
  assert.equal(neighbour(bank, 1, 1), 2)
  assert.equal(neighbour(bank, 2, 1), 1)
  assert.equal(neighbour(bank, 1, -1), 2)
  assert.equal(neighbour(bank, 99, 1), 1)
  assert.equal(neighbour([], 1, 1), -1)
})

test("banksByMonitor puts the given monitor first, then the rest by name", () => {
  const banks = plain(banksByMonitor(workspaces, "HDMI-A-1", 10))
  assert.deepEqual(banks.map((b) => b.monitor), ["HDMI-A-1", "DP-1"])
  assert.deepEqual(banks[0].slots.map((s) => s.id), [11, 12])
})
