"""Isolated revision evidence; never writes a player's app-data directory."""
from pathlib import Path
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
name = sys.argv[1]
extra = [arg for arg in sys.argv[2:] if arg != '--render']
suffix = ''.join('-' + arg.removeprefix('--').replace('=', '-') for arg in extra)
suffix += '-render' if '--render' in sys.argv else ''
out = root / 'artifacts/rainbow-overhaul'
out.mkdir(exist_ok=True, parents=True)
env = os.environ.copy()
for key in ('APPDATA', 'LOCALAPPDATA'):
    target = out / (name + suffix) / key.lower()
    target.mkdir(parents=True, exist_ok=True)
    env[key] = str(target)
command = ['R:/App/Godot_v4.7.1-stable_win64.exe', '--path', str(root)]
if '--render' not in sys.argv:
    command.append('--headless')
if name in ('rainbow_dps_benchmark', 'rainbow_dungeon_playthrough'):
    command += ['--fixed-fps', '60', '--disable-vsync']
command += ['res://tests/' + name + '.tscn']
if extra:
    command += ['--'] + extra
log = out / (name.replace('/', '-') + suffix + '.log')
with log.open('wb') as stream:
    result = subprocess.run(command, env=env, cwd=root, stdout=stream,
                            stderr=subprocess.STDOUT, timeout=1500)
text = log.read_text(encoding='utf-8', errors='replace')
runtime_errors = [line for line in text.splitlines() if line.startswith('ERROR:') and not any(known in line for known in ('leaked', 'resources still in use at exit', 'Pages in use exist at exit', 'shaders of type CanvasShaderGLES3 were never freed'))]
for line in text.splitlines():
    if any(token in line for token in ('SCRIPT ERROR', 'Parse Error', 'FAIL |', '_RESULT')):
        print(line)
print('EXIT', result.returncode, 'LOG', log)
for line in runtime_errors[:10]: print(line)
sys.exit(result.returncode or int('SCRIPT ERROR' in text or 'FAIL |' in text or bool(runtime_errors)))
