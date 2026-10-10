import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// The dock for one screen: groups on the left, then the windows on this
// monitor that belong to no group. The window is taller than the dock so
// the menu and tooltips have room above it; input is masked to what shows.
PanelWindow {
  id: root

  property var service: null

  readonly property string monitorName: root.screen ? root.screen.name : ""
  readonly property bool pinned: !root.service || root.service.store.dock.mode === "pinned"
  property bool revealed: false
  readonly property bool showDock: root.pinned || root.revealed || menu.open

  readonly property int iconSize: Style.space(32)
  readonly property int tileSize: iconSize + Style.space(14)
  readonly property int dockPad: Style.space(6)
  readonly property int dockHeight: tileSize + dockPad * 2
  readonly property int bottomGap: Style.gapsOut
  readonly property int edgeZone: 4

  readonly property var groups: root.service ? root.service.store.groups : []
  readonly property var looseWindows: {
    if (!root.service) return []
    var service = root.service
    return service.windows.filter(function(w) {
      return w.monitor === root.monitorName && service.groupsOf(w.address).length === 0
    })
  }

  anchors { bottom: true; left: true; right: true }
  implicitHeight: root.dockHeight + root.bottomGap + Style.space(460)
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: root.pinned ? root.dockHeight + root.bottomGap : 0
  color: "transparent"
  WlrLayershell.namespace: "harbor-dock"
  WlrLayershell.layer: WlrLayer.Top
  // OnDemand, not Exclusive: switching to exclusive focus clears the focus grab.
  WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region { item: menu.open ? contentRoot : (root.showDock ? dockBox : edgeStrip) }

  function openMenu(kind, key, tile) {
    var p = contentRoot.mapFromItem(tile, tile.width / 2, 0)
    menu.anchorX = p.x
    menu.show(kind, key)
  }

  HyprlandFocusGrab {
    active: menu.open
    windows: [root]
    onCleared: menu.close()
  }

  Timer {
    id: hideTimer
    interval: 450
    onTriggered: if (!dockHover.hovered && !menu.open) root.revealed = false
  }

  Item {
    id: contentRoot
    anchors.fill: parent

    // Clicks on the transparent area while the menu is open dismiss it.
    MouseArea {
      anchors.fill: parent
      enabled: menu.open
      acceptedButtons: Qt.AllButtons
      onClicked: menu.close()
    }

    Rectangle {
      id: dockBox

      readonly property real restY: contentRoot.height - root.bottomGap - height
      // 0 = shown, 1 = slid past the bottom edge.
      property real slide: root.showDock ? 0 : 1
      Behavior on slide { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      width: Math.max(root.tileSize, dockRow.implicitWidth) + root.dockPad * 2
      height: root.dockHeight
      x: Math.round((contentRoot.width - width) / 2)
      y: restY + (root.dockHeight + root.bottomGap) * slide
      opacity: 1 - slide
      visible: slide < 0.99
      radius: Math.max(Style.space(14), Style.cornerRadius)
      color: Color.popups.background
      border.width: 1
      border.color: Util.alpha(Color.popups.border, 0.45)

      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      HoverHandler {
        id: dockHover
        onHoveredChanged: {
          if (hovered) hideTimer.stop()
          else if (!root.pinned) hideTimer.restart()
        }
      }

      Row {
        id: dockRow
        anchors.centerIn: parent
        spacing: Style.space(4)

        Repeater {
          model: root.groups

          GroupTile {
            required property var modelData
            group: modelData
          }
        }

        Rectangle {
          visible: root.groups.length > 0 && root.looseWindows.length > 0
          width: 1
          height: root.iconSize
          anchors.verticalCenter: parent.verticalCenter
          color: Util.alpha(Color.foreground, 0.18)
        }

        Repeater {
          model: root.looseWindows

          WindowTile {
            required property var modelData
            win: modelData
          }
        }

        Text {
          visible: root.groups.length === 0 && root.looseWindows.length === 0
          height: root.tileSize
          verticalAlignment: Text.AlignVCenter
          leftPadding: Style.space(10)
          rightPadding: Style.space(10)
          text: "No windows"
          color: Util.alpha(Color.popups.text, 0.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }
    }

    Item {
      id: edgeStrip
      anchors.bottom: parent.bottom
      width: parent.width
      height: root.edgeZone

      HoverHandler {
        onHoveredChanged: {
          if (hovered && !root.pinned) {
            hideTimer.stop()
            root.revealed = true
          }
        }
      }
    }

    Rectangle {
      id: tooltip
      property string text: ""
      property real centerX: 0
      visible: text !== "" && !menu.open && root.showDock
      width: Math.min(Style.space(360), tipLabel.implicitWidth + Style.space(16))
      height: tipLabel.implicitHeight + Style.space(10)
      x: Math.round(Math.max(Style.space(8), Math.min(contentRoot.width - width - Style.space(8), centerX - width / 2)))
      y: dockBox.y - height - Style.space(8)
      radius: Style.space(6)
      color: Color.tooltip.background
      border.width: 1
      border.color: Util.alpha(Color.tooltip.border, 0.4)

      Text {
        id: tipLabel
        anchors.centerIn: parent
        width: Math.min(implicitWidth, Style.space(344))
        text: tooltip.text
        elide: Text.ElideRight
        color: Color.tooltip.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    DockMenu {
      id: menu
      service: root.service
      monitorName: root.monitorName
      bottomY: dockBox.restY - Style.space(8)
      maxX: contentRoot.width
    }
  }

  function showTip(tile, text) {
    tooltip.centerX = contentRoot.mapFromItem(tile, tile.width / 2, 0).x
    tooltip.text = text
  }

  function hideTip(text) {
    if (tooltip.text === text) tooltip.text = ""
  }

  component WindowTile: Item {
    id: tile
    property var win: null
    readonly property bool active: root.service && tile.win.address === root.service.activeAddress
    readonly property string tip: tile.win.title || tile.win.appClass

    width: root.tileSize
    height: root.tileSize

    Rectangle {
      anchors.fill: parent
      radius: Style.space(10)
      color: tileMouse.containsMouse ? Util.alpha(Color.foreground, 0.1) : "transparent"
    }

    AppIcon {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -Style.space(2)
      appClass: tile.win.appClass
      size: root.iconSize
      scale: tileMouse.containsMouse ? 1.08 : 1
      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Rectangle {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(2)
      width: Math.max(height, badgeLabel.implicitWidth + Style.space(6))
      height: Style.space(15)
      radius: height / 2
      color: Util.alpha(Color.background, 0.9)
      border.width: 1
      border.color: Util.alpha(Color.foreground, 0.25)

      Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.service ? root.service.bankLabel(tile.win.workspaceId) : ""
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      width: tile.active ? Style.space(12) : Style.space(4)
      height: Style.space(4)
      radius: height / 2
      color: tile.active ? Color.accent : Util.alpha(Color.foreground, 0.35)
      Behavior on width { NumberAnimation { duration: 140 } }
    }

    MouseArea {
      id: tileMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: containsMouse ? root.showTip(tile, tile.tip) : root.hideTip(tile.tip)
      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) root.service.focusWindow(tile.win.address)
        else if (mouse.button === Qt.MiddleButton) root.service.closeWindow(tile.win.address)
        else root.openMenu("window", tile.win.address, tile)
      }
    }
  }

  component GroupTile: Rectangle {
    id: groupTile
    property var group: null
    readonly property var members: root.service ? root.service.liveMembers(groupTile.group) : []
    readonly property bool active: {
      if (!root.service) return false
      for (var i = 0; i < members.length; i++) if (members[i].address === root.service.activeAddress) return true
      return false
    }
    readonly property string tip: groupTile.group.name + " · " + members.length + (members.length === 1 ? " window" : " windows")

    width: groupRow.implicitWidth + Style.space(16)
    height: root.tileSize
    radius: Style.space(10)
    color: groupMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : Util.alpha(Color.foreground, 0.06)
    border.width: 1
    border.color: groupTile.active ? Util.alpha(Color.accent, 0.8) : Util.alpha(Color.foreground, 0.14)

    Row {
      id: groupRow
      anchors.centerIn: parent
      spacing: Style.space(8)

      Item {
        readonly property int shown: Math.min(3, groupTile.members.length)
        width: shown === 0 ? root.iconSize * 0.8 : root.iconSize * 0.8 + (shown - 1) * root.iconSize * 0.42
        height: root.iconSize * 0.8
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: groupTile.members.slice(0, 3)

          AppIcon {
            required property var modelData
            required property int index
            x: index * root.iconSize * 0.42
            z: 3 - index
            appClass: modelData.appClass
            size: Math.round(root.iconSize * 0.8)
          }
        }

        Rectangle {
          visible: groupTile.members.length === 0
          anchors.fill: parent
          radius: width * 0.28
          color: "transparent"
          border.width: 1
          border.color: Util.alpha(Color.foreground, 0.3)
        }
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: groupTile.group.name
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
          width: Math.min(implicitWidth, Style.space(140))
        }

        Text {
          text: groupTile.members.length + (groupTile.members.length === 1 ? " window" : " windows")
          color: Util.alpha(Color.popups.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }

    MouseArea {
      id: groupMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: containsMouse ? root.showTip(groupTile, groupTile.tip) : root.hideTip(groupTile.tip)
      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) root.service.focusGroup(groupTile.group.id)
        else root.openMenu("group", groupTile.group.id, groupTile)
      }
    }
  }
}
