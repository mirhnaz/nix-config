#!/usr/bin/env python3
"""Exercise session routing and fail-closed locking without touching the desktop."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent
MOCK = '''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['CALL_LOG'], 'a') as f:
    f.write(json.dumps([name, *args]) + '\\n')
if name == 'id': print(os.environ['CALLER'])
elif name == 'getent': print('exists')
elif name == 'loginctl':
    mode = os.environ['MODE']
    if args[0] == 'list-sessions':
        if mode not in {'new', 'missing-getty'}:
            user = 'someone' if mode == 'occupied' else os.environ['TARGET']
            print('7 1000 ' + user + ' seat0 tty3 user')
        if mode == 'duplicate':
            print('8 1000 ' + os.environ['TARGET'] + ' seat0 tty4 user')
    elif args[0] == 'show-session':
        session_type = 'tty' if mode in {'console', 'bare-console', 'wrong-console', 'occupied'} else 'wayland'
        tty = 'tty4' if mode == 'wrong-console' else 'tty3'
        print('Type=' + session_type + '\\nClass=user\\nState=online\\nTTY=' + tty + '\\nService=' + os.environ['SERVICE'])
elif name == 'pgrep':
    sys.exit(1 if os.environ['MODE'] == 'bare-console' else 0)
elif name == 'systemctl':
    sys.exit(1 if os.environ['MODE'] == 'missing-getty' else 0)
elif name == 'tty': print(os.environ.get('TEST_TTY', '/dev/tty3'))
elif name == 'uwsm':
    if args[:2] == ['check', 'may-start']:
        if args != ['check', 'may-start', '-v', '3']:
            print('Test rejected implicit/default VT: tty3 must be explicitly allowed.', file=sys.stderr)
            sys.exit(2)
        sys.exit(1 if os.environ['MODE'] == 'profile-blocked' else 0)
elif name == 'omarchy-shell':
    print(json.dumps({'secure': os.environ['MODE'] != 'insecure'}))
elif name == 'sleep': pass
'''

with tempfile.TemporaryDirectory(prefix='family-switch-check-') as directory:
    temp = Path(directory)
    commands = temp / 'bin'
    commands.mkdir()
    for command in ['id', 'getent', 'loginctl', 'omarchy-shell',
                    'omarchy-system-lock', 'dbus-send', 'notify-send', 'sleep', 'pgrep', 'busctl', 'systemctl', 'tty', 'uwsm']:
        path = commands / command
        path.write_text(MOCK)
        path.chmod(0o755)
    for mode, caller, service in [
        ('existing', 'ayaan', 'sddm-autologin'),
        ('existing', 'mir', 'sddm'),
        ('new', 'mir', 'sddm'),
        ('insecure', 'mir', 'sddm'),
        ('duplicate', 'mir', 'sddm'),
        ('console', 'mir', 'login'),
        ('bare-console', 'mir', 'login'),
        ('wrong-console', 'mir', 'login'),
        ('occupied', 'mir', 'login'),
        ('missing-getty', 'mir', 'login'),
        ('new', 'ayaan', 'login'),
    ]:
        log = temp / 'calls.jsonl'
        log.write_text('')
        environment = os.environ | {
            'PATH': str(commands) + os.pathsep + os.environ['PATH'],
            'CALL_LOG': str(log), 'MODE': mode, 'CALLER': caller,
            'TARGET': 'mir' if caller == 'ayaan' else 'ayaan',
            'SERVICE': service, 'XDG_RUNTIME_DIR': str(temp), 'XDG_SEAT': 'seat0',
        }
        result = subprocess.run([str(ROOT / 'omarchy-family-switch')],
                                env=environment, capture_output=True, text=True)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        switches = [call for call in calls
                    if call[:2] == ['loginctl', 'activate'] or
                    call[0] == 'dbus-send' or (call[0] == 'busctl' and 'call' in call)]
        assert not any(call[0] == 'dbus-send' for call in calls), calls
        if mode in {'insecure', 'duplicate', 'wrong-console', 'occupied', 'missing-getty'} or (mode == 'new' and caller == 'ayaan'):
            assert result.returncode != 0 and not switches, (mode, calls)
            if mode != 'insecure':
                assert not any(call[0] == 'omarchy-system-lock' for call in calls), calls
        else:
            assert result.returncode == 0, (mode, result.stderr)
            assert len(switches) == 1, (mode, calls)
            lock_index = next(i for i, call in enumerate(calls)
                              if call[0] == 'omarchy-system-lock')
            assert lock_index < calls.index(switches[0]), calls
            if mode == 'new':
                assert switches[0][0] == 'busctl' and switches[0][-3:] == ['SwitchTo', 'u', '3'], calls
            else:
                assert switches[0] == ['loginctl', 'activate', '7'], calls
        print(f'PASS: {mode}, caller={caller}, service={service}')

    for label, variables, should_start in [
        ('physical ayaan tty3', {}, True),
        ('SSH login', {'SSH_CONNECTION': 'test connection'}, False),
        ('SSH tty', {'SSH_TTY': '/dev/pts/3'}, False),
        ('other console', {'TEST_TTY': '/dev/tty4'}, False),
        ('mir account', {'CALLER': 'mir'}, False),
        ('Wayland terminal', {'WAYLAND_DISPLAY': 'wayland-1'}, False),
        ('X11 terminal', {'DISPLAY': ':0'}, False),
        ('existing UWSM session', {'MODE': 'profile-blocked'}, False),
    ]:
        log = temp / 'profile-calls.jsonl'
        log.write_text('')
        environment = {key: value for key, value in os.environ.items()
                       if key not in {'SSH_CONNECTION', 'SSH_TTY', 'DISPLAY', 'WAYLAND_DISPLAY', 'BASH_ENV', 'ENV'}}
        environment.update(PATH=str(commands) + os.pathsep + os.environ['PATH'],
                           CALL_LOG=str(log), CALLER='ayaan', MODE='profile-ok', TEST_TTY='/dev/tty3')
        environment.update(variables)
        result = subprocess.run(['/usr/bin/bash', '--noprofile', '--norc', '-ic',
                                 '. "$1"', 'bash', str(ROOT / 'ayaan-tty3.bash')],
                                env=environment, capture_output=True, text=True)
        assert result.returncode == 0, (label, result.stderr)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        launches = [call for call in calls if call[:2] == ['uwsm', 'start']]
        assert bool(launches) == should_start, (label, calls)
        if should_start:
            assert launches == [['uwsm', 'start', '-g', '-1', '-e', '-D', 'Hyprland', 'hyprland.desktop']], calls
        print(f'PASS: profile {label}')

# Exercise the installer transformations in temporary homes, without root or
# touching real profiles, widgets, system services, or user ownership.
installer = (ROOT / 'install-on-demand.sh').read_text()
merge_profile, install_widgets = [part.split('\nPY\n', 1)[0]
                                  for part in installer.split("<<'PY'\n")[1:]]
with tempfile.TemporaryDirectory(prefix='family-install-check-') as directory:
    temp = Path(directory)
    profile, output = temp / 'bash_profile', temp / 'merged'
    original = 'export PERSONAL_SETTING=kept\n'
    profile.write_text(original)
    for _ in range(2):
        result = subprocess.run(['python3', '-', str(profile), str(ROOT / 'ayaan-tty3.bash'), str(output)],
                                input=merge_profile, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        profile.write_text(output.read_text())
    assert profile.read_text().startswith(original)
    assert profile.read_text().count('# BEGIN omarchy-family tty3 desktop') == 1
    assert 'uwsm check may-start -v 3' in profile.read_text()
    profile.write_text('# BEGIN omarchy-family tty3 desktop\n')
    output.unlink()
    result = subprocess.run(['python3', '-', str(profile), str(ROOT / 'ayaan-tty3.bash'), str(output)],
                            input=merge_profile, text=True, capture_output=True)
    assert result.returncode != 0 and not output.exists()
    print('PASS: installer profile merge preserves settings, is idempotent, and refuses malformed blocks')

    users = {}
    for name in ('mir', 'ayaan'):
        home = temp / name
        config = home / '.config/omarchy'
        config.mkdir(parents=True)
        (config / 'shell.json').write_text(json.dumps({
            'custom': 'preserved', 'bar': {'layout': {'right': [{'id': 'custom.widget'}, {'id': 'omarchy.power'}]}}
        }))
        users[name] = SimpleNamespace(pw_dir=str(home), pw_uid=1000 if name == 'mir' else 30033, pw_gid=1000)
    source = ROOT / '../../omarchy/plugins/mir.switch-user'
    with patch('sys.argv', ['installer', str(source)]), patch('pwd.getpwnam', side_effect=users.get), patch('os.chown'):
        exec(compile(install_widgets, 'installer-widgets', 'exec'), {})
        exec(compile(install_widgets, 'installer-widgets', 'exec'), {})
    for name, user in users.items():
        config = Path(user.pw_dir) / '.config/omarchy'
        plugin_id = f'{name}.switch-user'
        plugin = config / 'plugins' / plugin_id
        assert json.loads((plugin / 'manifest.json').read_text())['id'] == plugin_id
        assert f'moduleName: "{plugin_id}"' in (plugin / 'SwitchUser.qml').read_text()
        shell = json.loads((config / 'shell.json').read_text())
        assert shell['custom'] == 'preserved'
        assert [item['id'] for item in shell['bar']['layout']['right']] == ['custom.widget', plugin_id, 'omarchy.power']
    print('PASS: installer widgets preserve bar settings, use independent identities, and do not duplicate on rerun')
