import QtQuick
import Quickshell.Io
import qs.Ui

// The upstream indicator uses bar.shell.firstPartyServiceFor("omarchy.notifications"),
// which omarchy-shell only grants to plugins of kind "bar"; this clone is a
// "bar-widget", so that was null and clicks did nothing. Use the
// notification service's IPC instead.
BarIndicator {
  id: root

  property bool dnd: false

  active: dnd
  activeText: "󰂛"
  inactiveText: "󰂛"
  activeTooltipText: "Allow Notifications"
  inactiveTooltipText: "Silence Notifications"

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
    command: ["omarchy-shell", "notifications", "isDnd"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.dnd = String(text).trim() === "on"
    }
  }

  Process {
    id: toggleProc
    command: ["omarchy-shell", "notifications", "toggleDnd"]
    onExited: function() { root.refresh() }
  }

  onPressed: function() {
    if (!toggleProc.running) toggleProc.running = true
  }
}
