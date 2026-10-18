from pathlib import Path
root=Path(__file__).resolve().parents[1]
scene=root/'features/world/data/river_bay.tscn'
text=scene.read_text(encoding='utf-8')
assert 'MonkeyHardRegion' not in text, 'Already authored; edit resources in place.'
region=text[text.index('[node name="MonkeyGardenRegion"'):]
for key,title,seconds,speed,burst,decision,dodge,jump,offset in [
    ('hard','疾風林道',120,1.45,1.45,.6,.65,.6,(-280,340)),
    ('mania','狂亂獵場',90,1.7,1.55,.4,.85,.5,(-380,-110))]:
    profile=f'''[gd_resource type="Resource" script_class="MonkeyProfile" load_steps=2 format=3]
[ext_resource type="Script" path="res://features/monkey/monkey_profile.gd" id="1"]
[resource]
script = ExtResource("1")
zone_name = "{title}"
time_limit = {float(seconds)}
escape_multiplier = {speed}
burst_multiplier = {burst}
decision_seconds = {decision}
dodge_chance = {dodge}
jump_seconds = {jump}
'''
    (root/f'features/monkey/data/{key}.tres').write_text(profile,encoding='utf-8')
    arena=(root/'features/world/data/monkey_garden_arena.tres').read_text(encoding='utf-8').replace('data/default.tres',f'data/{key}.tres').replace('"monkey_garden"',f'"monkey_garden_{key}"').replace('庭園捕猴',title)
    (root/f'features/world/data/monkey_garden_{key}_arena.tres').write_text(arena,encoding='utf-8')
    habitat=(root/'features/monkey/data/habitat.tres').read_text(encoding='utf-8').replace('monkey_garden_five',f'monkey_garden_{key}_five').replace('庭園猴子隊 · 3D捕猴',f'{title} · {seconds}秒').replace('"meadow"',f'"monkey_garden_{key}"')
    (root/f'features/monkey/data/habitat_{key}.tres').write_text(habitat,encoding='utf-8')
    name='MonkeyHardRegion' if key=='hard' else 'MonkeyManiaRegion'
    new=region.replace('MonkeyGardenRegion',name).replace('Vector2(120, 340)',f'Vector2({offset[0]}, {offset[1]})').replace('"monkey_garden_region"',f'"monkey_garden_{key}_region"').replace('庭園猴子隊 · 3D捕猴',f'{title} · {seconds}秒').replace('"monkey_garden"',f'"monkey_garden_{key}"').replace('ExtResource("monkey_habitat")',f'ExtResource("monkey_{key}_habitat")')
    ext=f'[ext_resource type="Resource" path="res://features/monkey/data/habitat_{key}.tres" id="monkey_{key}_habitat"]\n'
    first=text.index('[sub_resource')
    text=text[:first]+ext+'\n'+text[first:]+ '\n'+new
scene.write_text(text,encoding='utf-8')
