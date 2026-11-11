import QtQuick
import Quickshell.Io
import qs.Ui

// The upstream indicator uses bar.shell.firstPartyServiceFor("omarchy.nightlight"),
// which omarchy-shell only grants to plugins of kind "bar"; this clone is a
// "bar-widget", so that was null and clicks did nothing. Use the nightlight
// service's IPC instead.
BarIndicator {
  id: root

  property bool nightlight: false

  active: nightlight
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: "Day Light"
  inactiveTooltipText: "Night Light"

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Process {
    id: statusProc
    command: ["omarchy-shell", "nightlight", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.nightlight = !!root.extractData(text).enabled
    }
  }

  Process {
    id: toggleProc
    command: ["omarchy-shell", "nightlight", "toggle"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.nightlight = String(text).trim() === "enabled"
    }
  }

  onPressed: function() {
    if (!toggleProc.running) toggleProc.running = true
  }
}
