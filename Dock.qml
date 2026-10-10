import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import "lib/groups.js" as Groups

// The dock for one screen: groups on the left, then the windows on this
// monitor that belong to no group. The window is taller than the dock so
// the menu and tooltips have room above it; input is masked to what shows.
PanelWindow {
  id: root

  property var service: null

  readonly property string monitorName: root.screen ? root.screen.name : ""
  readonly property var dock: root.service ? root.service.dock : Groups.defaultDock()
  readonly property bool pinned: root.dock.mode === "pinned"
  property bool revealed: false
  readonly property bool showDock: root.pinned || root.revealed || menu.open

  readonly property int iconSize: Style.space(({ s: 24, m: 32, l: 40, xl: 48 })[root.dock.size] || 32)
  readonly property int tileSize: iconSize + Style.space(14)
  readonly property bool labeled: root.dock.labels !== "off"
  readonly property int tileHeight: tileSize + (root.labeled ? Style.space(16) : 0)
  readonly property int windowTileWidth: root.dock.labels === "title" ? Math.max(Math.round(tileSize * 2.4), Style.space(110))
    : root.labeled ? Math.max(Math.round(tileSize * 1.7), Style.space(72))
    : tileSize
  readonly property int dockPad: Style.space(6)
  readonly property int dockHeight: tileHeight + dockPad * 2
  readonly property int bottomGap: Style.gapsOut
  readonly property int edgeZone: 4

  readonly property var groups: root.service ? root.service.groups : []
  readonly property int activeWorkspaceId: {
    var _ = root.service ? root.service.revision : 0
    var monitor = root.screen ? Hyprland.monitorFor(root.screen) : null
    return monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
  }

  readonly property var looseWindows: {
    if (!root.service) return []
    var service = root.service
    var onlyActive = root.dock.scope === "workspace"
    return service.windows.filter(function(w) {
      return w.monitor === root.monitorName && service.groupsOf(w.address).length === 0
        && (!onlyActive || w.workspaceId === root.activeWorkspaceId)
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

  // Runs whenever a revealed dock is left alone, however the pointer got
  // there: off the dock, off the edge strip, or after the menu closed.
  Timer {
    interval: 450
    running: root.revealed && !dockHover.hovered && !menu.open
    onTriggered: root.revealed = false
  }

  function windowCount(n) {
    return n + (n === 1 ? " window" : " windows")
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

      HoverHandler { id: dockHover }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: root.openMenu("dock", "", dockBox)
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
          height: root.tileHeight
          verticalAlignment: Text.AlignVCenter
          leftPadding: Style.space(10)
          rightPadding: Style.space(10)
          text: "No windows"
          color: Util.alpha(Color.popups.text, 0.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        Item {
          id: settingsTile
          width: Math.round(root.iconSize * 0.7)
          height: root.tileHeight

          Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: Style.space(8)
            color: settingsMouse.containsMouse || (menu.open && menu.kind === "dock")
              ? Util.alpha(Color.foreground, 0.12) : "transparent"
          }

          Text {
            anchors.centerIn: parent
            text: "⋯"
            color: Util.alpha(Color.popups.text, settingsMouse.containsMouse ? 0.9 : 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
          }

          MouseArea {
            id: settingsMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openMenu("dock", "", settingsTile)
          }
        }
      }
    }

    Item {
      id: edgeStrip
      anchors.bottom: parent.bottom
      width: parent.width
      height: root.edgeZone

      HoverHandler {
        onHoveredChanged: if (hovered && !root.pinned) root.revealed = true
      }
    }

    Rectangle {
      id: tooltip
      // A destroyed tile clears this by itself, so its tip cannot linger.
      property Item owner: null
      readonly property string text: owner ? owner.tip : ""
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

  function showTip(tile) {
    tooltip.centerX = contentRoot.mapFromItem(tile, tile.width / 2, 0).x
    tooltip.owner = tile
  }

  function hideTip(tile) {
    if (tooltip.owner === tile) tooltip.owner = null
  }

  component WindowTile: Item {
    id: tile
    property var win: null
    readonly property bool active: root.service && tile.win.address === root.service.activeAddress
    readonly property string tip: tile.win.title || tile.win.appClass

    width: root.windowTileWidth
    height: root.tileHeight

    Rectangle {
      anchors.fill: parent
      radius: Style.space(10)
      color: tileMouse.containsMouse ? Util.alpha(Color.foreground, 0.1) : "transparent"
    }

    AppIcon {
      id: tileIcon
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round((root.tileSize - root.iconSize) / 2) - Style.space(2)
      appClass: tile.win.appClass
      size: root.iconSize
      scale: tileMouse.containsMouse ? 1.08 : 1
      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Text {
      visible: root.labeled
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.tileSize - Style.space(4)
      width: parent.width - Style.space(6)
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: root.dock.labels === "title" ? tile.tip : tileIcon.appName
      color: Util.alpha(Color.popups.text, 0.85)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Rectangle {
      visible: root.dock.badges
      anchors.left: tileIcon.right
      anchors.leftMargin: -width * 0.6
      anchors.top: parent.top
      anchors.topMargin: Style.space(2)
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
      onContainsMouseChanged: containsMouse ? root.showTip(tile) : root.hideTip(tile)
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
    readonly property string tip: groupTile.group.name + " · " + root.windowCount(members.length)

    width: groupRow.implicitWidth + Style.space(16)
    height: root.tileHeight
    radius: Style.space(10)
    color: groupMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : Util.alpha(Color.foreground, 0.06)
    border.width: 1
    border.color: groupTile.active ? Util.alpha(Color.accent, 0.8) : Util.alpha(Color.foreground, 0.14)

    Row {
      id: groupRow
      anchors.centerIn: parent
      spacing: Style.space(8)

      Item {
        readonly property int shown: Math.min(4, groupTile.members.length)
        width: shown === 0 ? root.iconSize * 0.8 : root.iconSize * 0.8 + (shown - 1) * root.iconSize * 0.42
        height: root.iconSize * 0.8
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: groupTile.members.slice(0, 4)

          AppIcon {
            required property var modelData
            required property int index
            x: index * root.iconSize * 0.42
            z: 4 - index
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
          text: root.windowCount(groupTile.members.length)
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
      onContainsMouseChanged: containsMouse ? root.showTip(groupTile) : root.hideTip(groupTile)
      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) root.service.focusGroup(groupTile.group.id)
        else root.openMenu("group", groupTile.group.id, groupTile)
      }
    }
  }
}
