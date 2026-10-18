"""One-shot native monster atlas metadata. Source RGBA files are copied unchanged."""
from pathlib import Path
import json, shutil, hashlib
import author_rainbow_skins as skins

ROOT=Path(__file__).resolve().parents[1]
SOURCES={"lava_slime":"C:\\Users\\Furion Mashiou\\.codex\\generated_images\\01a13f7b-1c3a-7902-9fa9-769710805a9b\\exec-665d0a87-d09b-429a-ad66-c4be92a363ca.png","lava_beast":"C:\\Users\\Furion Mashiou\\.codex\\generated_images\\01a13f7b-1c3a-7902-9fa9-769710805a9b\\exec-60c63718-f3bf-491b-9282-cf289ffd93f3.png","lava_priest":"C:\\Users\\Furion Mashiou\\.codex\\generated_images\\01a13f7b-1c3a-7902-9fa9-769710805a9b\\exec-375e025c-5823-438a-848a-dc3af4bde7a2.png","fire_dragon":"C:\\Users\\Furion Mashiou\\.codex\\generated_images\\01a13f7b-1c3a-7902-9fa9-769710805a9b\\exec-3c517d9e-41a5-458f-aa2d-2624fd20a6da.png"}

def main():
    out=ROOT/'artifacts/rainbow-dungeon'
    out.mkdir(parents=True,exist_ok=True)
    (out/'.gdignore').touch()
    files=['features/rainbow/action_actor.gd','features/rainbow/action_battle.gd','features/rainbow/action_hud.gd','features/rainbow/action_profile.gd','features/rainbow/data/default_action.tres','features/world/data/rainbow_temple.tscn','features/units/data/monsters/rainbow_slime.tres','tests/rainbow_action_suite.gd','tests/rainbow_content_suite.gd','docs/rainbow_action.md','AGENTS.md']
    if (out/'before').exists(): raise SystemExit('Already authored; preserve artist changes')
    for file in files:
        dest=out/'before'/file; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/file,dest)
    for name,source in SOURCES.items(): shutil.copy2(source,ROOT/'features/rainbow/art'/(name+'-v1.png'))
    # Shared alpha metadata authoring; never modifies image pixels.
    skins.IDS=list(SOURCES)
    historical=ROOT/'artifacts/rainbow-content/atlas-audit.json'
    prior=historical.read_bytes()
    try:
        skins.main()
        shutil.copy2(historical,out/'atlas-audit.json')
    finally:
        historical.write_bytes(prior)
    provenance={name:{'original':source,'sha256':hashlib.sha256(Path(source).read_bytes()).hexdigest()} for name,source in SOURCES.items()}
    (out/'asset-provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
    print('Four original monster sheets and native layouts installed.')

if __name__=='__main__': main()
