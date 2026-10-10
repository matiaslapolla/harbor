import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "lib/dispatch.js" as Dispatch
import "lib/geometry.js" as Geometry

// The surface that hangs from the bar's bottom border: a to-scale preview of
// one workspace and a row with an icon per window on it. It is a full-width
// layer under the bar's exclusive zone; the input mask is the notch alone.
PanelWindow {
  id: root

  property bool livePreview: true
  property int previewWidth: 420
  property int revision: 0

  property int workspaceId: -1
  property real centerX: 0
  property bool shown: false
  readonly property bool hovered: notchHover.hovered

  signal focusWorkspace(int id)
  signal focusWindow(string address)

  function present(id, x) {
    var retarget = root.shown
    root.workspaceId = id
    body.glide = retarget
    root.centerX = x
    if (!retarget) root.refresh()
    root.shown = true
  }

  function dismiss() {
    root.shown = false
  }

  // ---- Data: monitor geometry and live clients from hyprctl

  property var monitorInfo: null
  property var clients: []
  readonly property var focusedAddress: {
    var _ = root.revision
    var active = Hyprland.activeToplevel
    return active ? Dispatch.normalizeAddress(active.address) : ""
  }

  readonly property var workspaceClients: {
    var list = root.clients.filter(function(c) {
      return c.workspace && c.workspace.id === root.workspaceId && c.mapped !== false && c.hidden !== true
    })
    // Least recently focused first, so the paint order matches the stacking.
    list.sort(function(a, b) { return (b.focusHistoryID || 0) - (a.focusHistoryID || 0) })
    return list
  }

  readonly property var rowClients: root.workspaceClients.slice().sort(function(a, b) {
    return a.at[0] - b.at[0] || a.at[1] - b.at[1]
  })

  readonly property var preview: Geometry.previewSize(root.monitorInfo, root.previewWidth, Math.round(root.previewWidth * 0.62))

  function refresh() {
    clientsProc.running = false
    clientsProc.running = true
    monitorsProc.running = false
    monitorsProc.running = true
  }

  function toplevelFor(address) {
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      if (Dispatch.normalizeAddress(values[i].address) === address) return values[i]
    }
    return null
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.clients = JSON.parse(text) } catch (e) {}
      }
    }
  }

  Process {
    id: monitorsProc
    command: ["hyprctl", "-j", "monitors"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var monitors = JSON.parse(text)
          for (var i = 0; i < monitors.length; i++) {
            if (root.screen && monitors[i].name === root.screen.name) root.monitorInfo = monitors[i]
          }
        } catch (e) {}
      }
    }
  }

  readonly property var clientEvents: ["openwindow", "closewindow", "movewindowv2", "activewindowv2",
    "changefloatingmode", "fullscreen", "resizewindow"]

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (root.shown && event && root.clientEvents.indexOf(event.name) !== -1) refreshDebounce.restart()
    }
  }

  Timer {
    id: refreshDebounce
    interval: 60
    onTriggered: root.refresh()
  }

  // ---- Window

  anchors { top: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  implicitHeight: body.height + Style.space(24)
  color: "transparent"
  visible: root.shown || body.reveal > 0
  WlrLayershell.namespace: "harbor-notch"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region { item: root.shown ? body : noInput }

  Item { id: noInput; width: 0; height: 0 }

  Item {
    id: body

    readonly property int fillet: Style.space(14)
    readonly property int radius: Math.max(Style.space(14), Style.cornerRadius)
    readonly property int pad: Style.space(12)
    readonly property real contentWidth: Math.max(root.preview.width, appRow.implicitWidth)

    property bool glide: false
    // 0 = tucked under the bar, 1 = fully out.
    property real reveal: root.shown ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    width: contentWidth + pad * 2 + fillet * 2
    height: content.implicitHeight + pad * 2
    x: Math.round(Math.max(0, Math.min(root.width - width, root.centerX - width / 2)))
    y: Math.round(-height * (1 - reveal))
    opacity: Math.min(1, reveal * 1.6)

    Behavior on x {
      enabled: body.glide
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    HoverHandler { id: notchHover }

    // Square top that flares into the bar, rounded bottom.
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: -1
        fillColor: Color.popups.background
        startX: 0; startY: 0
        PathArc { x: body.fillet; y: body.fillet; radiusX: body.fillet; radiusY: body.fillet }
        PathLine { x: body.fillet; y: body.height - body.radius }
        PathArc { x: body.fillet + body.radius; y: body.height; radiusX: body.radius; radiusY: body.radius; direction: PathArc.Counterclockwise }
        PathLine { x: body.width - body.fillet - body.radius; y: body.height }
        PathArc { x: body.width - body.fillet; y: body.height - body.radius; radiusX: body.radius; radiusY: body.radius; direction: PathArc.Counterclockwise }
        PathLine { x: body.width - body.fillet; y: body.fillet }
        PathArc { x: body.width; y: 0; radiusX: body.fillet; radiusY: body.fillet }
        PathLine { x: 0; y: 0 }
      }

      ShapePath {
        strokeWidth: Math.max(1, Style.space(1))
        strokeColor: Util.alpha(Color.popups.border, 0.55)
        fillColor: "transparent"
        startX: 0; startY: 0
        PathArc { x: body.fillet; y: body.fillet; radiusX: body.fillet; radiusY: body.fillet }
        PathLine { x: body.fillet; y: body.height - body.radius }
        PathArc { x: body.fillet + body.radius; y: body.height; radiusX: body.radius; radiusY: body.radius; direction: PathArc.Counterclockwise }
        PathLine { x: body.width - body.fillet - body.radius; y: body.height }
        PathArc { x: body.width - body.fillet; y: body.height - body.radius; radiusX: body.radius; radiusY: body.radius; direction: PathArc.Counterclockwise }
        PathLine { x: body.width - body.fillet; y: body.fillet }
        PathArc { x: body.width; y: 0; radiusX: body.fillet; radiusY: body.fillet }
      }
    }

    Column {
      id: content
      x: body.fillet + body.pad
      y: body.pad
      width: body.contentWidth
      spacing: Style.space(10)

      Rectangle {
        id: previewBox
        width: root.preview.width
        height: root.preview.height
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Style.space(6)
        color: Util.alpha(Color.foreground, 0.05)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.1)
        clip: true

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusWorkspace(root.workspaceId)
        }

        Text {
          anchors.centerIn: parent
          visible: root.workspaceClients.length === 0
          text: "Empty"
          color: Util.alpha(Color.popups.text, 0.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        Repeater {
          model: root.workspaceClients

          Rectangle {
            id: tile
            required property var modelData
            readonly property var rect: root.monitorInfo
              ? Geometry.windowRect(modelData, root.monitorInfo, root.preview.factor) : null
            readonly property string address: Dispatch.normalizeAddress(modelData.address)
            readonly property var toplevel: root.livePreview && root.shown ? root.toplevelFor(address) : null
            readonly property bool active: address === root.focusedAddress

            visible: rect !== null
            x: rect ? rect.x : 0
            y: rect ? rect.y : 0
            width: rect ? rect.width : 0
            height: rect ? rect.height : 0
            radius: Style.space(3)
            color: Util.alpha(Color.background, 0.85)
            border.width: active || tileMouse.containsMouse ? 2 : 1
            border.color: active || tileMouse.containsMouse ? Color.accent : Util.alpha(Color.foreground, 0.25)
            clip: true

            ScreencopyView {
              id: capture
              anchors.fill: parent
              anchors.margins: 1
              captureSource: tile.toplevel && tile.toplevel.wayland ? tile.toplevel.wayland : null
              live: root.shown
              paintCursor: false
            }

            AppIcon {
              anchors.centerIn: parent
              visible: !capture.hasContent
              appClass: tile.modelData.class || ""
              size: Math.max(12, Math.min(32, Math.min(tile.width, tile.height) * 0.45))
            }

            MouseArea {
              id: tileMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.focusWindow(tile.address)
            }
          }
        }
      }

      Row {
        id: appRow
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)
        visible: root.rowClients.length > 0

        Repeater {
          model: root.rowClients

          Item {
            id: slot
            required property var modelData
            readonly property string address: Dispatch.normalizeAddress(modelData.address)
            readonly property int iconSize: Style.space(30)

            width: iconSize + Style.space(8)
            height: iconSize + Style.space(10)

            Rectangle {
              anchors.fill: parent
              radius: Style.space(8)
              color: slotMouse.containsMouse ? Util.alpha(Color.foreground, 0.1) : "transparent"
            }

            AppIcon {
              anchors.horizontalCenter: parent.horizontalCenter
              y: Style.space(2)
              appClass: slot.modelData.class || ""
              size: slot.iconSize
              scale: slotMouse.containsMouse ? 1.1 : 1
              Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              width: Style.space(4)
              height: width
              radius: width / 2
              color: slot.address === root.focusedAddress ? Color.accent : Util.alpha(Color.foreground, 0.35)
            }

            MouseArea {
              id: slotMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.focusWindow(slot.address)
            }
          }
        }
      }
    }
  }
}
