extends SceneTree
func _initialize() -> void: call_deferred("run")
func style(id: String) -> WorldSceneryDefinition: return load("res://features/world/data/scenery/%s.tres" % id) as WorldSceneryDefinition
func run() -> void:
	for id: String in ["tree","mountain","cave_rock","building","town_gate","dungeon_gate","dungeon_stairs"]:
		if style(id)==null: quit(1); return
	var repair: bool = "--repair-portals" in OS.get_cmdline_user_args()
	var report: Dictionary = {}
	for id: String in ["river_bay","qingling_town","well_1","well_2"]:
		var path: String = "res://features/world/data/%s.tscn" % id
		var map: WorldMap2D = load(path).instantiate() as WorldMap2D
		if map.has_meta("authored_sprite_scenery_v1") and not repair: print("SKIP ",id); map.free(); continue
		var compiled: WorldMapDefinition = map.compile_definition()
		var counter: int = 0
		for author: Node in map.get_children():
			if not author is WorldAuthorNode: continue
			if author.kind==WorldAuthorNode.Kind.PORTAL:
				author.sprite_definition = style("town_gate" if author.target_map_id in ["qingling_town","river_bay"] else "dungeon_gate" if id=="river_bay" else "dungeon_stairs")
				author.display_name = {"qingling_town":"青嶺鎮入口","river_bay":"返回青嶺河灣","well_1":"古井地城 · 一層入口","well_2":"古井地城 · 二層入口"}.get(author.target_map_id,"地區入口")
			elif author.kind==WorldAuthorNode.Kind.LANDMARK and author.landmark_kind=="town": author.sprite_definition = style("building")
		for blocker: PolygonDomain in compiled.blockers:
			if repair: continue
			if blocker.visual_kind=="water": continue
			var bounds: Rect2 = blocker.bounds()
			for x: int in range(int(bounds.position.x+40),int(bounds.end.x),112):
				for y: int in range(int(bounds.position.y+40),int(bounds.end.y),112):
					var point: Vector2 = Vector2(x,y)
					if not blocker.contains(point): continue
					var node: WorldAuthorNode = WorldAuthorNode.new()
					node.kind = WorldAuthorNode.Kind.SCENERY
					node.stable_id = "scenery_%s_%04d" % [id,counter]
					node.name = node.stable_id
					node.position = point
					node.sprite_definition = style("tree" if blocker.visual_kind=="forest" else "building" if blocker.visual_kind=="building" else "cave_rock" if compiled.kind==WorldMapDefinition.Kind.DUNGEON else "mountain")
					map.add_child(node)
					node.owner = map
					counter+=1
		map.set_meta("authored_sprite_scenery_v1",true)
		var packed: PackedScene = PackedScene.new()
		if packed.pack(map)!=OK or ResourceSaver.save(packed,path)!=OK: quit(1); return
		report[id] = {"scenery":counter,"portals":compiled.portals.size()}
		print("SCENERY ",id," ",report[id])
		map.free()
	var file: FileAccess = FileAccess.open("res://artifacts/world/scenery-authoring.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	quit()
