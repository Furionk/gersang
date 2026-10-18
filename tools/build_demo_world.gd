extends SceneTree
func _initialize() -> void:
	call_deferred("build")
func build() -> void:
	WorldCatalog.initialize()
	for map: WorldMapDefinition in WorldCatalog.definitions.values():
		var path: String = "res://features/world/data/%s.tscn" % map.map_id
		if FileAccess.file_exists(path):
			print("PRESERVED_EXISTING ",path)
			continue
		var root: WorldMap2D = WorldMap2D.new()
		root.name = map.map_id
		root.definition = map.duplicate(true)
		var index: int = 0
		for kind: int in [WorldAuthorNode.Kind.WALKABLE,WorldAuthorNode.Kind.BLOCKER,WorldAuthorNode.Kind.SAFE_AREA]:
			var domains: Array = map.walkable if kind == WorldAuthorNode.Kind.WALKABLE else map.blockers if kind == WorldAuthorNode.Kind.BLOCKER else map.safe_areas
			for domain: PolygonDomain in domains:
				var node: WorldAuthorNode = _node(root,kind,"domain_%d" % index)
				node.domain = domain.duplicate(true)
				index += 1
		for habitat: WorldHabitat in map.habitats:
			var node: WorldAuthorNode = _node(root,WorldAuthorNode.Kind.HABITAT,habitat.habitat_id)
			node.display_name = habitat.display_name
			node.habitat = habitat.duplicate(true)
		for entry_id: String in map.entries:
			var node: WorldAuthorNode = _node(root,WorldAuthorNode.Kind.ARRIVAL,entry_id)
			node.position = map.entries[entry_id]["point"]
			node.facing = map.entries[entry_id]["facing"]
		for portal: Dictionary in map.portals:
			var node: WorldAuthorNode = _node(root,WorldAuthorNode.Kind.PORTAL,portal["id"])
			node.position = portal["point"]
			node.trigger_radius = portal["radius"]
			node.target_map_id = portal["target_map_id"]
			node.target_entry_id = portal["target_entry_id"]
		for landmark: Dictionary in map.landmarks:
			var node: WorldAuthorNode = _node(root,WorldAuthorNode.Kind.LANDMARK,"landmark_%d" % index)
			node.position = landmark["point"]
			node.display_name = landmark["name"]
			node.landmark_kind = landmark["kind"]
			index += 1
		for road: PackedVector2Array in map.roads:
			var node: WorldAuthorNode = _node(root,WorldAuthorNode.Kind.ROAD,"road_%d" % index)
			node.road = road.duplicate()
			index += 1
		var scene: PackedScene = PackedScene.new()
		var error: Error = scene.pack(root)
		if error == OK: error = ResourceSaver.save(scene,path)
		print("BUILD_MAP ",map.map_id," ",error)
		root.free()
	quit()
func _node(root: WorldMap2D,kind: int,id: String) -> WorldAuthorNode:
	var node: WorldAuthorNode = WorldAuthorNode.new()
	node.kind = kind
	node.name = id
	node.stable_id = id
	root.add_child(node)
	node.owner = root
	return node
