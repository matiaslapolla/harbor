import { test } from "node:test"
import assert from "node:assert/strict"
import { load, plain } from "./load.mjs"

const { logicalSize, previewSize, windowRect } = load("geometry")

const ultrawide = { x: 0, y: 0, width: 3440, height: 1440, scale: 1, transform: 0 }
const scaled = { x: 3440, y: 0, width: 2560, height: 1440, scale: 1.25, transform: 0 }
const portrait = { x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 1 }

test("logicalSize divides by scale and swaps for 90/270 degree transforms", () => {
  assert.deepEqual(plain(logicalSize(scaled)), { width: 2048, height: 1152 })
  assert.deepEqual(plain(logicalSize(portrait)), { width: 1080, height: 1920 })
  assert.deepEqual(plain(logicalSize({ ...portrait, transform: 5 })), { width: 1080, height: 1920 })
})

test("previewSize fits the monitor's aspect inside the box", () => {
  const size = plain(previewSize(ultrawide, 430, 240))
  assert.equal(size.width, 430)
  assert.equal(size.height, 180)
  assert.equal(size.factor, 430 / 3440)
})

test("previewSize is height-bound for a portrait monitor", () => {
  const size = plain(previewSize(portrait, 430, 240))
  assert.equal(size.height, 240)
  assert.equal(size.width, 135)
})

test("previewSize falls back to 16:9 when the monitor is unknown", () => {
  const size = plain(previewSize(null, 320, 400))
  assert.equal(size.width, 320)
  assert.equal(size.height, 180)
})

test("windowRect maps global coordinates into the preview", () => {
  const client = { at: [3440 + 1024, 100], size: [1024, 500] }
  assert.deepEqual(plain(windowRect(client, scaled, 0.1)), { x: 102, y: 10, width: 102, height: 50 })
})

test("windowRect clamps a window hanging off the monitor", () => {
  const client = { at: [-200, 1300], size: [800, 400] }
  assert.deepEqual(plain(windowRect(client, ultrawide, 0.1)), { x: 0, y: 130, width: 60, height: 14 })
})

test("windowRect returns null for a client without geometry", () => {
  assert.equal(windowRect({}, ultrawide, 0.1), null)
})
