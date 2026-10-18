extends SceneTree
func _initialize() -> void:
	WorldCatalog.initialize()
	for pair: Array in [["river_bay","forest"],["well_1","cave_hunt"]]:
		var old_root: WorldMap2D=load("res://artifacts/demo-web-2026-10-11/"+pair[0]+"-before.tscn").instantiate()
		var old: WorldHabitat=old_root.compile_definition().habitat(pair[1])
		var current: WorldHabitat=WorldCatalog.definitions[pair[0]].habitat(pair[1])
		var bounds: Rect2=current.chase_domain.bounds()
		for y: int in range(int(bounds.position.y),int(bounds.end.y),16):
			for x: int in range(int(bounds.position.x),int(bounds.end.x),16):
				var at: Vector2=Vector2(x+8,y+8)
				assert(not current.chase_domain.contains(at) or old.chase_domain.contains(at),"Chase expanded at "+str(at))
				assert(not current.activity_domain.contains(at) or (old.activity_domain.contains(at) and old.chase_domain.contains(at)),"Activity expanded")
				assert(not current.spawn_domain.contains(at) or old.spawn_domain.contains(at),"Spawn expanded")
		print("DOMAIN_NO_EXPANSION ",pair[0]); old_root.free()
	quit()
