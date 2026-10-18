extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path: String = "res://features/battle/maps/shaolin_temple.tscn"
	if not OS.get_cmdline_user_args().is_empty(): path=OS.get_cmdline_user_args()[0]
	var scene: BattlefieldMap = load(path).instantiate()
	var layer: BattleTileLayer = scene.get_node("Terrain/Blockers")
	for cell: Vector2i in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(5,7)]:
		var editor: Vector2 = WorldAuthorTree.canvas_transform(layer,scene)*layer.map_to_local(cell)
		var collision: Vector2 = Iso.project((Vector2(cell)+Vector2.ONE*0.5)*Iso.CELL)
		print("ALIGNMENT | cell=",cell," editor_center=",editor," collision_center=",collision," offset=",editor-collision)
	print("LAYER | layout=",layer.tile_set.tile_layout," offset_axis=",layer.tile_set.tile_offset_axis," transform=",layer.transform)
	var profile: Node = root.get_node("GameSettings")
	print("BODY_RADIUS | ",profile.get("profile").collision_radius)
	var compiled: Dictionary = BattlefieldCompiler.compile(scene)
	print("CONFIG_ERRORS | ",compiled.errors)
	if "--brush-diff" in OS.get_cmdline_user_args():
		var before: Node = load("res://artifacts/battlefield-alignment-2026-10-11/"+path.get_file()).instantiate()
		var old_layer: TileMapLayer = before.get_node("Terrain/Blockers")
		var seen: Dictionary = {}
		for cell: Vector2i in layer.get_used_cells(): seen[cell]=true
		for cell: Vector2i in old_layer.get_used_cells(): seen[cell]=true
		for cell: Vector2i in seen:
			var old_value: Array = [old_layer.get_cell_source_id(cell),old_layer.get_cell_atlas_coords(cell),old_layer.get_cell_alternative_tile(cell)]
			var new_value: Array = [layer.get_cell_source_id(cell),layer.get_cell_atlas_coords(cell),layer.get_cell_alternative_tile(cell)]
			if old_value!=new_value: print("BRUSH_DIFF | cell=",cell," before=",old_value," now=",new_value)
		before.free()
	scene.free()
	quit()
