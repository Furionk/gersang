extends "res://tools/author_shenchao_tower.gd"
# One-shot, new dungeon only; preserve authored tower navigation and unrelated content.
const ART: String="res://art/terrain/shenchao_abyss/"
func artwork(parent: Node,id: String,path: String,point: Vector2,extent: Vector2,alpha: float=1.0)->Sprite2D:
	var sprite: Sprite2D=Sprite2D.new();sprite.name=id;sprite.texture=load(path)
	sprite.position=point;sprite.scale=extent/sprite.texture.get_size();sprite.modulate.a=alpha
	sprite.set_meta("world_scenery_id",id);sprite.set_meta("scenery_sort_override",0)
	parent.add_child(sprite);return sprite
func population(parent: Node,id: String,rect: Rect2,boss: bool=false)->void:
	var area: WorldMonsterRegion=WorldMonsterRegion.new();area.name=id;area.stable_id=id
	area.display_name="轉珠之鬼 · 終極試煉" if boss else "暗密群珠 · Lv99"
	area.monster=load("res://features/units/data/monsters/tower_ghost.tres" if boss else "res://features/units/data/monsters/tower_dark.tres")
	area.party_count=1 if boss else 3;area.minimum_units=1 if boss else 12;area.maximum_units=1 if boss else 18
	area.minimum_level=100 if boss else 99;area.maximum_level=area.minimum_level;area.aggressive=false
	area.respawn_min_seconds=90 if boss else 20;area.respawn_max_seconds=120 if boss else 30
	area.battlefields=PackedStringArray(["shenchao_abyss"])
	area.habitat=WorldHabitat.new();area.habitat.profile=SpawnProfile.new();area.habitat.profile.speed=40 if boss else 110
	area.habitat.profile.rules.max_enemy_parties=1;area.habitat.profile.rules.reinforcement_chance=0
	parent.add_child(area)
	for i: int in 3:
		var poly: WorldRegionPolygon=WorldRegionPolygon.new();poly.name=["SpawnArea","RoamingArea","PursuitArea"][i]
		var shape: Rect2=rect.grow(-32) if i==0 else rect
		var vertices: PackedVector2Array=PackedVector2Array()
		for point: Vector2 in [shape.position,Vector2(shape.end.x,shape.position.y),shape.end,Vector2(shape.position.x,shape.end.y)]:vertices.append(Iso.project(point))
		poly.polygon=vertices;area.add_child(poly)
func run()->void:
	if FileAccess.file_exists("res://features/world/data/shenchao_abyss.tscn"):
		push_error("Secret abyss exists; refusing overwrite");quit(1);return
	var rules: PuzzleRules=load("res://features/puzzle/data/tower_dark_rules.tres").duplicate()
	rules.enemy_texture=load(ART+"orb-ghost-v1.png");rules.monster_health_attack_multiple=1800
	rules.monster_level=100;rules.enemy_attack_fraction=0.18;rules.enemy_cooldown_seconds=1.6
	rules.enemy_initial_min_seconds=6;rules.enemy_initial_max_seconds=6
	save(rules,"res://features/puzzle/data/tower_ghost_rules.tres")
	var layout: SpriteSheetLayout=load("res://features/puzzle/data/pearl_layout.tres").duplicate(true)
	layout.source_texture=rules.enemy_texture;layout.foot_point=Vector2(627,1190);layout.source_pivots.assign([layout.foot_point])
	save(layout,"res://features/puzzle/data/ghost_layout.tres")
	var ghost: UnitDefinition=load("res://features/units/data/monsters/tower_dark.tres").duplicate()
	ghost.id=&"tower_ghost";ghost.display_name="轉珠之鬼";ghost.level=100;ghost.balance_revision=1
	ghost.puzzle_monster=rules;ghost.sprite_layout=layout;ghost.sprite_path=ART+"orb-ghost-v1.png"
	ghost.sprite_tint=Color.WHITE;ghost.world_sprite_scale=0.28;ghost.battle_sprite_scale=0.32;ghost.experience_reward=60000
	ghost.tactical_hint="暗密空間的終極守主；六秒後開始每1.6秒攻擊，持續高速轉珠。"
	save(ghost,"res://features/units/data/monsters/tower_ghost.tres")
	var root: WorldMap2D=WorldMap2D.new();root.name="ShenchaoAbyss";root.native_tiles_enabled=true
	root.definition=WorldMapDefinition.new();root.definition.map_id="shenchao_abyss";root.definition.display_name="暗密空間 · 轉珠之鬼"
	root.definition.kind=WorldMapDefinition.Kind.DUNGEON;root.definition.extent=Vector2(2048,2048)
	root.definition.safe_return_map_id="shenchao_tower";root.definition.safe_return_entry_id="abyss_return"
	var ground: Node2D=node(root,"Ground")
	var empty_floor: WorldTileLayer=WorldTileLayer.new();empty_floor.name="Ground_TileMap";empty_floor.position=Vector2(-32,0);empty_floor.tile_set=load("res://features/world/data/tiles/shaolin_temple_masks.tres");ground.add_child(empty_floor)
	for role: int in [WorldTileLayer.Role.WALKABLE,WorldTileLayer.Role.SAFE]:
		var layer: WorldTileLayer=WorldTileLayer.new();layer.name="Walkable_Mask" if role==2 else "Safe_Mask"
		layer.role=role;layer.position=Vector2(-32,0);layer.tile_set=load("res://features/world/data/tiles/shaolin_temple_masks.tres")
		for x: int in range(4,60):
			for y: int in range(4,60):
				if role==2 or (x>=28 and x<36 and y>=52):layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
		ground.add_child(layer)
	var decor: Node2D=node(root,"Scenery")
	var sky: Sprite2D=artwork(decor,"AbyssBackdrop",ART+"abyss-v1.png",Vector2(0,700),Vector2(6000,3375))
	sky.offset.y=800.0/sky.scale.y
	artwork(decor,"GlassPlatform",ART+"glass-platform-v1.png",Vector2(0,1024),Vector2(4096,2048),0.52)
	var entries: Node2D=node(root,"Entrances")
	arrival(entries,"entrance",Vector2(1024,1744));portal(entries,"abyss_exit",Vector2(1024,1880),"shenchao_tower","abyss_return")
	var exit: WorldAuthorNode=entries.get_node("abyss_exit");exit.display_name="返回神抄之塔";exit.sprite_definition=load("res://art/terrain/shenchao_tower/celestial-gate-v1.tres")
	var regions: Node2D=node(root,"MonsterRegions")
	var rects: Array[Rect2]=[Rect2(192,576,704,480),Rect2(1152,576,704,480),Rect2(192,1184,704,384),Rect2(1152,1184,704,384)]
	for i: int in 4:population(regions,"dark_guard_"+str(i),rects[i])
	population(regions,"final_ghost",Rect2(832,192,384,320),true)
	pack(root,"res://features/world/data/shenchao_abyss.tscn");root.free()
	var battle: BattlefieldMap=load("res://features/battle/maps/shenchao_tower.tscn").instantiate()
	battle.name="ShenchaoAbyssBattle";battle.arena_id="shenchao_abyss"
	for child: Node in battle.get_node("Scenery").get_children():child.free()
	var backdrop: Sprite2D=battle.get_node("CloudSeaBackdrop");backdrop.texture=load(ART+"abyss-v1.png");backdrop.material=null;backdrop.region_enabled=false;backdrop.scale=Vector2(6,6)
	for child: Node in battle.get_node("Terrain").get_children():
		if child is TileMapLayer:child.modulate=Color(0.12,0.09,0.19,0.3)
	artwork(battle.get_node("Scenery"),"BattleGlass",ART+"glass-platform-v1.png",Vector2(120,760),Vector2(3300,1650),0.65)
	pack(battle,"res://features/battle/maps/shenchao_abyss.tscn");battle.free()
	var arena: ArenaDefinition=load("res://features/world/data/shenchao_tower_arena.tres").duplicate(true)
	arena.arena_id="shenchao_abyss";arena.encounter.id=&"shenchao_abyss";arena.encounter.display_name="暗密空間";arena.encounter.battlefield_scene="res://features/battle/maps/shenchao_abyss.tscn"
	save(arena,"res://features/world/data/shenchao_abyss_arena.tres")
	var tower: WorldMap2D=load("res://features/world/data/shenchao_tower.tscn").instantiate()
	var compiled: WorldMapDefinition=tower.compile_definition()
	for i: int in 4:
		var id: String="dark_guard_"+str(i)
		tower.definition.retired_habitats.append(compiled.habitat(id))
		tower.get_node("MonsterRegions/"+id).free()
	portal(tower.get_node("Entrances"),"abyss_door",Vector2(1280,128),"shenchao_abyss","entrance")
	var door: WorldAuthorNode=tower.get_node("Entrances/abyss_door");door.display_name="暗密空間 · 終極試煉";door.sprite_definition=load("res://art/terrain/shenchao_tower/celestial-gate-v1.tres")
	arrival(tower.get_node("Entrances"),"abyss_return",Vector2(1280,288))
	var sign: WorldAuthorNode=tower.get_node_or_null("Scenery/tier_sign_3")
	if sign!=null:sign.display_name="四階 Lv95 · 2秒攻擊 · 塔頂通往暗密空間"
	pack(tower,"res://features/world/data/shenchao_tower.tscn");tower.free()
	print("ABYSS_AUTHORED 12 dark hordes + one final ghost; tower native geometry preserved")
	quit()
