"""Run Godot checks with isolated user data and bounded execution."""
import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / 'artifacts/rainbow-action'
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
for key, folder in [('APPDATA', 'appdata'), ('LOCALAPPDATA', 'localappdata')]:
    env[key] = str(out / folder)
    Path(env[key]).mkdir(exist_ok=True)
name = sys.argv[1] if len(sys.argv) > 1 else 'rainbow_action_suite'
render = '--render' in sys.argv
cmd = ['R:/App/Godot_v4.7.1-stable_win64.exe', '--path', str(root)]
if not render:
    cmd.append('--headless')
if name == 'import':
    cmd += ['--editor', '--import', '--quit']
elif name == 'author':
    cmd += ['--script', 'res://tools/author_rainbow_encounter.gd']
elif name == 'run_all':
    cmd += ['--script', 'res://tests/run_all.gd']
else:
    cmd += ['res://tests/' + name + '.tscn']
extra = [arg for arg in sys.argv[2:] if arg != '--render']
if extra:
    cmd += ['--'] + extra
log = out / (name.replace('/', '-') + ('-render' if render else '') + '.log')
with log.open('wb') as stream:
    try:
        result = subprocess.run(cmd, cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=1200)
    except subprocess.TimeoutExpired:
        print('TIMEOUT', log)
        sys.exit(2)
text = log.read_text(encoding='utf-8', errors='replace')
lines = text.splitlines()
print('\n'.join(line for line in lines if 'SCRIPT ERROR' in line or 'Parse Error' in line or line.startswith('FAIL |')))
print('\n'.join(lines[-12:]))
print('EXIT', result.returncode, 'LOG', log)
sys.exit(result.returncode or (1 if 'SCRIPT ERROR' in text or 'Parse Error' in text or 'FAIL |' in text else 0))
