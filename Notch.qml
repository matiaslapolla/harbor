import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "lib/dispatch.js" as Dispatch
import "lib/geometry.js" as Geometry

// The surface that hangs from the bar's bottom border: one fixed-width card
// per window of a workspace, in a row you can drag. It is a full-width layer
// under the bar's exclusive zone; the input mask is the notch alone.
PanelWindow {
  id: root

  property bool livePreview: true
  property int cardWidth: 220
  property int visibleCards: 3
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
    cards.contentX = 0
    if (!retarget) root.refresh()
    root.shown = true
  }

  function dismiss() {
    root.shown = false
  }

  // ---- Data: live clients from hyprctl

  property var clients: []
  readonly property var focusedAddress: {
    var _ = root.revision
    var active = Hyprland.activeToplevel
    return active ? Dispatch.normalizeAddress(active.address) : ""
  }

  // Left to right, in screen order.
  readonly property var workspaceClients: root.clients.filter(function(c) {
    return c.workspace && c.workspace.id === root.workspaceId && c.mapped !== false && c.hidden !== true
  }).sort(function(a, b) { return a.at[0] - b.at[0] || a.at[1] - b.at[1] })

  readonly property int cardSpacing: Style.space(8)
  readonly property int captureHeight: Math.round(root.cardWidth * 0.62)

  function refresh() {
    clientsProc.running = false
    clientsProc.running = true
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
    readonly property real contentWidth: cards.width

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
      spacing: Style.space(6)

      Flickable {
        id: cards
        width: Geometry.viewportWidth(root.workspaceClients.length, root.cardWidth, root.visibleCards, root.cardSpacing)
        height: cardRow.height
        contentWidth: cardRow.width
        contentHeight: cardRow.height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // The vertical wheel scrolls the row sideways.
        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            var delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
            var max = Math.max(0, cards.contentWidth - cards.width)
            cards.contentX = Math.max(0, Math.min(max, cards.contentX - delta))
          }
        }

        Row {
          id: cardRow
          spacing: root.cardSpacing

          Rectangle {
            visible: root.workspaceClients.length === 0
            width: root.cardWidth
            height: root.captureHeight + Style.space(28)
            radius: Style.space(8)
            color: Util.alpha(Color.foreground, 0.05)
            border.width: 1
            border.color: Util.alpha(Color.foreground, 0.1)

            Text {
              anchors.centerIn: parent
              text: "Empty"
              color: Util.alpha(Color.popups.text, 0.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.focusWorkspace(root.workspaceId)
            }
          }

          Repeater {
            model: root.workspaceClients

            Rectangle {
              id: card
              required property var modelData
              readonly property string address: Dispatch.normalizeAddress(modelData.address)
              readonly property var toplevel: root.livePreview && root.shown ? root.toplevelFor(address) : null
              readonly property bool active: address === root.focusedAddress
              readonly property var fit: Geometry.fitSize(modelData.size ? modelData.size[0] : 0,
                modelData.size ? modelData.size[1] : 0, root.cardWidth - Style.space(8), root.captureHeight - Style.space(8))

              width: root.cardWidth
              height: root.captureHeight + Style.space(28)
              radius: Style.space(8)
              color: cardMouse.containsMouse ? Util.alpha(Color.foreground, 0.1) : Util.alpha(Color.foreground, 0.05)
              border.width: card.active ? 2 : 1
              border.color: card.active ? Color.accent : Util.alpha(Color.foreground, cardMouse.containsMouse ? 0.3 : 0.12)

              Item {
                id: captureBox
                width: parent.width
                height: root.captureHeight

                ScreencopyView {
                  id: capture
                  anchors.centerIn: parent
                  width: card.fit.width
                  height: card.fit.height
                  captureSource: card.toplevel && card.toplevel.wayland ? card.toplevel.wayland : null
                  live: root.shown
                  paintCursor: false
                }

                AppIcon {
                  anchors.centerIn: parent
                  visible: !capture.hasContent
                  appClass: card.modelData.class || ""
                  size: Math.round(root.captureHeight * 0.4)
                }
              }

              Row {
                anchors.top: captureBox.bottom
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                spacing: Style.space(6)

                AppIcon {
                  anchors.verticalCenter: parent.verticalCenter
                  appClass: card.modelData.class || ""
                  size: Style.space(16)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: root.cardWidth - Style.space(38)
                  height: Style.space(24)
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                  text: card.modelData.title || card.modelData.class || ""
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
              }

              MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusWindow(card.address)
              }
            }
          }
        }
      }

      // Scroll position, only when the row overflows.
      Rectangle {
        visible: cards.contentWidth > cards.width
        width: cards.width
        height: Style.space(3)
        radius: height / 2
        color: Util.alpha(Color.foreground, 0.08)

        Rectangle {
          x: cards.visibleArea.xPosition * parent.width
          width: Math.max(Style.space(16), cards.visibleArea.widthRatio * parent.width)
          height: parent.height
          radius: height / 2
          color: Util.alpha(Color.foreground, 0.4)
        }
      }
    }
  }
}
