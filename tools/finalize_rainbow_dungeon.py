"""Record concrete integration, original image hashes and validation evidence."""
from pathlib import Path
import json, hashlib, re
root=Path(__file__).resolve().parents[1]; out=root/'artifacts/rainbow-dungeon'
sources={"lava_slime":"C:\\Users\\Furion Mashiou\\.codex\\generated_images\\01a13f7b-1c3a-7902-9fa9-769710805a9b\\exec-665d0a87-d09b-429a-ad66-c4be92a363ca.png","lava_beast":"C:\\Users\\Furion Mashiou\\.codex\\generated_images\\01a13f7b-1c3a-7902-9fa9-769710805a9b\\exec-60c63718-f3bf-491b-9282-cf289ffd93f3.png","lava_priest":"C:\\Users\\Furion Mashiou\\.codex\\generated_images\\01a13f7b-1c3a-7902-9fa9-769710805a9b\\exec-375e025c-5823-438a-848a-dc3af4bde7a2.png","fire_dragon":"C:\\Users\\Furion Mashiou\\.codex\\generated_images\\01a13f7b-1c3a-7902-9fa9-769710805a9b\\exec-3c517d9e-41a5-458f-aa2d-2624fd20a6da.png","temple_props":"C:\\Users\\Furion Mashiou\\.codex\\generated_images\\01a13f7b-1c3a-7902-9fa9-769710805a9b\\exec-824a546a-f21f-46c5-b3e4-7f777025f9e2.png"}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
records={}
for key,source in sources.items():
    name='temple-props' if key=='temple_props' else key
    target=root/f'features/rainbow/art/{name}-v1.png'
    records[key]={'original':source,'integrated':str(target.relative_to(root)),'source_sha256':sha(Path(source)),'integrated_sha256':sha(target),'identical':sha(Path(source))==sha(target)}
assert all(item['identical'] for item in records.values())
(out/'asset-provenance.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
baseline=json.loads((root/'artifacts/rainbow-content/full-regression.json').read_text(encoding='utf-8'))
current=json.loads((out/'full-regression.json').read_text(encoding='utf-8'))
names=lambda values:{re.sub(r' exit -?\d+$','',x) for x in values}
comparison={'prior_failed':baseline['failed'],'current_failed':current['failed'],'additional':sorted(names(current['failures'])-names(baseline['failures'])),'resolved':sorted(names(baseline['failures'])-names(current['failures'])),'targeted_rerun':json.loads((out/'battlefield-final-exit.json').read_text(encoding='utf-8'))}
(out/'regression-comparison.json').write_text(json.dumps(comparison,indent=2),encoding='utf-8')
index=root/'specs/context_map.json'; text=index.read_text(encoding='utf-8')
text=text.replace('只在指定地圖的真實遭遇啟用；其他區域保留RTS。11兵種使用獨立動作圖集與Weapon Resource；原生熔岩地板保留導航。SettlementService仍是結算權威。','只在火龍神殿真實遭遇啟用；其他區域保留RTS。四廳10怪隊4戰場，四原創怪物與祭司／火龍機制；11友軍動作外觀。新增槽位保留舊存檔，Boss抗擊退，SettlementService仍是結算權威。')
index.write_text(text,encoding='utf-8')
paths=set()
for folder in ['features/rainbow','features/units/data/monsters','features/world/data','features/battle/maps']:
    for p in (root/folder).rglob('*'):
        if not p.is_file() or p.suffix in ['.import','.uid']: continue
        rel=str(p.relative_to(root)).replace('\\','/')
        if folder=='features/rainbow' or any(x in p.name for x in ['rainbow','lava_beast','lava_priest','fire_dragon']): paths.add(rel)
for pattern in ['tools/*rainbow*dungeon*','tools/anchor_rainbow_pillars.gd','tools/author_rainbow_monsters.py','tools/repair_rainbow_native_refs.gd','tools/check_rainbow_battlefield_exit.py','tests/rainbow*','docs/rainbow_action.md','specs/context_map.json','AGENTS.md']:
    for p in root.glob(pattern):
        if p.is_file() and p.suffix!='.uid': paths.add(str(p.relative_to(root)).replace('\\','/'))
manifest={rel:sha(root/rel) for rel in sorted(paths)}
(out/'delivery-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps({'original_images_verified':len(records),'manifest_files':len(manifest),'regression':comparison},indent=2))
