import { test } from "node:test"
import assert from "node:assert/strict"
import { load, plain } from "./load.mjs"

const { fitSize, viewportWidth } = load("geometry")

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
