import QtQuick
import qs.Commons
import "lib/banks.js" as Banks

// Context menu for a dock tile. Kind "window" targets a window address,
// kind "group" a group id. It sits above the dock, centered on the tile.
Rectangle {
  id: root

  property var service: null
  property string monitorName: ""
  property real anchorX: 0
  property real bottomY: 0
  property real maxX: 0

  property bool open: false
  property string kind: ""
  property string key: ""
  // "", "new" (name a new group) or "rename"
  property string editing: ""

  readonly property var targetWindow: root.service && root.kind === "window" ? root.service.windowFor(root.key) : null
  readonly property var targetGroup: root.service && root.kind === "group" ? root.service.groupFor(root.key) : null
  readonly property var memberOf: root.targetWindow ? root.service.groupsOf(root.targetWindow.address) : []
  readonly property var otherGroups: {
    if (!root.targetWindow) return []
    var mine = root.memberOf.map(function(g) { return g.id })
    return root.service.store.groups.filter(function(g) { return mine.indexOf(g.id) === -1 })
  }
  readonly property int currentWorkspace: root.targetWindow ? root.targetWindow.workspaceId : -1
  readonly property var banks: root.service ? Banks.banksByMonitor(root.service.workspaceList, root.monitorName, 10) : []
  readonly property int pad: Style.space(12)
  readonly property int cell: Style.space(26)

  function show(kind, key) {
    root.kind = kind
    root.key = key
    root.editing = ""
    root.open = true
    root.forceActiveFocus()
  }

  function close() {
    root.open = false
    root.editing = ""
  }

  function moveTo(workspaceId) {
    if (root.kind === "window") root.service.moveWindow(root.key, workspaceId)
    else root.service.moveGroup(root.key, workspaceId)
    root.close()
  }

  function submitName(text) {
    if (root.editing === "new") {
      if (!root.service.createGroup(text, root.key)) return
    } else {
      root.service.renameGroup(root.key, text)
    }
    root.close()
  }

  // The target can vanish while the menu is open (window closed elsewhere).
  onTargetWindowChanged: if (root.open && root.kind === "window" && !root.targetWindow) root.close()
  onTargetGroupChanged: if (root.open && root.kind === "group" && !root.targetGroup) root.close()

  visible: opacity > 0
  opacity: root.open ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  width: root.cell * 10 + Style.space(3) * 9 + root.pad * 2
  height: column.implicitHeight + root.pad * 2
  x: Math.round(Math.max(Style.space(8), Math.min(root.maxX - width - Style.space(8), root.anchorX - width / 2)))
  y: Math.round(root.bottomY - height + (root.open ? 0 : Style.space(8)))
  Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  radius: Math.max(Style.space(10), Style.cornerRadius)
  color: Color.popups.background
  border.width: 1
  border.color: Util.alpha(Color.popups.border, 0.55)

  Keys.onEscapePressed: root.editing !== "" ? root.editing = "" : root.close()

  // Swallow clicks so the dock's dismiss area underneath does not see them.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
  }

  Column {
    id: column
    x: root.pad
    y: root.pad
    width: root.width - root.pad * 2
    spacing: Style.space(8)

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: root.targetWindow ? (root.targetWindow.title || root.targetWindow.appClass)
        : root.targetGroup ? root.targetGroup.name : ""
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.bold: true
    }

    SectionLabel { text: root.kind === "group" ? "Move all to" : "Move to" }

    Repeater {
      model: root.banks

      Column {
        id: bankColumn
        required property var modelData
        spacing: Style.space(3)

        Text {
          visible: root.banks.length > 1
          text: bankColumn.modelData.monitor
          color: Util.alpha(Color.popups.text, 0.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Row {
          spacing: Style.space(3)

          Repeater {
            model: bankColumn.modelData.slots

            Rectangle {
              id: cellBox
              required property var modelData
              readonly property bool current: cellBox.modelData.id === root.currentWorkspace

              width: root.cell
              height: root.cell
              radius: Style.space(6)
              color: current ? Util.alpha(Color.accent, 0.25)
                : cellMouse.containsMouse ? Util.alpha(Color.foreground, 0.14) : Util.alpha(Color.foreground, 0.05)
              border.width: current ? 1 : 0
              border.color: Color.accent

              Text {
                anchors.centerIn: parent
                text: cellBox.modelData.label
                color: cellBox.current ? Color.accent : Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }

              MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !cellBox.current
                cursorShape: Qt.PointingHandCursor
                onClicked: root.moveTo(cellBox.modelData.id)
              }
            }
          }
        }
      }
    }

    Separator {}

    // ---- Window: groups
    SectionLabel {
      visible: root.kind === "window"
      text: "Add to group"
    }

    Flow {
      visible: root.kind === "window"
      width: parent.width
      spacing: Style.space(4)

      Repeater {
        model: root.otherGroups

        Chip {
          required property var modelData
          label: modelData.name
          onActivated: {
            root.service.addToGroup(modelData.id, root.key)
            root.close()
          }
        }
      }

      Chip {
        label: "+ New group"
        visible: root.editing !== "new"
        onActivated: root.editing = "new"
      }
    }

    NameField {
      visible: root.editing !== ""
      placeholder: root.editing === "new" ? "Group name" : "New name"
      initial: root.editing === "rename" && root.targetGroup ? root.targetGroup.name : ""
    }

    Repeater {
      model: root.memberOf

      MenuRow {
        required property var modelData
        label: "Remove from " + modelData.name
        onActivated: {
          root.service.removeFromGroup(modelData.id, root.key)
          root.close()
        }
      }
    }

    MenuRow {
      visible: root.kind === "window"
      label: "Close window"
      danger: true
      onActivated: {
        root.service.closeWindow(root.key)
        root.close()
      }
    }

    // ---- Group
    MenuRow {
      visible: root.kind === "group" && root.editing === ""
      label: "Rename"
      onActivated: root.editing = "rename"
    }

    MenuRow {
      visible: root.kind === "group"
      label: "Delete group"
      danger: true
      onActivated: {
        root.service.deleteGroup(root.key)
        root.close()
      }
    }
  }

  component SectionLabel: Text {
    color: Util.alpha(Color.popups.text, 0.6)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.6
  }

  component Separator: Rectangle {
    width: parent ? parent.width : 0
    height: 1
    color: Util.alpha(Color.foreground, 0.12)
  }

  component MenuRow: Rectangle {
    id: row
    property string label: ""
    property bool danger: false
    signal activated()

    width: parent ? parent.width : 0
    height: Style.spacing.popupRowHeight
    radius: Style.space(6)
    color: rowMouse.containsMouse ? Util.alpha(row.danger ? Color.urgent : Color.foreground, 0.14) : "transparent"

    Text {
      anchors.verticalCenter: parent.verticalCenter
      x: Style.space(8)
      width: parent.width - Style.space(16)
      elide: Text.ElideRight
      text: row.label
      color: row.danger ? Color.urgent : Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.activated()
    }
  }

  component Chip: Rectangle {
    id: chip
    property string label: ""
    signal activated()

    width: chipLabel.implicitWidth + Style.space(16)
    height: Style.space(24)
    radius: height / 2
    color: chipMouse.containsMouse ? Util.alpha(Color.foreground, 0.16) : Util.alpha(Color.foreground, 0.07)

    Text {
      id: chipLabel
      anchors.centerIn: parent
      text: chip.label
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.activated()
    }
  }

  component NameField: Rectangle {
    id: field
    property string placeholder: ""
    property string initial: ""

    width: parent ? parent.width : 0
    height: Style.space(30)
    radius: Style.space(6)
    color: Util.alpha(Color.foreground, 0.06)
    border.width: 1
    border.color: input.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.2)

    onVisibleChanged: {
      if (!visible) return
      input.text = field.initial
      input.selectAll()
      input.forceActiveFocus()
    }

    TextInput {
      id: input
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      verticalAlignment: TextInput.AlignVCenter
      color: Color.popups.text
      selectionColor: Util.alpha(Color.accent, 0.4)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      maximumLength: 40
      clip: true
      onAccepted: root.submitName(text)
      Keys.onEscapePressed: root.editing = ""
    }

    Text {
      anchors.fill: input
      verticalAlignment: Text.AlignVCenter
      visible: input.text === ""
      text: field.placeholder
      color: Util.alpha(Color.popups.text, 0.4)
      font: input.font
    }
  }
}
