extends Node
var failures: int = 0
func _ready() -> void: call_deferred("run")
func run() -> void:
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	for id: String in ["river_bay","qingling_town","well_1","well_2"]:
		var map: WorldMapDefinition = WorldCatalog.definitions[id]
		game.world_context.state["player"]["map_id"] = id
		game.world_context.state["player"]["position"] = map.entries.values()[0]["point"]
		game.world_context.state["mode"] = "WORLD"
		game.start_world()
		while game.mode!=&"world": await get_tree().process_frame
		for i: int in 4: await get_tree().process_frame
		var count: int = 0
		for child: Node in game.render_root.get_children():
			if child is TileMapLayer:
				count+=1
				if child.tile_set.tile_size!=Vector2i(64,32) or child.collision_enabled or child.navigation_enabled: failures+=1
		if count!=2: failures+=1
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://artifacts/world/native-map-%s.png" % id)
		print("PASS | rendered native map ",id," layers=",count)
	print("NATIVE_RENDER_RESULT failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
