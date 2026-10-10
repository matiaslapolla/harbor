import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "lib/banks.js" as Banks
import "lib/dispatch.js" as Dispatch

BarWidget {
  id: root
  moduleName: "matiaslapolla.harbor"

  // `omarchy bar set` stores strings unless --json is passed.
  function intSetting(key, fallback, min, max) {
    var n = Number(root.setting(key, fallback))
    return isFinite(n) ? Math.round(Math.min(max, Math.max(min, n))) : fallback
  }

  function boolSetting(key, fallback) {
    var v = root.setting(key, fallback)
    if (typeof v === "boolean") return v
    var s = String(v).trim().toLowerCase()
    if (s === "true" || s === "1" || s === "on") return true
    if (s === "false" || s === "0" || s === "off") return false
    return fallback
  }

  readonly property int count: intSetting("count", Banks.BANK_SIZE, 1, Banks.BANK_SIZE)
  readonly property int hoverDelayMs: intSetting("hoverDelayMs", 180, 0, 1000)
  readonly property bool livePreview: boolSetting("livePreview", true)
  readonly property int previewWidth: intSetting("previewWidth", 420, 240, 800)

  readonly property var screen: root.QsWindow.window ? root.QsWindow.window.screen : null
  readonly property string monitorName: root.screen ? root.screen.name : ""

  // Workspace objects are not deeply reactive; every Hyprland event bumps this.
  property int revision: 0

  // A string only notifies when its value changes, so the Repeater keeps its
  // delegates (and their hover state) across unrelated events.
  readonly property string bankJson: {
    var _ = root.revision
    var values = Hyprland.workspaces.values
    var list = []
    for (var i = 0; i < values.length; i++) {
      list.push({ id: values[i].id, monitor: values[i].monitor ? values[i].monitor.name : null })
    }
    return JSON.stringify(Banks.bankFor(list, root.monitorName, root.count))
  }
  readonly property var bank: JSON.parse(root.bankJson)

  readonly property var occupiedIds: {
    var _ = root.revision
    var ids = ({})
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].workspace) ids[values[i].workspace.id] = true
    }
    return ids
  }

  readonly property int focusedId: {
    var _ = root.revision
    var monitor = root.screen ? Hyprland.monitorFor(root.screen) : null
    return monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
  }

  function dispatch(command) {
    var argv = Dispatch.argv(command)
    if (argv.length) Quickshell.execDetached(argv)
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.revision++ }
  }

  // ---- Hover lifecycle shared by the strip and the notch

  property int hoveredId: -1
  property Item hoveredButton: null
  readonly property bool stripHovered: root.hoveredButton !== null

  // The notch spans the whole screen; a floating bar is inset by its side
  // margins, assumed equal on both sides.
  function buttonCenterX(button) {
    var win = root.QsWindow.window
    if (!button || !win) return 0
    var inset = root.screen ? Math.max(0, (root.screen.width - win.width) / 2) : 0
    return win.contentItem.mapFromItem(button, button.width / 2, 0).x + inset
  }

  function showNotch() {
    var slot = null
    for (var i = 0; i < root.bank.length; i++) if (root.bank[i].id === root.hoveredId) slot = root.bank[i]
    if (!slot || !root.hoveredButton) return
    notch.present(slot.id, root.buttonCenterX(root.hoveredButton))
  }

  function enterButton(button, id) {
    closeTimer.stop()
    root.hoveredButton = button
    root.hoveredId = id
    if (notch.shown) root.showNotch()
    else openTimer.restart()
  }

  function leaveButton(button) {
    if (root.hoveredButton === button) root.hoveredButton = null
  }

  // Also fires when the hovered delegate is destroyed (the bank changed under
  // the pointer), which never reports a hover exit.
  onHoveredButtonChanged: {
    if (root.hoveredButton) return
    openTimer.stop()
    closeTimer.restart()
  }

  Timer {
    id: openTimer
    interval: root.hoverDelayMs
    onTriggered: root.showNotch()
  }

  Timer {
    id: closeTimer
    interval: 220
    onTriggered: if (!root.stripHovered && !notch.hovered) notch.dismiss()
  }

  Connections {
    target: notch
    function onHoveredChanged() {
      if (notch.hovered) closeTimer.stop()
      else if (!root.stripHovered) closeTimer.restart()
    }
  }

  readonly property real trailingGap: Style.spaceReal(1.5)

  implicitWidth: row.implicitWidth + trailingGap
  implicitHeight: row.implicitHeight

  RowLayout {
    id: row
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    spacing: Style.space(1)

    Repeater {
      model: root.bank

      WidgetButton {
        id: button
        required property var modelData

        readonly property bool occupied: root.occupiedIds[modelData.id] === true
        readonly property bool focused: root.focusedId === modelData.id

        bar: root.bar
        text: modelData.label
        // No accent on the bar: glass bars (True Glass) key the accent colour out.
        foreground: root.bar ? root.bar.barForeground : Color.foreground
        opacity: focused || occupied ? 1 : 0.45
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: Style.space(22)
        fixedHeight: root.barSize
        onPressed: root.dispatch(Dispatch.focusWorkspace(modelData.id))
        onWheelMoved: function(delta) {
          var next = Banks.neighbour(root.bank, root.focusedId, delta > 0 ? -1 : 1)
          if (next !== -1) root.dispatch(Dispatch.focusWorkspace(next))
        }

        Rectangle {
          z: -1
          anchors.centerIn: parent
          width: parent.width - Style.space(4)
          height: Math.round(root.barSize * 0.62)
          radius: height / 2
          color: Util.alpha(button.foreground, 0.16)
          opacity: button.focused ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Math.round(root.barSize * 0.12)
          width: Style.space(3)
          height: width
          radius: width / 2
          color: button.foreground
          visible: notch.shown && notch.workspaceId === button.modelData.id
        }

        HoverHandler {
          onHoveredChanged: hovered ? root.enterButton(button, button.modelData.id) : root.leaveButton(button)
        }
      }
    }
  }

  Notch {
    id: notch
    screen: root.screen
    livePreview: root.livePreview
    previewWidth: root.previewWidth
    revision: root.revision
    onFocusWorkspace: function(id) { root.dispatch(Dispatch.focusWorkspace(id)) }
    onFocusWindow: function(address) { root.dispatch(Dispatch.focusWindow(address)) }
  }
}
