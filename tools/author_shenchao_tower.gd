extends SceneTree
# One-shot authoring; existing tower is never overwritten.
var units: Array[UnitDefinition] = []
func _initialize() -> void: call_deferred("run")
func save(data: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	assert(ResourceSaver.save(data,path)==OK)
	data.take_over_path(path)
func node(parent:Node,name:String)->Node2D:
	var result:Node2D=Node2D.new();result.name=name;parent.add_child(result);return result
func own(root:Node,branch:Node)->void:
	for child:Node in branch.get_children(): child.owner=root;own(root,child)
func arrival(parent:Node,id:String,point:Vector2)->WorldAuthorNode:
	var entry:WorldAuthorNode=WorldAuthorNode.new();entry.name=id;entry.stable_id=id;entry.kind=WorldAuthorNode.Kind.ARRIVAL;entry.coordinate_space=WorldAuthorNode.CoordinateSpace.CANVAS;entry.position=Iso.project(point);parent.add_child(entry);return entry

func pack(root: Node, path: String) -> void:
	own(root,root)
	var packed: PackedScene=PackedScene.new()
	assert(packed.pack(root)==OK)
	save(packed,path)
func portal(parent: Node,id: String,point: Vector2,target: String,entry: String) -> void:
	var door: WorldAuthorNode=arrival(parent,id,point)
	door.kind=WorldAuthorNode.Kind.PORTAL; door.target_map_id=target; door.target_entry_id=entry
	door.display_name="神抄之塔 · 極速轉珠" if target=="shenchao_tower" else "返回青嶺河灣"
	door.trigger_radius=80
	door.sprite_definition=load("res://features/world/data/scenery/shaolin_gate.tres")
func region(parent: Node,id: String,title: String,rect: Rect2,tier: int,element: int,boss: bool=false) -> void:
	var area: WorldMonsterRegion=WorldMonsterRegion.new()
	area.name=id;area.stable_id=id;area.display_name=title;area.simple_party=false
	area.party_count=1 if boss else 2;area.aggressive=true;area.battlefields=PackedStringArray(["shenchao_tower"])
	area.respawn_min_seconds=90 if boss else 25;area.respawn_max_seconds=120 if boss else 40
	area.habitat=WorldHabitat.new();area.habitat.profile=SpawnProfile.new()
	var profile: SpawnProfile=area.habitat.profile
	profile.speed=220 if boss else 255
	profile.rules.max_enemy_parties=1
	profile.rules.reinforcement_chance=0
	var party: PartyTemplate=PartyTemplate.new();party.template_id=id+"_party";party.display_name=title
	party.representative=units[12+element] if boss else units[tier*4+element]
	var count: int=3 if boss else tier+1
	for slot: int in count:
		var member: MemberRule=MemberRule.new()
		member.definition=party.representative if slot==0 else units[tier*4+(element+slot)%4]
		member.min_level=90 if boss and slot==0 else 30+tier*20
		member.max_level=member.min_level if boss and slot==0 else member.min_level+9
		member.min_count=1 if boss else 2
		member.max_count=1 if boss else 3
		party.members.append(member)
	profile.templates.append(party)
	parent.add_child(area)
	for i: int in 3:
		var polygon: WorldRegionPolygon=WorldRegionPolygon.new();polygon.name=["SpawnArea","RoamingArea","PursuitArea"][i]
		var shape: Rect2=rect.grow(-32) if i==0 else rect
		var vertices: PackedVector2Array=PackedVector2Array()
		for point: Vector2 in [shape.position,Vector2(shape.end.x,shape.position.y),shape.end,Vector2(shape.position.x,shape.end.y)]: vertices.append(Iso.project(point))
		polygon.polygon=vertices
		area.add_child(polygon)
func run() -> void:
	if FileAccess.file_exists("res://features/world/data/shenchao_tower.tscn"):
		push_error("Tower exists; refusing overwrite");quit(1);return
	for tier: int in 4:
		var rules: PuzzleRules=load("res://features/puzzle/data/default_rules.tres").duplicate()
		rules.monster_health_attack_multiple=[12.0,15.0,18.0,60.0][tier]
		rules.enemy_cooldown_seconds=[10.0,9.0,8.0,4.5][tier]
		rules.enemy_initial_min_seconds=[8.0,7.0,6.0,5.0][tier]
		rules.enemy_initial_max_seconds=[12.0,10.0,9.0,7.0][tier]
		rules.enemy_attack_fraction=[0.05,0.045,0.04,0.12][tier]
		save(rules,"res://features/puzzle/data/tower_tier_"+str(tier)+".tres")
		for element: int in 4:
			var unit: UnitDefinition=load("res://features/units/data/monsters/puzzle_"+["fire","water","grass","electric"][element]+".tres").duplicate()
			unit.id=StringName("tower_"+str(tier)+"_"+str(element))
			unit.display_name=["火","水","草","電"][element]+["珠衛","珠術士","精銳珠將","轉珠王"][tier]
			unit.level=90 if tier==3 else 30+tier*20;unit.puzzle_monster=rules
			unit.experience_reward=[120,240,480,5000][tier]
			if tier==3: unit.battle_sprite_scale=0.23;unit.world_sprite_scale=0.18
			save(unit,"res://features/units/data/monsters/"+String(unit.id)+".tres");units.append(unit)
	var source: WorldMap2D=load("res://features/world/data/shaolin_temple.tscn").instantiate()
	var root: WorldMap2D=WorldMap2D.new();root.name="ShenchaoTower";root.native_tiles_enabled=true
	root.definition=WorldMapDefinition.new();root.definition.map_id="shenchao_tower";root.definition.display_name="神抄之塔 · 極速轉珠"
	root.definition.kind=WorldMapDefinition.Kind.DUNGEON;root.definition.extent=Vector2(2560,3840)
	root.definition.safe_return_map_id="river_bay";root.definition.safe_return_entry_id="tower_return"
	var ground: Node2D=node(root,"Ground")
	for role: int in [WorldTileLayer.Role.GROUND,WorldTileLayer.Role.WALKABLE,WorldTileLayer.Role.OBSTACLES]:
		var layer: WorldTileLayer=WorldTileLayer.new();layer.name={0:"Ground_TileMap",2:"Walkable_Mask",1:"Obstacles_TileMap"}[role];layer.role=role;layer.position=Vector2(-32,0)
		layer.tile_set=source.get_node("Ground/Ground_TileMap").tile_set if role==0 else source.get_node("Ground/Walkable_Mask").tile_set
		for x: int in 80:
			for y: int in 120:
				var wall: bool=x<2 or x>77 or y<2 or y>117 or (y in [30,58,86] and (x<35 or x>44))
				if role==WorldTileLayer.Role.GROUND or (role==WorldTileLayer.Role.OBSTACLES and wall) or (role==WorldTileLayer.Role.WALKABLE and not wall): layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
		if role==WorldTileLayer.Role.GROUND: layer.modulate=Color(0.36,0.48,0.62)
		ground.add_child(layer)
	var entrances: Node2D=node(root,"Entrances")
	arrival(entrances,"entrance",Vector2(1280,3650));portal(entrances,"tower_exit",Vector2(1280,3750),"river_bay","tower_return")
	var safe: WorldAuthorNode=WorldAuthorNode.new();safe.name="EntrySafety";safe.stable_id="tower_safe";safe.kind=WorldAuthorNode.Kind.SAFE_AREA
	safe.domain=PolygonDomain.rectangle(Rect2(1056,3520,448,224));ground.add_child(safe)
	var regions: Node2D=node(root,"MonsterRegions")
	for tier: int in 4:
		for element: int in 4:
			var rect: Rect2=Rect2(160+element*576,2880-tier*896,480,480)
			region(regions,"tier_"+str(tier)+"_"+str(element),["下層珠衛","中層混色","上層精銳","王座試煉"][tier]+" · "+["火","水","草","電"][element],rect,mini(tier,2),element,tier==3)
	var decor: Node2D=node(root,"Scenery")
	for tier: int in 4:
		var mark: WorldAuthorNode=arrival(decor,"tier_sign_"+str(tier),Vector2(1280,3450-tier*896));mark.kind=WorldAuthorNode.Kind.LANDMARK
		mark.display_name=["一階 Lv30–39 · 2–3珠","二階 Lv50–59 · 4–6珠","三階 Lv70–79 · 6–9珠","四王 Lv90 · 4.5秒攻擊"][tier]
		mark.sprite_definition=load("res://features/world/data/scenery/shaolin_pavilion.tres")
	var battle: BattlefieldMap=load("res://features/battle/maps/shaolin_temple.tscn").instantiate()
	battle.name="ShenchaoTowerBattle";battle.arena_id="shenchao_tower"
	pack(battle,"res://features/battle/maps/shenchao_tower.tscn");battle.free()
	var encounter: EncounterDefinition=EncounterDefinition.new();encounter.id=&"shenchao_tower";encounter.display_name="神抄之塔";encounter.battlefield_scene="res://features/battle/maps/shenchao_tower.tscn"
	var arena: ArenaDefinition=ArenaDefinition.new();arena.arena_id="shenchao_tower";arena.encounter=encounter
	save(arena,"res://features/world/data/shenchao_tower_arena.tres")
	pack(root,"res://features/world/data/shenchao_tower.tscn");root.free();source.free()
	var river: WorldMap2D=load("res://features/world/data/river_bay.tscn").instantiate()
	var before: WorldMapDefinition=river.compile_definition()
	var nav: WorldNavigationService=WorldNavigationService.new();nav.register_map(before)
	var desired: Vector2=Vector2(4100,2400)
	var approach: Dictionary=nav.find_portal_approach("river_bay",before.entries.start.point,desired,80,16)
	assert(approach.ok,"Tower entrance unreachable")
	var point: Vector2=approach.points[-1]
	portal(river.get_node("Entrances"),"tower_door",point,"shenchao_tower","entrance")
	arrival(river.get_node("Entrances"),"tower_return",point+Vector2(128,0))
	pack(river,"res://features/world/data/river_bay.tscn");river.free()
	print("TOWER_AUTHORED 28 parties / 16 regions / 4 kings")
	quit()
