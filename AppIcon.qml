import QtQuick
import Quickshell
import qs.Commons

// Icon for a window class, resolved through its desktop entry, with a
// monogram when no icon theme has it.
Item {
  id: root

  property string appClass: ""
  property int size: 24

  readonly property var entry: root.appClass ? DesktopEntries.heuristicLookup(String(root.appClass).trim()) : null
  readonly property string appName: root.entry && root.entry.name ? root.entry.name : root.appClass

  readonly property string source: {
    var cls = String(root.appClass || "").trim()
    if (!cls) return ""
    var icon = String(root.entry && root.entry.icon ? root.entry.icon : "")
    if (icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0) return icon
    if (icon.charAt(0) === "/") return Util.fileUrl(icon)
    var names = [icon, cls, cls.toLowerCase()]
    for (var i = 0; i < names.length; i++) {
      if (!names[i]) continue
      var path = Quickshell.iconPath(names[i], true)
      if (path) return path
    }
    return ""
  }

  implicitWidth: size
  implicitHeight: size

  Image {
    id: image
    anchors.fill: parent
    source: root.source
    sourceSize: Qt.size(root.size * 2, root.size * 2)
    asynchronous: true
    smooth: true
    mipmap: true
    visible: status === Image.Ready
  }

  Rectangle {
    anchors.fill: parent
    visible: image.status !== Image.Ready
    radius: width * 0.28
    color: Util.alpha(Color.foreground, 0.14)

    Text {
      anchors.centerIn: parent
      text: String(root.appClass || "?").replace(/^.*[.]/, "").charAt(0).toUpperCase()
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Math.round(root.size * 0.5)
      font.bold: true
    }
  }
}
