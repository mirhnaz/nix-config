import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "mir.switch-user"

  function switchUser() {
    if (!switchProc.running) switchProc.running = true
  }
  // Lock this session before returning to SDDM. SDDM keeps the graphical
  // session alive, so selecting this user later resumes exactly where they
  // left off. --print-reply keeps the caller connected until SDDM accepts it.
  Process {
    id: switchProc
    running: false
    command: ["/usr/local/bin/omarchy-family-switch"]
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0)
        console.warn("Switch user failed:", exitCode, exitStatus)
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf2f5"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: switchProc.running ? "Switching user…" : "Switch user (locks this session)"
    enabled: !switchProc.running
    onPressed: root.switchUser()
  }
}
