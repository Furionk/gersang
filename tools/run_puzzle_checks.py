"""Isolated Godot runner; logs all output and never uses the player's AppData."""
import os
import subprocess
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
out = root/'artifacts/puzzle-world'
out.mkdir(parents=True,exist_ok=True)
env = os.environ.copy()
env['APPDATA'] = str(out/'appdata')
env['LOCALAPPDATA'] = str(out/'localappdata')
Path(env['APPDATA']).mkdir(exist_ok=True)
Path(env['LOCALAPPDATA']).mkdir(exist_ok=True)
name = sys.argv[1] if len(sys.argv)>1 else 'puzzle_world_suite'
render = '--render' in sys.argv
cmd = ['R:/App/Godot_v4.7.1-stable_win64.exe','--path',str(root)]
if not render: cmd += ['--headless']
if name == 'import': cmd += ['--editor','--import','--quit']
elif name == 'run_all': cmd += ['--script','res://tests/run_all.gd']
else: cmd += ['res://tests/'+name+'.tscn']
if '--all' in sys.argv: cmd += ['--','--all']
log = out/(name.replace('/','-')+('-render' if render else '')+'.log')
with log.open('wb') as stream:
    p = subprocess.run(cmd,cwd=root,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=1200)
text = log.read_text(encoding='utf-8',errors='replace')
lines = text.splitlines()
print('\n'.join(line for line in lines if line.startswith('FAIL |') or 'SCRIPT ERROR' in line or 'Parse Error' in line))
print('PASS lines:',sum(line.startswith('PASS |') for line in lines))
print('\n'.join(lines[-8:]))
print('EXIT',p.returncode,'LOG',log)
sys.exit(p.returncode or (1 if 'SCRIPT ERROR' in text else 0))
