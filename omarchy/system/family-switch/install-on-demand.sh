#!/usr/bin/env bash
# Configure authenticated local login on tty3; preserve every existing session.
set -Eeuo pipefail
((EUID == 0)) || { echo 'Run with sudo from your terminal.' >&2; exit 1; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
widget_source="$script_dir/../../omarchy/plugins/mir.switch-user"
[[ -f $widget_source/SwitchUser.qml && -f $widget_source/manifest.json ]] ||
  { echo 'Tracked switch-user widget is missing from this checkout.' >&2; exit 1; }
for command in getent python3 install systemctl loginctl busctl uwsm; do
  command -v "$command" >/dev/null || { printf 'Missing command: %s\n' "$command" >&2; exit 1; }
done
record=$(getent passwd ayaan)
IFS=: read -r account _ uid gid _ account_home account_shell <<< "$record"
[[ $account == ayaan && $account_home == /home/ayaan &&
   ( $account_shell == /usr/bin/bash || $account_shell == /bin/bash ) ]] ||
  { echo 'Expected ayaan with a Bash login shell and /home/ayaan home.' >&2; exit 1; }
profile="$account_home/.bash_profile"
[[ -d $account_home && ! -L $account_home && ! -L $profile ]] ||
  { echo 'Refusing missing home or symlinked home/profile.' >&2; exit 1; }
[[ ! -e $profile || -f $profile ]] || exit 1
for desktop_user in mir ayaan; do
  desktop_home=$(getent passwd "$desktop_user" | cut -d: -f6)
  [[ $desktop_home == "/home/$desktop_user" && -d $desktop_home/.config/hypr &&
     -f $desktop_home/.config/omarchy/shell.json &&
     ! -L $desktop_home/.config && ! -L $desktop_home/.config/omarchy &&
     ! -L $desktop_home/.config/omarchy/shell.json ]] ||
    { printf 'Initialize the independent Omarchy desktop for %s first (plain shell.json required).\n' "$desktop_user" >&2; exit 1; }
done
# Read-only preflight: no terminal changes and no desktop startup.
loginctl list-sessions --no-pager >/dev/null
busctl --system --timeout=5s introspect org.freedesktop.login1 \
  /org/freedesktop/login1/seat/seat0 org.freedesktop.login1.Seat >/dev/null
getty_definition=$(systemctl cat getty@tty3.service)
if grep -Eq -- '--autologin|--skip-login|--login-program|--login-options|(^|[[:space:]])-a([[:space:]]|$)' <<< "$getty_definition"; then
  echo 'tty3 has a custom login program or autologin configuration; refusing to change its role.' >&2
  exit 1
fi
bash -n "$script_dir/omarchy-family-switch" "$script_dir/ayaan-tty3.bash"

install -d -m 0755 /var/backups
backup=$(mktemp -d /var/backups/omarchy-family-ondemand.XXXXXXXX)
chmod 0700 "$backup"
if [[ -e /usr/local/bin/omarchy-family-switch ]]; then
  cp -a /usr/local/bin/omarchy-family-switch "$backup/switch-helper"
fi
if [[ -e $profile ]]; then
  cp -a "$profile" "$backup/bash_profile"
else
  touch "$backup/profile-was-absent"
fi
systemctl is-enabled getty@tty3.service >"$backup/getty-enabled-state" 2>/dev/null || true
printf '#!/usr/bin/env bash\nset -euo pipefail\n((EUID == 0)) || exit 1\n' >"$backup/rollback.sh"
if [[ -e $backup/switch-helper ]]; then
  printf 'cp -a -- %q /usr/local/bin/omarchy-family-switch\n' "$backup/switch-helper" >>"$backup/rollback.sh"
else
  printf 'rm -f -- /usr/local/bin/omarchy-family-switch\n' >>"$backup/rollback.sh"
fi
if [[ -e $profile ]]; then
  printf 'cp -a -- %q %q\n' "$backup/bash_profile" "$profile" >>"$backup/rollback.sh"
else
  printf 'rm -f -- %q\n' "$profile" >>"$backup/rollback.sh"
fi
if ! grep -qx 'enabled' "$backup/getty-enabled-state"; then
  printf 'systemctl disable getty@tty3.service\n' >>"$backup/rollback.sh"
fi
chmod 0700 "$backup/rollback.sh"
printf 'Backup and rollback: %s\n' "$backup"
for desktop_user in mir ayaan; do
  desktop_config="/home/$desktop_user/.config/omarchy"
  cp -a "$desktop_config/shell.json" "$backup/$desktop_user-shell.json"
  printf 'cp -a -- %q %q\n' "$backup/$desktop_user-shell.json" "$desktop_config/shell.json" >>"$backup/rollback.sh"
  widget_dir="$desktop_config/plugins/$desktop_user.switch-user"
  if [[ -e $widget_dir ]]; then
    cp -a "$widget_dir" "$backup/$desktop_user-widget"
    printf 'rm -rf -- %q\ncp -a -- %q %q\n' "$widget_dir" "$backup/$desktop_user-widget" "$widget_dir" >>"$backup/rollback.sh"
  else
    printf 'rm -rf -- %q\n' "$widget_dir" >>"$backup/rollback.sh"
  fi
done

# Merge our marked block without executing the account's shell configuration.
temporary_profile=$(mktemp)
trap 'rm -f -- "$temporary_profile"' EXIT
python3 - "$profile" "$script_dir/ayaan-tty3.bash" "$temporary_profile" <<'PY'
from pathlib import Path
import sys
profile, snippet, output = map(Path, sys.argv[1:])
text = profile.read_text() if profile.exists() else '[[ -f ~/.bashrc ]] && . ~/.bashrc\n'
start = '# BEGIN omarchy-family tty3 desktop'
end = '# END omarchy-family tty3 desktop'
if start in text or end in text:
    if text.count(start) != 1 or text.count(end) != 1 or text.index(start) > text.index(end):
        raise SystemExit('Malformed existing family profile block; no profile changes made.')
    a, b = text.index(start), text.index(end) + len(end)
    text = text[:a] + text[b:]
output.write_text(text.rstrip() + '\n\n' + snippet.read_text())
PY
bash -n "$temporary_profile"
install -o "$uid" -g "$gid" -m 0644 "$temporary_profile" "$profile"
# Starts only a standard password-based text login if it is not already active.
# No --autologin, restart, stop, chvt, or desktop launch is performed here.
systemctl enable --now getty@tty3.service
systemctl is-active --quiet getty@tty3.service
install -o root -g root -m 0755 "$script_dir/omarchy-family-switch" /usr/local/bin/omarchy-family-switch
python3 - "$widget_source" <<'PY'
import json
import os
from pathlib import Path
import pwd
import sys
import tempfile

source = Path(sys.argv[1])
qml = (source / 'SwitchUser.qml').read_text()
manifest = json.loads((source / 'manifest.json').read_text())

def write_owned(path, text, user):
    # Atomic writes avoid partially written QML/config being hot-reloaded.
    if path.is_file() and path.read_text() == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as output:
            output.write(text)
        os.chmod(temporary, 0o644)
        os.chown(temporary, user.pw_uid, user.pw_gid)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

for name in ('mir', 'ayaan'):
    user = pwd.getpwnam(name)
    config = Path(user.pw_dir) / '.config/omarchy'
    plugin_id = f'{name}.switch-user'
    plugin = config / 'plugins' / plugin_id
    plugin.mkdir(parents=True, exist_ok=True)
    os.chown(config / 'plugins', user.pw_uid, user.pw_gid)
    os.chown(plugin, user.pw_uid, user.pw_gid)
    widget_manifest = dict(manifest, id=plugin_id, author=name)
    write_owned(plugin / 'SwitchUser.qml', qml.replace('"mir.switch-user"', json.dumps(plugin_id)), user)
    write_owned(plugin / 'manifest.json', json.dumps(widget_manifest, indent=2) + '\n', user)
    shell_file = config / 'shell.json'
    shell = json.loads(shell_file.read_text())
    right = shell.setdefault('bar', {}).setdefault('layout', {}).setdefault('right', [])
    if not any(item.get('id') == plugin_id for item in right):
        index = next((i for i, item in enumerate(right) if item.get('id') == 'omarchy.power'), len(right))
        right.insert(index, {'id': plugin_id})
        write_owned(shell_file, json.dumps(shell, indent=2) + '\n', user)
PY
printf 'Installed on-demand tty3 login and existing-session switching.\n'
printf 'No SDDM restart, reboot, logout, or screen switch was performed.\n'
printf 'Rollback: sudo bash %s/rollback.sh\n' "$backup"
