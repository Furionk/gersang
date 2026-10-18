"""Reproduce the full runner's strict child-exit gate on the final authored content."""
import json, os, subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]; out=root/'artifacts/rainbow-dungeon'
env=os.environ.copy()
for key in ['APPDATA','LOCALAPPDATA']: env[key]=str(out/key.lower())
engine=out/'battlefield-final-engine.log'; captured=out/'battlefield-final-output.log'
cmd=['R:/App/Godot_v4.7.1-stable_win64.exe','--headless','--path',str(root),'--log-file',str(engine),'--quit-after','18000','res://tests/battlefield_scene_suite.tscn']
with captured.open('wb') as stream: result=subprocess.run(cmd,env=env,cwd=root,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
text=engine.read_text(encoding='utf-8',errors='replace')
report={'exit':result.returncode,'strict_clean':result.returncode==0 and 'ERROR:' not in text and 'SCRIPT ERROR' not in text and 'FAIL |' not in text and 'PASS' in text,'engine_errors':[x for x in text.splitlines() if 'ERROR:' in x or 'FAIL |' in x]}
(out/'battlefield-final-exit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
