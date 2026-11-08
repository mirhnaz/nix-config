# BEGIN omarchy-family tty3 desktop
# Only Ayaan's interactive, physical tty3 login launches the desktop.
# SSH, other consoles, and graphical terminals keep their ordinary shell.
if [[ $- == *i* && $(id -un) == ayaan &&
      -z ${SSH_CONNECTION:-} && -z ${SSH_TTY:-} &&
      -z ${DISPLAY:-} && -z ${WAYLAND_DISPLAY:-} &&
      $(tty 2>/dev/null) == /dev/tty3 ]]; then
  # UWSM defaults to permitting only VT 1; this login deliberately uses VT 3.
  if uwsm check may-start -v 3; then
    exec uwsm start -g -1 -e -D Hyprland hyprland.desktop
  else
    printf 'Omarchy desktop was not started. See the UWSM check details above.\n' >&2
  fi
fi
# END omarchy-family tty3 desktop
