import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "lib/banks.js" as Banks
import "lib/dispatch.js" as Dispatch
import "lib/groups.js" as Groups

// Owns the windows model, the groups and their persistence, and draws one
// dock per screen. The docks and the IPC target call into here.
Item {
  id: root

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/settings"
  readonly property string statePath: stateDir + "/harbor.json"

  property var store: Groups.emptyState()
  property bool loaded: false

  // ---- Hyprland model

  // Toplevel and workspace objects are not deeply reactive; every event bumps this.
  property int revision: 0

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      root.revision++
      if (event.name === "closewindow") root.forgetWindow(event.data)
    }
  }

  readonly property var workspaceList: {
    var _ = root.revision
    var values = Hyprland.workspaces.values
    var list = []
    for (var i = 0; i < values.length; i++) {
      list.push({ id: values[i].id, monitor: values[i].monitor ? values[i].monitor.name : null })
    }
    return list
  }

  // Every live window, special workspaces and not-yet-placed ones included.
  // Group membership is checked against this, never against `windows`.
  readonly property var liveAddresses: {
    var _ = root.revision
    var values = Hyprland.toplevels.values
    var list = []
    for (var i = 0; i < values.length; i++) {
      var address = Dispatch.normalizeAddress(values[i].address)
      if (address) list.push(address)
    }
    return list
  }

  // Windows on regular workspaces. A string only notifies when its value
  // changes, so dock tiles survive events that do not touch them.
  readonly property string windowsJson: {
    var _ = root.revision
    var values = Hyprland.toplevels.values
    var list = []
    for (var i = 0; i < values.length; i++) {
      var t = values[i]
      var address = Dispatch.normalizeAddress(t.address)
      if (!address || !t.workspace || t.workspace.id <= 0) continue
      var ipc = t.lastIpcObject || {}
      list.push({
        address: address,
        appClass: String((t.wayland && t.wayland.appId) || ipc.class || ""),
        title: String(t.title || ipc.title || ""),
        workspaceId: t.workspace.id,
        monitor: t.workspace.monitor ? t.workspace.monitor.name : ""
      })
    }
    list.sort(function(a, b) { return a.workspaceId - b.workspaceId || (a.address < b.address ? -1 : 1) })
    return JSON.stringify(list)
  }
  readonly property var windows: JSON.parse(root.windowsJson)

  readonly property var groups: root.store.groups
  readonly property string dockMode: root.store.dock.mode

  readonly property string activeAddress: {
    var _ = root.revision
    var active = Hyprland.activeToplevel
    return active ? Dispatch.normalizeAddress(active.address) : ""
  }

  function windowFor(address) {
    for (var i = 0; i < root.windows.length; i++) if (root.windows[i].address === address) return root.windows[i]
    return null
  }

  function groupFor(id) {
    for (var i = 0; i < root.store.groups.length; i++) if (root.store.groups[i].id === id) return root.store.groups[i]
    return null
  }

  function liveMembers(group) {
    var members = []
    for (var i = 0; i < group.members.length; i++) {
      var w = root.windowFor(group.members[i])
      if (w) members.push(w)
    }
    return members
  }

  function bankLabel(workspaceId) {
    return Banks.labelOf(root.workspaceList, workspaceId)
  }

  // ---- Actions

  function dispatch(command) {
    var argv = Dispatch.argv(command)
    if (argv.length) Quickshell.execDetached(argv)
  }

  function focusWindow(address) { root.dispatch(Dispatch.focusWindow(address)) }
  function closeWindow(address) { root.dispatch(Dispatch.closeWindow(address)) }
  function moveWindow(address, workspaceId) { root.dispatch(Dispatch.moveWindow(address, workspaceId)) }

  function moveGroup(id, workspaceId) {
    var group = root.groupFor(id)
    if (!group) return
    var members = root.liveMembers(group)
    for (var i = 0; i < members.length; i++) root.moveWindow(members[i].address, workspaceId)
  }

  // First click focuses the first live member; each next click the one after.
  function focusGroup(id) {
    var group = root.groupFor(id)
    if (!group) return
    var members = root.liveMembers(group)
    if (members.length === 0) return
    var activeIndex = -1
    for (var i = 0; i < members.length; i++) if (members[i].address === root.activeAddress) activeIndex = i
    root.focusWindow(members[(activeIndex + 1) % members.length].address)
  }

  function apply(next) {
    if (next === root.store) return
    root.store = next
    saveTimer.restart()
  }

  function createGroup(name, address) {
    var result = Groups.createGroup(root.store, name, Dispatch.normalizeAddress(address))
    root.apply(result.state)
    return result.id
  }

  function addToGroup(id, address) { root.apply(Groups.addMember(root.store, id, Dispatch.normalizeAddress(address))) }
  function removeFromGroup(id, address) { root.apply(Groups.removeMember(root.store, id, Dispatch.normalizeAddress(address))) }
  function renameGroup(id, name) { root.apply(Groups.renameGroup(root.store, id, name)) }
  function deleteGroup(id) { root.apply(Groups.deleteGroup(root.store, id)) }
  function setDockMode(mode) { root.apply(Groups.setDockMode(root.store, mode)) }
  function groupsOf(address) { return Groups.groupsOf(root.store, address) }

  function forgetWindow(address) {
    var addr = Dispatch.normalizeAddress(String(address).split(",")[0])
    var next = root.store
    var groups = Groups.groupsOf(next, addr)
    for (var i = 0; i < groups.length; i++) next = Groups.removeMember(next, groups[i].id, addr)
    root.apply(next)
  }

  // ---- Persistence

  Process {
    running: true
    command: ["mkdir", "-p", root.stateDir]
    onExited: function() { stateFile.path = root.statePath }
  }

  FileView {
    id: stateFile
    printErrors: false
    onLoaded: {
      var raw = text()
      try {
        JSON.parse(raw)
      } catch (e) {
        // Keep a hand-edited file that no longer parses; the next save would overwrite it.
        if (raw.trim() !== "") Quickshell.execDetached(["cp", root.statePath, root.statePath + ".invalid"])
      }
      root.store = Groups.parse(raw)
      root.loaded = true
      startupPrune.restart()
    }
    onLoadFailed: {
      root.loaded = true
      startupPrune.restart()
    }
  }

  // Windows closed while the shell was down. Toplevels arrive after startup,
  // so wait for them and never prune against an empty list.
  Timer {
    id: startupPrune
    interval: 2500
    onTriggered: if (root.liveAddresses.length > 0) root.apply(Groups.prune(root.store, root.liveAddresses))
  }

  Timer {
    id: saveTimer
    interval: 300
    onTriggered: if (root.loaded) stateFile.setText(Groups.serialize(root.store))
  }

  // ---- Surfaces and IPC

  Variants {
    model: Quickshell.screens
    Dock {
      required property var modelData
      screen: modelData
      service: root
    }
  }

  IpcHandler {
    target: "harbor"

    function groups(): string { return JSON.stringify(root.store.groups) }
    function windows(): string { return JSON.stringify(root.windows) }
    function createGroup(name: string, address: string): string { return root.createGroup(name, address) }
    function addToGroup(id: string, address: string): void { root.addToGroup(id, address) }
    function removeFromGroup(id: string, address: string): void { root.removeFromGroup(id, address) }
    function renameGroup(id: string, name: string): void { root.renameGroup(id, name) }
    function deleteGroup(id: string): void { root.deleteGroup(id) }
    function moveWindow(address: string, workspace: int): void { root.moveWindow(address, workspace) }
    function moveGroup(id: string, workspace: int): void { root.moveGroup(id, workspace) }
    function setDockMode(mode: string): void { root.setDockMode(mode) }
  }
}
