extends SceneTree
func _initialize() -> void:
	var maps: Dictionary = {}
	for id: String in ["river_bay","shaolin_temple"]:
		var path: String = "res://features/world/data/"+id+".tscn"
		var authored: WorldMap2D = load(path).instantiate() as WorldMap2D
		if id=="shaolin_temple":
			for region: WorldMonsterRegion in authored.get_node("MonsterRegions").get_children():
				region.habitat = region.habitat.duplicate(true) as WorldHabitat
				region.habitat.profile.templates[0].display_name = region.display_name
				if region.stable_id!="bronze_guardian": region.habitat.profile.templates[0].template_id = region.stable_id+"_party"
			var packed: PackedScene = PackedScene.new()
			assert(packed.pack(authored)==OK and ResourceSaver.save(packed,path)==OK)
		var compiled: WorldMapDefinition = authored.compile_definition()
		var habitats: Dictionary = {}
		for habitat: WorldHabitat in compiled.habitats:
			var record: Dictionary = {}
			for field: String in ["spawn_domain","activity_domain","chase_domain"]:
				var domain: PolygonDomain = habitat.get(field)
				var holes: Array = []
				for contour: PackedVector2Array in domain.holes: holes.append(pairs(contour))
				record[field] = {"outer":pairs(domain.outer),"holes":holes}
			var profile: SpawnProfile = habitat.profile
			var members: Array = []
			for rule: MemberRule in profile.templates[0].members:
				members.append({"unit":String(rule.definition.id),"minimum":rule.min_count,"maximum":rule.max_count,"min_level":rule.min_level,"max_level":rule.max_level})
			record["profile"] = {"count":profile.target_party_count,"active":profile.rules.active,"arenas":Array(profile.arena_pool),"members":members,"display_name":profile.templates[0].display_name,"template_id":profile.templates[0].template_id}
			habitats[habitat.habitat_id] = record
		maps[id] = habitats
		authored.free()
	var file: FileAccess = FileAccess.open("res://tests/world/approved_monster_layouts.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"decision":"D23","scope":"explicit current-picture monster ranges and temple12 parties; not player geometry","maps":maps},"\t"))
	file.close()
	print("MONSTER_LAYOUT_FIXTURE recorded explicit authorized shapes/profiles")
	quit()
func pairs(points: PackedVector2Array) -> Array:
	var result: Array = []
	for point: Vector2 in points: result.append([point.x,point.y])
	return result
