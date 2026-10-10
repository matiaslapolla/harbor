import { test } from "node:test"
import assert from "node:assert/strict"
import { load, plain } from "./load.mjs"

const { fitSize, viewportWidth, windowTileWidth, onMonitor } = load("geometry")

test("fitSize fits a wide window by width", () => {
  assert.deepEqual(plain(fitSize(3440, 1440, 220, 136)), { width: 220, height: 92 })
})

test("fitSize fits a tall window by height", () => {
  assert.deepEqual(plain(fitSize(800, 1600, 220, 136)), { width: 68, height: 136 })
})

test("fitSize fills the box when the window has no size", () => {
  assert.deepEqual(plain(fitSize(0, 0, 220, 136)), { width: 220, height: 136 })
  assert.deepEqual(plain(fitSize(undefined, 500, 220, 136)), { width: 220, height: 136 })
})

test("viewportWidth is one card wide for an empty workspace", () => {
  assert.equal(viewportWidth(0, 220, 3, 8), 220)
})

test("viewportWidth fits every card when there are fewer than visible", () => {
  assert.equal(viewportWidth(2, 220, 3, 8), 448)
})

test("viewportWidth caps at the visible cards", () => {
  assert.equal(viewportWidth(7, 220, 3, 8), 676)
})

test("viewportWidth never exceeds the room on screen", () => {
  assert.equal(viewportWidth(6, 400, 6, 8, 1800), 1800)
  assert.equal(viewportWidth(2, 220, 3, 8, 1800), 448)
})

test("viewportWidth keeps at least one card even on a tiny screen", () => {
  assert.equal(viewportWidth(3, 220, 3, 8, 100), 220)
})

test("windowTileWidth is square without labels", () => {
  assert.equal(windowTileWidth("off", 46, 1), 46)
})

test("windowTileWidth widens for app names and more for titles", () => {
  assert.equal(windowTileWidth("app", 46, 1), 78)
  assert.equal(windowTileWidth("title", 46, 1), 110)
  assert.equal(windowTileWidth("title", 62, 1), 149)
})

test("windowTileWidth minimums follow the UI scale", () => {
  assert.equal(windowTileWidth("app", 20, 1.5), 108)
})

// DP-1 on the author's machine: 3440x1440 at scale 1.25 is 2752x1152 logical.
const dp1 = { x: 0, y: 816, width: 3440, height: 1440, scale: 1.25, transform: 0 }

test("onMonitor is true for a window inside the monitor", () => {
  assert.equal(onMonitor({ at: [12, 858], size: [1330, 1098] }, dp1), true)
})

test("onMonitor is true for a window that only peeks in at the edge", () => {
  assert.equal(onMonitor({ at: [2694, 858], size: [1325, 1098] }, dp1), true)
})

test("onMonitor is false for a window a scrolling layout parked off screen", () => {
  assert.equal(onMonitor({ at: [4033, 858], size: [1325, 1098] }, dp1), false)
  assert.equal(onMonitor({ at: [-2611, 858], size: [1330, 1098] }, dp1), false)
})

test("onMonitor uses the rotated size for a portrait monitor", () => {
  const portrait = { x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 1 }
  assert.equal(onMonitor({ at: [100, 1500], size: [500, 300] }, portrait), true)
  assert.equal(onMonitor({ at: [1200, 100], size: [500, 300] }, portrait), false)
})

test("onMonitor assumes on screen when geometry is missing", () => {
  assert.equal(onMonitor({}, dp1), true)
  assert.equal(onMonitor({ at: [0, 0], size: [10, 10] }, null), true)
})
