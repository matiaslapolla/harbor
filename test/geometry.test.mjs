import { test } from "node:test"
import assert from "node:assert/strict"
import { load, plain } from "./load.mjs"

const { fitSize, viewportWidth, windowTileWidth } = load("geometry")

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
