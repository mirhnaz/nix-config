import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// The upstream indicator calls bar.shell.firstPartyServiceFor("omarchy.idle"),
// but omarchy-shell only hands first-party services to plugins of kind "bar".
// This clone is a "bar-widget", so that lookup returns null and the click did
// nothing. Drive the same state file the idle service watches instead
// (~/.local/state/omarchy/indicators/stay-awake) via omarchy-toggle-idle.
BarIndicator {
  id: root

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/indicators"
  property bool stayAwake: false

  active: stayAwake
  activeText: "󰅶"
  inactiveText: "󰅶"
  activeTooltipText: "Allow Idle Lock & Screensaver"
  inactiveTooltipText: "Stay Awake"

  function refresh() {
    if (statusProc.running) return
    statusProc.running = true
  }

  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  // Picks up changes from anywhere: this button, `omarchy toggle idle`,
  // omarchy-update-stay-awake, or `omarchy-shell idle toggle`.
  FileView {
    path: root.stateDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  Process {
    id: statusProc
    command: ["test", "-f", root.stateDir + "/stay-awake"]
    onExited: function(exitCode) { root.stayAwake = exitCode === 0 }
  }

  Process {
    id: toggleProc
    command: ["omarchy-toggle-idle", "toggle"]
    onExited: function() { root.refresh() }
  }

  onPressed: function() {
    if (!toggleProc.running) toggleProc.running = true
  }
}
