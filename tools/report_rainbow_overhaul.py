"""Collect immutable asset hashes and current test evidence; no gameplay mutations."""
from pathlib import Path
import hashlib, json, re

root = Path(__file__).resolve().parents[1]
out = root / 'artifacts/rainbow-overhaul'
source = Path.home() / '.codex/generated_images/01a13f7b-1c3a-7902-9fa9-769710805a9b'
assets = {
    'temple-creatures-v2.png': 'exec-27b5f41d-294b-414e-aa37-54819ef8a516.png',
    'dragon-tiers-v3.png': 'exec-e2ce3fc6-bc17-41e9-b791-0df0c1f3864a.png',
    'branch-landmarks-v1.png': 'exec-d7f1ada6-6dba-4966-91fa-66cf4c5a0f3d.png',
}
manifest = []
for name, original in assets.items():
    target = root / 'features/rainbow/art' / name
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    original_path = source / original
    manifest.append(dict(project=str(target), source=str(original_path), sha256=digest,
                         original_matches=hashlib.sha256(original_path.read_bytes()).hexdigest() == digest))
(out / 'asset-provenance.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
results = []
for log in sorted(out.glob('*.log')):
    text = log.read_text(encoding='utf-8', errors='replace')
    results.append(dict(log=log.name, results=[line for line in text.splitlines() if '_RESULT' in line],
                        metrics=[json.loads(line.split('NATURAL_METRICS ', 1)[1]) for line in text.splitlines() if line.startswith('NATURAL_METRICS ')],
                        script_error='SCRIPT ERROR' in text))
(out / 'evidence-index.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
balance = {}
for name in ['fire_dragon', 'lava_priest']:
    for tier in range(4):
        unit_id = name if tier == 0 else f'{name}_tier_{tier}'
        text = (root / f'features/units/data/monsters/{unit_id}.tres').read_text(encoding='utf-8')
        balance[unit_id] = {key: float(re.search(rf'^{key} = ([\d.]+)', text, re.M)[1]) for key in ['max_health', 'level', 'balance_revision']}
(out / 'final-resource-balance.json').write_text(json.dumps(balance, indent=2), encoding='utf-8')
print('Evidence collected:', len(results), 'logs;', len(manifest), 'original asset hashes verified')
