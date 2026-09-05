import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

// Popup scaffolding (anchor math, focus grab, popout coordination, card fade)
// follows zeru.portwatch's PortsPopup so it behaves like a native Omarchy
// bar popup across bar positions and themes.
PopupWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property bool open: false

  property var providers: []
  property real totalCost: 0
  property bool loaded: false
  property bool failed: false
  property string errorText: ""
  property string snapshotMode: ""
  property int warnPercent: 80

  signal refreshRequested()
  signal watchRequested()
  signal scanRequested()

  readonly property var coordinatorKey: owner || root
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null

  readonly property color bg: Color.popups.background
  readonly property color borderColor: Color.popups.border
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent

  function luminance(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
  readonly property color fg: luminance(bg) > 0.6 ? "#1a1a1a" : Color.popups.text
  readonly property color safeMuted: luminance(bg) > 0.6 ? "#5a5a5a" : Color.muted
  readonly property string fontFamily: bar ? bar.fontFamily : "monospace"

  readonly property int margin: 10
  readonly property int cardPadding: 14

  function barColor(pct) {
    return pct >= root.warnPercent ? root.urgent : root.accent
  }
  function formatCost(v) {
    if (v >= 100) return "$" + Math.round(v)
    return "$" + v.toFixed(2)
  }
  function formatAmount(n, unit) {
    if (unit === "requests") return Math.round(n) + " req"
    if (n >= 1e6) return (n / 1e6).toFixed(2) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(1) + "K"
    return String(Math.round(n))
  }

  implicitWidth: 440
  implicitHeight: Math.min(540, Math.max(120, content.implicitHeight + cardPadding * 2))

  visible: open || card.opacity > 0
  color: "transparent"

  function close() { root.open = false }

  onOpenChanged: {
    if (!bar) return
    if (open) bar.requestPopout(coordinatorKey)
    else if (bar.activePopout === coordinatorKey) bar.releasePopout(coordinatorKey)
  }

  HyprlandFocusGrab {
    active: root.open
    windows: root.anchorWindow ? [root, root.anchorWindow] : [root]
    onCleared: root.close()
  }

  anchor {
    id: popupAnchor
    window: root.anchorWindow
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      if (!root.anchorItem || !root.bar || !root.anchorWindow) return

      var target = root.anchorItem
      var w = root.implicitWidth
      var h = root.implicitHeight
      var localX = target.width / 2 - w / 2
      var localY = target.height + root.margin

      if (root.bar.position === "bottom") {
        localY = -h - root.margin
      } else if (root.bar.position === "left") {
        localX = target.width + root.margin
        localY = target.height / 2 - h / 2
      } else if (root.bar.position === "right") {
        localX = -w - root.margin
        localY = target.height / 2 - h / 2
      }

      var point = root.anchorWindow.contentItem.mapFromItem(target, localX, localY)

      if (root.bar.position === "top" || root.bar.position === "bottom") {
        point.x = Math.max(root.margin, Math.min(point.x, root.anchorWindow.width - w - root.margin))
      } else {
        point.y = Math.max(root.margin, Math.min(point.y, root.anchorWindow.height - h - root.margin))
      }

      popupAnchor.rect.x = Math.round(point.x)
      popupAnchor.rect.y = Math.round(point.y)
    }
  }

  Rectangle {
    id: card
    anchors.fill: parent
    radius: 0
    color: root.bg
    border.color: root.borderColor
    border.width: 2
    opacity: root.open ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
    }

    Column {
      id: content
      anchors.fill: parent
      anchors.margins: root.cardPadding
      spacing: 10

      // --- header ---------------------------------------------------------
      Row {
        width: parent.width
        height: Math.max(titleText.implicitHeight, refreshBtn.height)

        Column {
          width: parent.width - refreshBtn.width
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          Text {
            id: titleText
            text: "AI Model Usage"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: 14
            font.bold: true
          }
          Text {
            visible: root.snapshotMode === "EXAMPLE"
            text: "example data — no providers configured"
            color: root.safeMuted
            font.family: root.fontFamily
            font.pixelSize: 9
          }
        }

        Row {
          id: refreshBtn
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.loaded ? root.formatCost(root.totalCost) + " / mo" : ""
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: 12
            font.bold: true
          }

          Item {
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            Text {
              anchors.centerIn: parent
              text: ""
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: 13
              opacity: refreshArea.containsMouse ? 1 : 0.6
            }
            MouseArea {
              id: refreshArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.refreshRequested()
            }
          }
        }
      }

      // --- states -------------------------------------------------------------
      Text {
        visible: !root.loaded
        text: "Loading…"
        color: root.safeMuted
        font.family: root.fontFamily
        font.pixelSize: 12
      }

      Text {
        visible: root.loaded && root.failed
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Couldn't read usage: " + root.errorText
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: 11
      }

      Column {
        visible: root.loaded && !root.failed && root.providers.length === 0
        width: parent.width
        spacing: 8

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "No providers configured yet. Scan this machine for installed AI tools and API keys to start tracking."
          color: root.safeMuted
          font.family: root.fontFamily
          font.pixelSize: 11
        }
        PopupButton {
          label: "Scan for providers"
          onClicked: root.scanRequested()
        }
      }

      // --- provider list ---------------------------------------------------
      Flickable {
        id: flick
        visible: root.loaded && !root.failed && root.providers.length > 0
        width: parent.width
        height: Math.min(360, listCol.implicitHeight)
        contentWidth: width
        contentHeight: listCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: listCol
          width: flick.width
          spacing: 8

          Repeater {
            model: root.providers
            delegate: ProviderRow { width: listCol.width }
          }
        }
      }

      // --- footer --------------------------------------------------------
      PopupButton {
        visible: root.loaded && !root.failed && root.providers.length > 0
        label: "Open live dashboard  ▸"
        onClicked: root.watchRequested()
      }
    }
  }

  // ----------------------------------------------------------------------------
  component PopupButton: Rectangle {
    id: btn
    property string label: ""
    signal clicked()

    width: parent ? parent.width : 200
    height: 30
    radius: 6
    color: btnArea.containsMouse
      ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
      : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)

    Text {
      anchors.centerIn: parent
      text: btn.label
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: 11
      font.bold: true
    }
    MouseArea {
      id: btnArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }

  component ProviderRow: Item {
    id: rowDelegate
    required property var modelData
    readonly property real pct: modelData.percent_used || 0
    readonly property bool warn: pct >= root.warnPercent
    readonly property real cost: modelData.estimated_cost_usd || 0
    height: 44

    // Line 1 — provider name + tier on the left, percent pinned right.
    Text {
      id: pctText
      anchors.right: parent.right
      anchors.top: parent.top
      text: Math.round(rowDelegate.pct) + "%"
      color: rowDelegate.warn ? root.urgent : root.fg
      font.family: root.fontFamily
      font.pixelSize: 12
      font.bold: true
    }

    Row {
      anchors.left: parent.left
      anchors.right: pctText.left
      anchors.rightMargin: 8
      anchors.top: parent.top
      spacing: 6

      Text {
        id: nameText
        text: modelData.display_name || modelData.provider_id || "?"
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: 12
        font.bold: true
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, parent.width - nameText.width - parent.spacing)
        text: modelData.model_or_tier || ""
        color: root.safeMuted
        font.family: root.fontFamily
        font.pixelSize: 10
        elide: Text.ElideRight
      }
    }

    // Line 2 — progress track fills the row, amounts pinned right.
    Text {
      id: amountText
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 2
      text: root.formatAmount(modelData.consumed || 0, modelData.unit)
            + " / " + root.formatAmount(modelData.quota || 0, modelData.unit)
            + (rowDelegate.cost > 0 ? "   " + root.formatCost(rowDelegate.cost) : "")
      color: root.safeMuted
      font.family: root.fontFamily
      font.pixelSize: 9
    }

    Rectangle {
      id: track
      anchors.left: parent.left
      anchors.right: amountText.left
      anchors.rightMargin: 10
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 6
      height: 6
      radius: 3
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)

      Rectangle {
        width: Math.max(2, Math.min(1, rowDelegate.pct / 100) * parent.width)
        height: parent.height
        radius: 3
        color: root.barColor(rowDelegate.pct)
      }
    }
  }
}
