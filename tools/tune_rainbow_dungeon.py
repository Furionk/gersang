"""Reviewed content tuning and native facing metadata; generated pixels remain untouched."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
if 'metadata/rainbow_balance_v1' in (root/'features/units/data/monsters/fire_dragon.tres').read_text(encoding='utf-8'):
    raise SystemExit('Balance already authored; edit native Resources rather than rerunning this tool.')
for name,hp,damage in [('lava_priest',2800,32),('fire_dragon',4200,36)]:
    p=root/f'features/units/data/monsters/{name}.tres'
    lines=p.read_text(encoding='utf-8').splitlines()
    lines=[f'max_health = {hp}.0' if l.startswith('max_health = ') else f'damage = {damage}.0' if l.startswith('damage = ') else l for l in lines]
    if name=='fire_dragon': lines=['defense = 2.0' if l.startswith('defense = ') else l for l in lines]
    if name=='fire_dragon': lines.append('metadata/rainbow_balance_v1 = true')
    p.write_text('\n'.join(lines)+'\n',encoding='utf-8')
p=root/'features/rainbow/data/enemies/fire_dragon.tres'
text=p.read_text(encoding='utf-8').replace('armored_damage_scale = 0.65','armored_damage_scale = 0.8').replace('melee_power = 1.2','melee_power = 1.0').replace('special_power = 110.0','special_power = 100.0')
p.write_text(text,encoding='utf-8')
for name in ['lava_slime','lava_beast','lava_priest','fire_dragon']:
    p=root/f'features/rainbow/data/skins/{name}.tres'
    text=p.read_text(encoding='utf-8').replace('direction_rows = Array[int]([0, 0, 0, 1, 1, 3, 3, 2])','direction_rows = Array[int]([0, 0, 0, 1, 1, 2, 2, 3])')
    if name in ['lava_beast','fire_dragon']:
        for clip in [2,3]:
            token=f'[sub_resource type="Resource" id="clip{clip}"]\n'
            fields='direction_rows = PackedInt32Array(0, 0, 0, 1, 1, 3, 3, 3)\nmirrored_directions = Array[bool]([false, false, false, false, false, true, true, false])\n'
            text=text.replace(token+fields,token)
            if fields not in text.split(token)[1].split('[sub_resource')[0]: text=text.replace(token+'script = ExtResource("2")\n',token+'script = ExtResource("2")\n'+fields)
    p.write_text(text,encoding='utf-8')
print('Boss HP/attack tuned; four painted facing maps and mirrored NW attacks corrected.')
