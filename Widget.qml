import QtQuick
import Quickshell
import Quickshell.Io

// Bare Item root (same shape as zeru.portwatch) so the widget stays
// self-contained and does not depend on qs.Ui internals that shift between
// Omarchy releases. Only the popup reaches into qs.Commons, for theme colors.
Item {
  id: root

  property var bar
  property string moduleName: "sabrodigan.ai-usage"
  property var settings

  // Nerd Font glyph (bar chart). Change here if your bar font lacks it.
  readonly property string icon: ""

  // --- geometry -------------------------------------------------------------
  // Bar.qml pins a vertical widget's cross-axis to bar.barSize regardless of
  // implicitWidth, so mirror BarIconButton and follow bar.vertical.
  readonly property bool vertical: bar ? bar.vertical : false
  implicitWidth: vertical ? (bar ? bar.barSize : 26) : row.implicitWidth + 14
  implicitHeight: vertical ? row.implicitHeight + 10 : (bar ? bar.barSize : 26)

  function luminance(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
  readonly property color baseColor: bar
    ? (luminance(bar.background) > 0.6 ? "#1a1a1a" : bar.foreground)
    : "white"
  readonly property color warnColor: "#e5534b"

  // --- settings ------------------------------------------------------------
  function setting(key, fallback) {
    if (settings && settings[key] !== undefined && settings[key] !== null && settings[key] !== "")
      return settings[key]
    return fallback
  }
  readonly property string badgeMetric: setting("badgeMetric", "Top usage %")
  readonly property int refreshMs: Math.max(15, Number(setting("refreshIntervalSec", 60))) * 1000
  readonly property int warnPercent: Number(setting("warnPercent", 80))
  readonly property int timeoutSec: Math.max(2, Number(setting("timeoutSec", 8)))

  // --- binary resolution -------------------------------------------------------
  // Qt.resolvedUrl(".") is this QML file's directory, wherever the plugin was
  // installed. bin/usage-run then prefers a system `usage`, else the bundled
  // static build.
  readonly property string pluginDir: {
    var u = Qt.resolvedUrl(".").toString()
    if (u.indexOf("file://") === 0) u = u.substring(7)
    if (u.length > 0 && u.charAt(u.length - 1) === "/") u = u.substring(0, u.length - 1)
    return decodeURIComponent(u)
  }
  readonly property string usageRun: pluginDir + "/bin/usage-run"

  // --- state -------------------------------------------------------------------
  property var providers: []
  property real totalCost: 0
  property bool loaded: false
  property bool failed: false
  property string errorText: ""
  property string snapshotMode: ""

  readonly property var topProvider: providers.length > 0 ? providers[0] : null
  readonly property bool anyWarn: {
    for (var i = 0; i < providers.length; i++)
      if (providers[i].percent_used >= root.warnPercent) return true
    return false
  }

  function formatCost(v) {
    if (v >= 100) return "$" + Math.round(v)
    return "$" + v.toFixed(2)
  }
  function formatPercent(v) { return Math.round(v) + "%" }
  function formatAmount(n, unit) {
    if (unit === "requests") return Math.round(n) + " req"
    if (n >= 1e6) return (n / 1e6).toFixed(2) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(1) + "K"
    return String(Math.round(n))
  }

  readonly property string badgeText: {
    if (!loaded) return failed ? "!" : "…"
    if (providers.length === 0) return "—"
    var pct = root.formatPercent(topProvider.percent_used)
    var cost = root.formatCost(totalCost)
    if (badgeMetric === "Total cost") return cost
    if (badgeMetric === "Both") return pct + " · " + cost
    return pct
  }
  readonly property color badgeColor: (loaded && anyWarn) ? warnColor : baseColor

  // --- refresh ---------------------------------------------------------------
  function refresh() {
    if (!scanProc.running) scanProc.running = true
  }

  Process {
    id: scanProc
    command: [root.usageRun, "now", "--json", "--timeout", String(root.timeoutSec)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.ingest(text)
    }
    onExited: function (exitCode) {
      if (exitCode !== 0 && !root.loaded) {
        root.failed = true
        root.loaded = true
        if (root.errorText === "")
          root.errorText = "`usage` exited " + exitCode
      }
    }
  }

  function ingest(text) {
    var data
    try {
      data = JSON.parse(text)
    } catch (e) {
      root.failed = true
      root.loaded = true
      root.errorText = "Could not parse `usage` output"
      return
    }

    var list = (data.providers || []).slice()
    list.sort(function (a, b) { return (b.percent_used || 0) - (a.percent_used || 0) })

    root.providers = list
    root.totalCost = Number(data.total_cost_usd || 0)
    root.snapshotMode = data.snapshot_mode || ""
    root.failed = false
    root.errorText = ""
    root.loaded = true
  }

  Timer {
    interval: root.refreshMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
  // A tighter cadence only while the popup is open.
  Timer {
    interval: 10000
    repeat: true
    running: popup.open
    onTriggered: root.refresh()
  }

  // --- popup plumbing ------------------------------------------------------
  function open() { popup.open = true; refresh() }
  function close() { popup.open = false }
  function toggle() { popup.open ? close() : open() }

  // The bar's click dispatcher only routes to widgets exposing this.
  function triggerPress(button) { root.toggle() }

  function openWatch() {
    Quickshell.execDetached(["bash", "-lc",
      "exec \"${TERMINAL:-alacritty}\" -e \"$0\" watch", root.usageRun])
    root.close()
  }

  IpcHandler {
    target: "sabrodigan.ai-usage"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.badgeColor
      font.family: bar ? bar.fontFamily : "monospace"
      font.pixelSize: 14
      opacity: root.loaded ? 1 : 0.5
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.vertical && root.badgeText !== ""
      text: root.badgeText
      color: root.badgeColor
      font.family: bar ? bar.fontFamily : "monospace"
      font.pixelSize: 12
      font.bold: root.loaded && root.anyWarn
    }
  }

  UsagePopup {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    providers: root.providers
    totalCost: root.totalCost
    loaded: root.loaded
    failed: root.failed
    errorText: root.errorText
    snapshotMode: root.snapshotMode
    warnPercent: root.warnPercent
    onRefreshRequested: root.refresh()
    onWatchRequested: root.openWatch()
    onScanRequested: {
      Quickshell.execDetached(["bash", "-lc",
        "exec \"${TERMINAL:-alacritty}\" -e \"$0\" scan new", root.usageRun])
      root.close()
    }
  }

  Component.onCompleted: refresh()
}
