import { readFileSync } from "node:fs"
import vm from "node:vm"

// lib/*.js are QML JavaScript resources: no exports, an optional
// `.pragma library` header. Run them in a fresh context and hand back its globals.
export function load(name) {
  const source = readFileSync(new URL(`../lib/${name}.js`, import.meta.url), "utf8")
    .replace(/^\.pragma library\s*$/m, "")
  const context = vm.createContext({})
  vm.runInContext(source, context, { filename: `lib/${name}.js` })
  return context
}

// Values built inside the vm context carry its realm's prototypes.
export const plain = (value) => JSON.parse(JSON.stringify(value))
