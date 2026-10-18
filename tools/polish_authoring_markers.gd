extends SceneTree
## One-shot metadata-only polish; never a boot hook.
func _initialize() -> void:
	for file: String in DirAccess.get_files_at("res://features/world/data"):
		if not file.ends_with(".tscn"): continue
		var path: String = "res://features/world/data/"+file
		var map: WorldMap2D = load(path).instantiate() as WorldMap2D
		if map==null: continue
		for node: Node in WorldAuthorTree.nodes(map):
			if node is Sprite2D and node.name==&"Artwork" and node.has_meta("_edit_lock_"): node.remove_meta("_edit_lock_")
		var scene: PackedScene = PackedScene.new()
		assert(scene.pack(map)==OK and ResourceSaver.save(scene,path)==OK)
		map.free()
		print("MARKER_POLISH | ",file)
	quit()
