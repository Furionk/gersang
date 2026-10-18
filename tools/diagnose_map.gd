extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	WorldCatalog.initialize()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else "res://features/world/data/millennium_lake.tscn"
	var map: WorldMap2D = load(path).instantiate()
	var snapshot: Dictionary = WorldAuthoringSnapshot.compile(map,WorldCatalog.definitions)
	print("MAP_DIAGNOSTIC ",path)
	print("SNAPSHOT_OK ",snapshot.get("ok",false))
	for error: String in snapshot.get("errors",[]): print("MAP_ERROR | ",error)
	print("ERROR_COUNT ",snapshot.get("errors",[]).size())
	if "--population" in args:
		var compiled: WorldMapDefinition = snapshot.definition
		var progress: Node = root.get_node("PartyProgress")
		var context: WorldContext = WorldContext.new()
		context.initialize(progress.call("serialize"),11011,true,{compiled.map_id:compiled})
		context.ensure_map(compiled.map_id)
		var runtime: Dictionary = context.state.maps[compiled.map_id]
		for habitat: WorldHabitat in compiled.habitats:
			var cells: Array = context.navigation._cache(compiled.map_id,habitat.habitat_id,"SPAWN",habitat.profile.radius).get("cells",[])
			print("HABITAT | ",habitat.habitat_id," target=",habitat.profile.target_party_count," legal_spawn_cells=",cells.size())
			var bounds: Rect2 = habitat.spawn_domain.bounds()
			var full_inside: int = 0
			var full_walkable: int = 0
			var centers_legal: int = 0
			for y: int in range(floori(bounds.position.y/compiled.grid_size),ceili(bounds.end.y/compiled.grid_size)):
				for x: int in range(floori(bounds.position.x/compiled.grid_size),ceili(bounds.end.x/compiled.grid_size)):
					var rect: Rect2 = Rect2(Vector2(x,y)*compiled.grid_size,Vector2.ONE*compiled.grid_size).grow(habitat.profile.radius)
					var shape: PackedVector2Array = PolygonDomain.rectangle(rect).outer
					if habitat.spawn_domain.covers(shape):
						full_inside+=1
						for domain: PolygonDomain in compiled.walkable:
							if domain.covers(shape): full_walkable+=1; break
					var point: Vector2 = (Vector2(x,y)+Vector2.ONE*0.5)*compiled.grid_size
					if context.navigation.segment_legal(compiled.map_id,habitat.habitat_id,"SPAWN",point,point,habitat.profile.radius): centers_legal+=1
			print("SPAWN_DIAG | bounds=",bounds," radius=",habitat.profile.radius," full_cells_in_region=",full_inside," also_walkable=",full_walkable," legal_radius_centers=",centers_legal)
		for slot: Dictionary in runtime.slots.values(): print("FRESH_SLOT | ",slot.slot_id," state=",slot.state," error=",slot.get("last_error",""))
		if "--saved-readonly" in args:
			var file: FileAccess = FileAccess.open("user://world_state.dat",FileAccess.READ)
			if file!=null:
				var saved: Variant = file.get_var(false)
				file.close()
				if saved is Dictionary:
					var old: Dictionary = saved.get("maps",{}).get(compiled.map_id,{})
					print("SAVED_MAP | present=",not old.is_empty()," slots=",old.get("slots",{}).size()," parties=",old.get("parties",{}).size())
					for habitat: WorldHabitat in compiled.habitats:
						var count: int = 0
						for slot: Dictionary in old.get("slots",{}).values():
							if slot.get("habitat_id","")==habitat.habitat_id: count+=1
						print("SAVED_HABITAT | ",habitat.habitat_id," slots=",count)
			else: print("SAVED_MAP | save file unavailable")
	map.free()
	quit()
