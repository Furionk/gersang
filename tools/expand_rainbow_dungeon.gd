extends SceneTree
## Explicit one-shot expansion. Saved native scenes are the runtime authority.
const WORLD: String = "res://features/world/data/rainbow_temple.tscn"
const IDS: Array[String] = ["rainbow_slime","lava_beast","lava_priest","fire_dragon"]
const ART: Array[String] = ["lava_slime","lava_beast","lava_priest","fire_dragon"]
const TITLES: Array[String] = ["熔岩史萊姆","熔岩獸","熔岩祭司","焚天火龍"]
func _initialize() -> void: call_deferred("run")
func save(data: Resource, path: String) -> void:
	assert(ResourceSaver.save(data,path) == OK); data.take_over_path(path)
func own(root: Node, node: Node) -> void:
	for child: Node in node.get_children(): child.owner = root; own(root,child)
func pack(root: Node, path: String) -> void:
	own(root,root)
	var packed := PackedScene.new(); assert(packed.pack(root) == OK); save(packed,path)
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_dungeon_v2"): push_error("Already expanded; edit native content explicitly."); world.free(); quit(1); return
	var settings: RainbowActionProfile = load("res://features/rainbow/data/default_action.tres")
	var monsters: Array[UnitDefinition] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://features/rainbow/data/enemies"))
	for i: int in 4:
		var data: UnitDefinition = load("res://features/units/data/monsters/rainbow_slime.tres").duplicate() if i == 0 else UnitDefinition.new()
		data.id = StringName(IDS[i]); data.display_name = TITLES[i]
		data.strength = 20; data.agility = 20; data.intelligence = 20; data.luck = 0
		data.level = [3,18,28,35][i]; data.max_health = [420,1450,5200,12500][i]
		data.damage = [14,42,38,58][i]; data.defense = [0,4,6,10][i]
		data.max_mana = 300; data.mana_regeneration = 8
		data.speed = [95,115,95,90][i]; data.attack_range = [70,130,360,160][i]
		data.experience_reward = [60,180,1600,4000][i]; data.balance_revision = 1
		data.base_power = [100,500,3000,8000][i]
		data.sprite_path = "res://features/rainbow/art/%s-v1.png" % ART[i]
		data.sprite_layout = load("res://features/rainbow/data/skins/%s.tres" % ART[i])
		data.sprite_tint = Color.WHITE
		data.battle_sprite_scale = [0.30,0.48,0.42,0.90][i]
		data.world_sprite_scale = [0.18,0.24,0.23,0.44][i]
		data.tactical_hint = ["熔泡鎖定腳下後才爆發；離開紅圈，近攻可打斷普攻。","裂地猛踏有扇形預警；往側後走，別站在角前。","次王。烙印鎖定位置、焚魂外環中央安全；兩次施法後耗竭四秒。","終王。65%及35%轉階段；吐息→熔星→龍心爆燃。爆燃中央安全，隨後破鱗五秒，承傷1.8倍；平時抗硬直。"][i]
		save(data,"res://features/units/data/monsters/%s.tres" % IDS[i]); monsters.append(data)
		var weapon := RainbowWeaponDefinition.new()
		weapon.unit_id = data.id; weapon.layout = data.sprite_layout; weapon.sprite_scale = data.battle_sprite_scale
		weapon.tint = [Color("ff973e"),Color("ffbd60"),Color("cb91ff"),Color("ff5829")][i]
		weapon.melee_range = [85,145,100,175][i]; weapon.melee_half_angle = [0.9,0.75,1.1,0.9][i]
		weapon.melee_windup = [0.5,0.85,0.6,0.9][i]; weapon.melee_recovery = [0.55,0.8,0.7,0.85][i]
		weapon.melee_power = [1.0,1.15,0.65,1.2][i]
		weapon.ranged_windup = 0.8; weapon.ranged_recovery = 1.1; weapon.ranged_power = 0.8
		weapon.projectile_speed = 340; weapon.projectile_lifetime = 1.8; weapon.mana_cost = 0
		weapon.projectile_count = 3 if i == 2 else 1; weapon.spread = 0.19
		weapon.knockback = [90,190,65,200][i]
		weapon.effect = "heavy" if i in [1,3] else "seal" if i == 2 else "curse"
		var projectile := AtlasTexture.new(); projectile.atlas = load("res://features/rainbow/art/effects-v1.png")
		projectile.region = Rect2(314,800,314,360) if i != 2 else Rect2(940,450,314,350)
		weapon.effect_texture = projectile
		var enemy := RainbowEnemyDefinition.new(); enemy.unit_id = data.id; enemy.weapon = weapon
		enemy.pattern = ["slime","beast","priest","dragon"][i]; enemy.boss = i >= 2
		enemy.special_interval = [7.5,6.5,5.5,5.0][i]
		enemy.warning_seconds = [1.4,1.3,1.6,1.6][i]
		enemy.special_power = [24,65,85,110][i]
		enemy.armored_damage_scale = [1.0,1.0,0.8,0.65][i]
		enemy.exposed_damage_scale = 1.8 if i == 3 else 1.6
		enemy.exposure_seconds = 5 if i == 3 else 4
		save(enemy,"res://features/rainbow/data/enemies/%s.tres" % IDS[i])
		settings.enemies.append(enemy)
	save(settings,"res://features/rainbow/data/default_action.tres")
	world.get_node("MonsterRegions/SlimeCourt").monster = monsters[0]
	world.get_node("MonsterRegions/SlimeCourt").display_name = "熔岩前庭 · 熔岩史萊姆"
	world.definition = world.definition.duplicate(true)
	world.definition.extent = Vector2(5120,1408)
	world.definition.display_name = "彩虹冒險 · 火龍神殿"
	# Preserve the original court, entrances, habitats and existing monster IDs.
	var ground: WorldTileLayer = world.get_node("Ground/Ground_TileMap")
	var mask: WorldTileLayer = world.get_node("Ground/Walkable_Mask")
	var walls: WorldTileLayer = world.get_node("Ground/Obstacles_TileMap")
	for x: int in 160:
		for y: int in 44:
			if x < 34 and y < 32: continue
			var p := Vector2i(x,y)
			var room: bool = Rect2i(40,4,32,28).has_point(p) or Rect2i(80,6,28,30).has_point(p) or Rect2i(116,3,40,37).has_point(p)
			var bridge: bool = y >= 16 and y < 22 and x >= 34 and x < 156
			var blocked: bool = not (room or bridge)
			ground.set_cell(p,0,Vector2i(posmod(x,8)+(8 if blocked else 0),1+posmod(y,8)))
			if blocked: walls.set_cell(p,0,Vector2i(2,0)); mask.erase_cell(p)
			else: mask.set_cell(p,0,Vector2i(0,0)); walls.erase_cell(p)
	var regions: Node = world.get_node("MonsterRegions")
	region(regions,"CinderPits","餘燼池 · 熔岩史萊姆",monsters[0],Rect2(1360,200,700,240),2,4,8,"rainbow_temple")
	region(regions,"BeastNest","熔岩獸巢",monsters[1],Rect2(1400,740,700,220),3,2,18,"rainbow_forge")
	region(regions,"AltarGuard","祭壇護衛",monsters[1],Rect2(2640,800,700,240),1,3,24,"rainbow_forge")
	region(regions,"HighPriest","熔岩祭司 · 次王",monsters[2],Rect2(2750,300,400,250),1,1,28,"rainbow_sanctum")
	region(regions,"DragonThrone","焚天火龍 · 終王",monsters[3],Rect2(4070,350,600,450),1,1,35,"rainbow_throne")
	for info: Array in [["court_sign","熔岩前庭 · Lv3",Vector2(600,700)],["nest_sign","獸巢 · Lv18",Vector2(1650,620)],["priest_sign","祭火聖所 · Lv28 次王",Vector2(2930,680)],["dragon_sign","火龍王座 · Lv35 終王",Vector2(4170,1000)]]:
		var marker := WorldAuthorNode.new(); marker.name = info[0]; marker.stable_id = info[0]; marker.display_name = info[1]
		marker.kind = WorldAuthorNode.Kind.LANDMARK; marker.coordinate_space = WorldAuthorNode.CoordinateSpace.CANVAS
		marker.position = Iso.project(info[2]); marker.landmark_kind = "gate"; world.add_child(marker)
	var scenery: Node = world.get_node("Scenery")
	for p: Vector2 in [Vector2(1312,192),Vector2(2240,192),Vector2(2624,256),Vector2(3392,256),Vector2(3744,224),Vector2(4928,224),Vector2(3744,1152),Vector2(4928,1152)]:
		var pillar := Sprite2D.new(); pillar.name = "DungeonPillar%d" % scenery.get_child_count()
		pillar.texture = load("res://features/rainbow/art/pillar-v1.png"); pillar.scale = Vector2.ONE * 0.13
		pillar.offset = Vector2(0,-660); pillar.position = Iso.project(p)
		pillar.set_meta("world_scenery_id",str(pillar.name)); pillar.set_meta("world_scenery_name","火龍神殿石柱"); pillar.set_meta("scenery_sort_override",1)
		scenery.add_child(pillar)
	world.set_meta("rainbow_dungeon_v2",true)
	pack(world,WORLD); world.free()
	for i: int in 3: make_arena(["rainbow_forge","rainbow_sanctum","rainbow_throne"][i],i)
	print("RAINBOW_DUNGEON_AUTHORED four monsters / 10 parties / 4 arenas / 4 linked halls")
	quit()

func region(parent: Node, id: String, title: String, monster: UnitDefinition, rect: Rect2, count: int, members: int, level: int, arena: String) -> void:
	var area := WorldMonsterRegion.new(); area.name = id; area.stable_id = "rainbow_"+id.to_snake_case(); area.display_name = title
	area.monster = monster; area.minimum_units = members; area.maximum_units = members
	area.minimum_level = level; area.maximum_level = level; area.party_count = count
	area.respawn_min_seconds = 180 if members == 1 else 60; area.respawn_max_seconds = 240 if members == 1 else 90
	area.battlefields = PackedStringArray([arena]); area.habitat = WorldHabitat.new(); area.habitat.profile = SpawnProfile.new()
	area.habitat.profile.rules.max_enemy_parties = 1; area.habitat.profile.rules.reinforcement_chance = 0
	parent.add_child(area)
	for title_node: String in ["SpawnArea","RoamingArea","PursuitArea"]:
		var poly := WorldRegionPolygon.new(); poly.name = title_node
		var points := PackedVector2Array()
		for p: Vector2 in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]: points.append(Iso.project(p))
		poly.polygon = points
		area.add_child(poly)

func make_arena(id: String, kind: int) -> void:
	var source: BattlefieldMap = load("res://features/battle/maps/rainbow_temple.tscn").instantiate()
	source.name = id.to_pascal_case(); source.arena_id = id
	source.battlefield_cells = Vector2i(40,36)
	for path: String in ["Ground","Walkable","Blockers"]:
		var layer: BattleTileLayer = source.get_node(path); layer.clear()
		for x: int in 40:
			for y: int in 36:
				var blocked: bool = x < 2 or x > 37 or y < 2 or y > 33
				# Broad boss fighting area: no hidden obstacle beneath a painted dragon wing.
				if kind == 0: blocked = blocked or (x in [10,29] and y in [14,15])
				if path == "Ground": layer.set_cell(Vector2i(x,y),0,Vector2i(posmod(x,8)+(8 if blocked else 0),1+posmod(y,8)))
				elif (path == "Walkable" and not blocked) or (path == "Blockers" and blocked): layer.set_cell(Vector2i(x,y),0,Vector2i(2 if blocked else 0,0))
	var old_scenery: Node = source.get_node_or_null("Scenery")
	if old_scenery != null: source.remove_child(old_scenery); old_scenery.free()
	var centers: Array[Vector2] = [Vector2(800,1090),Vector2(800,420),Vector2(340,420),Vector2(1260,420),Vector2(1260,1090)]
	for i: int in 5: source.get_node("SpawnZones/Zone%d" % i).position = Iso.project(centers[i])
	source.set_meta("rainbow_dungeon_v2",true)
	pack(source,"res://features/battle/maps/%s.tscn" % id); source.free()
	var encounter := EncounterDefinition.new(); encounter.id = StringName(id)
	encounter.display_name = ["熔岩獸巢","祭火聖所","火龍王座"][kind]
	encounter.battlefield_scene = "res://features/battle/maps/%s.tscn" % id
	encounter.action_profile = load("res://features/rainbow/data/default_action.tres")
	var arena := ArenaDefinition.new(); arena.arena_id = id; arena.encounter = encounter
	save(arena,"res://features/world/data/%s_arena.tres" % id)
