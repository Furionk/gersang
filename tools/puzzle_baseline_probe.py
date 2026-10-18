"""Build an isolated pre-feature baseline copy for regression attribution."""
from pathlib import Path
import os
import shutil
root = Path(__file__).resolve().parents[1]
dest = root/'artifacts/puzzle-world/baseline-project-v2'
if dest.exists(): raise SystemExit('Baseline exists; refusing replacement.')
before = root/'artifacts/puzzle-world/before'
replacements = {
    'common/data/unit_definition.gd':before/'unit_definition.gd',
    'features/battle/game_director.gd':before/'game_director.gd',
    'features/world/data/river_bay.tscn':before/'river_bay.tscn',
}
for p in (before/'mercenaries').glob('*.tres'):
    replacements['features/units/data/mercenaries/'+p.name]=p
for directory,dirs,files in os.walk(root):
    rel = Path(directory).relative_to(root)
    dirs[:] = [d for d in dirs if d not in ['artifacts','.git','.agents','.codex','__pycache__']]
    if rel==Path('.godot'):
        dirs[:] = [d for d in dirs if d=='imported']
        files = [f for f in files if f=='global_script_class_cache.cfg']
    (dest/rel).mkdir(parents=True,exist_ok=True)
    for name in files:
        path = rel/name
        key = path.as_posix()
        target = dest/path
        if key in replacements: shutil.copy2(replacements[key],target)
        elif key=='features/progression/combat_stats.gd':
            text=(root/path).read_text(encoding='utf-8')
            text=text.replace('\tif data.puzzle_monster != null:\n\t\tvalues["health"] = data.puzzle_monster.monster_health()\n','')
            target.write_text(text,encoding='utf-8')
        elif path.suffix.lower() in ['.png','.jpg','.ogg','.mp3','.otf','.ttf','.ctex']:
            shutil.copy2(root/path,target)
        else: shutil.copy2(root/path,target)
# Existing legacy suites need their own historical fixture files, read-only linked.
for directory,dirs,files in os.walk(root/'artifacts'):
    if Path(directory)==root/'artifacts': dirs[:]=[d for d in dirs if d!='puzzle-world']
    rel=Path(directory).relative_to(root)
    for name in files:
        if Path(name).suffix not in ['.tscn','.tres','.json','.dat']: continue
        target=dest/rel/name
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(Path(directory)/name,target)
print(dest)
