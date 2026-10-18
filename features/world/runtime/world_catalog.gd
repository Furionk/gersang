@tool
class_name WorldCatalog
extends RefCounted
static var definitions: Dictionary = {}
static var arenas: Dictionary = {}

static func initialize() -> void:
	if not definitions.is_empty():
		return
	for encounter: EncounterDefinition in Catalog.encounters():
		var arena: ArenaDefinition = ArenaDefinition.new()
		arena.arena_id = String(encounter.id)
		arena.encounter = encounter
		arenas[arena.arena_id] = arena
	# Stable arena IDs do not depend on translated titles.
	arenas["meadow"] = arenas.values()[0]
	arenas["mountain"] = arenas.values()[1]
	arenas["cave"] = arenas.values()[2]
	var exterior: WorldMapDefinition = _map("river_bay","青嶺河灣",Vector2(6144,4096),0)
	exterior.entries = {"start":{"point":Vector2(5000,2200),"facing":Vector2.DOWN},"town_gate":{"point":Vector2(4800,2300),"facing":Vector2.DOWN},"well_exit":{"point":Vector2(2800,3120),"facing":Vector2.DOWN}}
	exterior.safe_areas = [PolygonDomain.rectangle(Rect2(4300,1050,1500,1100))]
	for rect: Rect2 in [Rect2(0,1950,1080,150),Rect2(1400,2050,1200,150),Rect2(2650,2100,300,140),Rect2(600,2600,350,400),Rect2(1500,2850,280,520),Rect2(900,200,400,400)]:
		exterior.blockers.append(PolygonDomain.rectangle(rect))
	exterior.roads = [PackedVector2Array([Vector2(4800,2200),Vector2(4200,2300),Vector2(3200,2600),Vector2(2800,3200)]),PackedVector2Array([Vector2(4800,2200),Vector2(3800,1600),Vector2(2600,1450),Vector2(1250,1500),Vector2(1250,2350),Vector2(1200,3150)])]
	exterior.landmarks = [{"name":"青嶺鎮","point":Vector2(5000,1600),"kind":"town"},{"name":"河灣橋","point":Vector2(1250,2050),"kind":"bridge"},{"name":"石槌山口","point":Vector2(1200,3150),"kind":"mountain"},{"name":"古井入口","point":Vector2(2800,3200),"kind":"well"},{"name":"沿河農田","point":Vector2(3600,3000),"kind":"farm"}]
	exterior.habitats = [_habitat("river","河岸獸群",Rect2(200,700,1300,950),6,false,0,"meadow"),_habitat("farm","農田妖獸",Rect2(3100,2650,1200,850),6,false,0,"meadow"),_habitat("forest","林道巡獵隊",Rect2(2400,650,1400,1100),6,true,1,"meadow"),_habitat("mountain","石槌山守衛",Rect2(1000,2850,1300,950),4,true,2,"mountain")]
	exterior.portals = [_portal("town_door",Vector2(4800,1900),"qingling_town","gate"),_portal("well_door",Vector2(2800,3260),"well_1","entrance")]
	definitions[exterior.map_id] = exterior
	var town: WorldMapDefinition = _map("qingling_town","青嶺鎮 · 城內",Vector2(1536,1024),0)
	town.kind = WorldMapDefinition.Kind.TOWN
	town.safe_areas = [PolygonDomain.rectangle(Rect2(Vector2.ZERO,town.extent))]
	town.entries = {"gate":{"point":Vector2(768,800),"facing":Vector2.UP},"clinic":{"point":Vector2(500,400),"facing":Vector2.DOWN}}
	town.portals = [_portal("town_exit",Vector2(768,940),"river_bay","town_gate")]
	town.landmarks = [{"name":"醫館 / 安全復活點","point":Vector2(500,350),"kind":"town"},{"name":"青嶺城門","point":Vector2(768,900),"kind":"gate"}]
	definitions[town.map_id] = town
	for floor_number: int in [1,2]:
		var cave: WorldMapDefinition = _map("well_%d" % floor_number,"古井地城 · %d 層" % floor_number,Vector2(2048,1536),2)
		cave.kind = WorldMapDefinition.Kind.DUNGEON
		cave.entries = {"entrance":{"point":Vector2(320,320),"facing":Vector2.DOWN},"stairs":{"point":Vector2(1664,1184),"facing":Vector2.UP}}
		cave.blockers = [PolygonDomain.rectangle(Rect2(800,0,220,700)),PolygonDomain.rectangle(Rect2(800,1000,220,536))]
		cave.habitats = [_habitat("cave_hunt","古井鬼衛",Rect2(1120,250,750,850),4,true,2 if floor_number == 1 else 3,"cave")]
		cave.portals = [_portal("up",Vector2(240,240),"river_bay" if floor_number == 1 else "well_1","well_exit" if floor_number == 1 else "stairs")]
		if floor_number == 1:
			cave.portals.append(_portal("down",Vector2(1800,1300),"well_2","entrance"))
		cave.landmarks = [{"name":"返回上層","point":Vector2(240,240),"kind":"stairs"},{"name":"石階","point":Vector2(1800,1300),"kind":"stairs"}]
		definitions[cave.map_id] = cave
	# Author-created scene edits are compiled at boot; opening a scene never changes IDs.
	var scene_ids: Array[String] = []
	for id: String in definitions.keys(): scene_ids.append(id)
	var files: PackedStringArray=ResourceLoader.list_directory("res://features/world/data"); files.sort()
	if not files.is_empty():
		for file: String in files:
			if file.ends_with("_arena.tres"):
				var authored_arena: ArenaDefinition = load("res://features/world/data/"+file) as ArenaDefinition
				if authored_arena != null: arenas[authored_arena.arena_id] = authored_arena
			if file.ends_with(".tscn") and file.get_basename() not in scene_ids:
				scene_ids.append(file.get_basename())
	for id: String in scene_ids:
		var path: String = "res://features/world/data/%s.tscn" % id
		if ResourceLoader.exists(path):
			var packed: PackedScene = load(path) as PackedScene
			var root: Node = packed.instantiate()
			if root.has_method("compile_definition"):
				var compiled: WorldMapDefinition = root.call("compile_definition")
				definitions[compiled.map_id] = compiled
				compiled.scene_path = path
			root.free()
		elif definitions.has(id):
			definitions[id].scene_path = path

static func _map(id: String, title: String, extent: Vector2, terrain: int) -> WorldMapDefinition:
	var map: WorldMapDefinition = WorldMapDefinition.new()
	map.map_id = id
	map.display_name = title
	map.extent = extent
	map.terrain = terrain
	map.walkable = [PolygonDomain.rectangle(Rect2(Vector2.ZERO,extent))]
	return map

static func _portal(id: String, point: Vector2, target: String, entry: String) -> Dictionary:
	return {"id":id,"point":point,"radius":65.0,"target_map_id":target,"target_entry_id":entry}

static func _habitat(id: String, title: String, rect: Rect2, count: int, active: bool, enemy_kind: int, arena: String) -> WorldHabitat:
	var habitat: WorldHabitat = WorldHabitat.new()
	habitat.habitat_id = id
	habitat.display_name = title
	habitat.spawn_domain = PolygonDomain.rectangle(rect.grow(-64))
	habitat.activity_domain = PolygonDomain.rectangle(rect)
	habitat.chase_domain = PolygonDomain.rectangle(rect.grow(280))
	var profile: SpawnProfile = SpawnProfile.new()
	profile.target_party_count = count
	profile.rules.active = active
	profile.arena_pool = PackedStringArray([arena])
	var template: PartyTemplate = PartyTemplate.new()
	template.template_id = id + "_party"
	template.display_name = title
	template.representative = Catalog.enemy(enemy_kind)
	var rule: MemberRule = MemberRule.new()
	rule.definition = Catalog.enemy(enemy_kind)
	rule.min_count = 3 if enemy_kind < 2 else 2
	rule.max_count = 5 if enemy_kind < 2 else 3
	rule.min_level = 5 if enemy_kind < 2 else 15
	rule.max_level = 12 if enemy_kind < 2 else 25
	template.members = [rule]
	profile.templates = [template]
	habitat.profile = profile
	return habitat
