"""One-shot additive authoring. Refuses to overwrite an existing puzzle population."""
from pathlib import Path
import re
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
scene = ROOT / 'features/world/data/river_bay.tscn'
source = scene.read_text(encoding='utf-8-sig')
if 'stable_id = "puzzle_fire"' in source:
    raise SystemExit('Already authored; edit native Resources/scenes instead.')

def write(path, content):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8', newline='\n')

layout = '''[gd_resource type="Resource" script_class="SpriteSheetLayout" format=3]
[ext_resource type="Script" path="res://common/data/sprite_sheet_layout.gd" id="1"]
[ext_resource type="Script" path="res://common/data/sprite_animation_clip.gd" id="2"]
[ext_resource type="Texture2D" path="res://features/puzzle/art/pearl-monster-v1.png" id="3"]
'''
for i in range(5):
    layout += f'\n[sub_resource type="Resource" id="clip{i}"]\nscript = ExtResource("2")\naction = {i}\ncolumns = PackedInt32Array(0)\nloop = {"true" if i < 2 else "false"}\n'
layout += '''
[resource]
script = ExtResource("1")
source_texture = ExtResource("3")
source_size = Vector2i(1254, 1254)
columns = 1
rows = 1
frame_size = Vector2i(1254, 1254)
foot_point = Vector2(627, 934)
frame_rects = Array[Rect2i]([Rect2i(0, 0, 1254, 1254)])
source_pivots = Array[Vector2]([Vector2(627, 934)])
animations = Array[ExtResource("2")]([SubResource("clip0"),SubResource("clip1"),SubResource("clip2"),SubResource("clip3"),SubResource("clip4")])
attack_columns = Array[int]([0])
direction_rows = Array[int]([0,0,0,0,0,0,0,0])
'''
write('features/puzzle/data/pearl_layout.tres',layout)
elements = [('fire','火','river','0.94, 0.39, 0.3'),('water','水','forest','0.30, 0.72, 0.93'),('grass','草','farm','0.42, 0.81, 0.57'),('electric','電','mountain','0.96, 0.83, 0.40')]
external = ''
new_nodes = ''
node_blocks = re.split(r'(?=\[node )',source)
for element,(slug,label,region,tint) in enumerate(elements):
    name = 'puzzle_'+slug
    write(f'features/units/data/monsters/{name}.tres',f'''[gd_resource type="Resource" script_class="UnitDefinition" format=3]
[ext_resource type="Script" path="res://common/data/unit_definition.gd" id="1"]
[ext_resource type="Resource" path="res://features/puzzle/data/default_rules.tres" id="2"]
[ext_resource type="Resource" path="res://features/puzzle/data/pearl_layout.tres" id="3"]
[resource]
script = ExtResource("1")
id = &"{name}"
display_name = "{label}轉珠怪"
puzzle_element = {element}
puzzle_monster = ExtResource("2")
level = 25
experience_reward = 80
speed = 360.0
damage = 0.0
attack_range = 56.0
attack_interval = 1.0
sprite_path = "res://features/puzzle/art/pearl-monster-v1.png"
sprite_layout = ExtResource("3")
sprite_tint = Color({tint}, 1)
battle_sprite_scale = 0.14
world_sprite_scale = 0.11
tactical_hint = "首次攻擊進入轉珠世界；消除同屬性珠可讓兵種出手。"
''')
    write(f'features/puzzle/data/{name}_habitat.tres',f'''[gd_resource type="Resource" script_class="WorldHabitat" format=3]
[ext_resource type="Script" path="res://features/world/definitions/world_habitat.gd" id="1"]
[ext_resource type="Script" path="res://features/world/definitions/spawn_profile.gd" id="2"]
[sub_resource type="Resource" id="profile"]
script = ExtResource("2")
speed = 255.0
target_party_count = 10
[resource]
script = ExtResource("1")
habitat_id = "{name}"
display_name = "{label}轉珠怪棲地"
profile = SubResource("profile")
''')
    external += f'[ext_resource type="Resource" path="res://features/units/data/monsters/{name}.tres" id="{name}"]\n'
    external += f'[ext_resource type="Resource" path="res://features/puzzle/data/{name}_habitat.tres" id="{name}_habitat"]\n'
    for block in node_blocks[1:]:
        header = block.splitlines()[0]
        is_region = f'name="{region}" ' in header and 'parent="MonsterRegions"' in header
        is_child = f'parent="MonsterRegions/{region}' in header
        is_mask = any(f'name="{prefix}_{region}"' in header for prefix in ['Spawn','Activity','Chase'])
        # Native names vary; identify masks by their actual region_id.
        is_mask = 'type="TileMapLayer"' in header and f'region_id = "{region}"' in block
        if not (is_region or is_child or is_mask): continue
        clone = re.sub(r' unique_id=\d+', '', block)
        clone = clone.replace(f'MonsterRegions/{region}',f'MonsterRegions/{name}')
        clone = clone.replace(f'region_id = "{region}"',f'region_id = "{name}"')
        if is_mask:
            clone = re.sub(r'\[node name="([^"]+)"',lambda m:f'[node name="{m[1]}_{name}"',clone,count=1)
        if is_region:
            clone = clone.replace(f'name="{region}"',f'name="{name}"',1)
            updates = {'simple_party':'true','monster':f'ExtResource("{name}")','minimum_units':'1','maximum_units':'3','minimum_level':'25','maximum_level':'25','party_count':'10','aggressive':'true','stable_id':f'"{name}"','display_name':f'"{label}轉珠怪棲地"','habitat':f'ExtResource("{name}_habitat")'}
            for key,value in updates.items():
                pattern = rf'^{key} = .*?$'
                if re.search(pattern,clone,re.M): clone = re.sub(pattern,f'{key} = {value}',clone,flags=re.M)
                else: clone = clone.rstrip()+f'\n{key} = {value}\n\n'
        new_nodes += clone.rstrip()+'\n\n'
source = source.replace('[sub_resource ',external+'\n[sub_resource ',1)
scene.write_text(source.rstrip()+'\n\n'+new_nodes,encoding='utf-8',newline='\n')
mapping = {'gunner':0,'teppo':0,'merchant':1,'guard':1,'kohime':1,'healer':2,'supplier':2,'malfory':2,'mage':3,'controller':3,'ninja':3}
for name,element in mapping.items():
    path = ROOT/f'features/units/data/mercenaries/{name}.tres'
    content = path.read_text(encoding='utf-8-sig')
    content = re.sub(r'(\[resource\]\nscript = [^\n]+\n)',lambda m:m[1]+f'puzzle_element = {element}\n',content,count=1)
    path.write_text(content,encoding='utf-8',newline='\n')
manifest = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'artifacts/puzzle-world/before').rglob('*') if p.is_file()}
write('artifacts/puzzle-world/before-hashes.json',json.dumps(manifest,indent=2))
print('Added four native regions and twelve native mask layers; original nodes preserved.')
