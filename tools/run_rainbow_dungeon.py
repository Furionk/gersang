"""Isolated engine runner; all outputs live in the current dungeon evidence folder."""
from pathlib import Path
import os, subprocess, sys
root=Path(__file__).resolve().parents[1]
out=root/'artifacts/rainbow-dungeon'; out.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
for key in ['APPDATA','LOCALAPPDATA']:
    env[key]=str(out/key.lower()); Path(env[key]).mkdir(exist_ok=True)
name=sys.argv[1]
cmd=['R:/App/Godot_v4.7.1-stable_win64.exe','--path',str(root)]
if name=='rainbow_dungeon_playthrough': cmd+=['--fixed-fps','60','--disable-vsync']
if '--render' not in sys.argv: cmd+=['--headless']
if name in ['expand','dress','repair','pillars','run_all']:
    cmd+=['--script',{'expand':'res://tools/expand_rainbow_dungeon.gd','dress':'res://tools/dress_rainbow_dungeon.gd','repair':'res://tools/repair_rainbow_native_refs.gd','pillars':'res://tools/anchor_rainbow_pillars.gd','run_all':'res://tests/run_all.gd'}[name]]
else: cmd+=['res://tests/'+name+'.tscn']
extra=[arg for arg in sys.argv[2:] if arg!='--render']
if extra: cmd+=['--']+extra
log=out/(name.replace('/','-')+('-full' if '--all' in sys.argv else '')+('-render' if '--render' in sys.argv else '')+'.log')
with log.open('wb') as stream:
    result=subprocess.run(cmd,cwd=root,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=1500)
text=log.read_text(encoding='utf-8',errors='replace')
print('\n'.join(l for l in text.splitlines() if 'SCRIPT ERROR' in l or 'Parse Error' in l or l.startswith('FAIL |')))
print('\n'.join(text.splitlines()[-12:]))
print('EXIT',result.returncode,'LOG',log)
sys.exit(result.returncode or int('SCRIPT ERROR' in text or 'FAIL |' in text))
