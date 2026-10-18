extends SceneTree
## Explicit one-shot authoring migration, never called at boot.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var paths: Array[String] = []
	for folder: String in ["res://features/world/data","res://features/battle/maps"]:
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".tscn"): paths.append(folder+"/"+file)
	var total: int = 0
	for path: String in paths:
		var hash_before: String = FileAccess.get_sha256(path)
		var scene: Node2D = load(path).instantiate()
		var targets: Array[Node2D] = []
		for node: Node in WorldAuthorTree.nodes(scene):
			var pure: bool = node is WorldAuthorNode and node.kind==WorldAuthorNode.Kind.SCENERY and node.coordinate_space==WorldAuthorNode.CoordinateSpace.CANVAS
			if scene is BattlefieldMap and node is Node2D and node.get_parent()!=null and node.get_parent().name==&"Scenery": pure=true
			if pure and node.get_child_count()==1 and node.get_child(0) is Sprite2D and node.get_child(0).name==&"Artwork" and node.owner==scene and node.get_child(0).get_script()==null: targets.append(node)
		if targets.is_empty(): scene.free(); continue
		var backup: String = "res://artifacts/editor-workflow-2026-10-11/scenery-before/"+("battle-" if scene is BattlefieldMap else "world-")+path.get_file()
		if FileAccess.file_exists(backup):
			if FileAccess.get_sha256(backup)!=hash_before: print("REFUSE_CHANGED_ARTIST_SCENE ",path); scene.free(); quit(1); return
		elif DirAccess.copy_absolute(path,backup)!=OK: scene.free(); quit(1); return
		var before: Dictionary = scene.compile_definition().entries.duplicate(true) if scene is WorldMap2D else {}
		for pivot: Node2D in targets:
			var art: Sprite2D = pivot.get_child(0)
			var combined: Transform2D = pivot.transform*art.transform
			var sprite: Sprite2D = NativeScenery.flatten(pivot,art)
			if scene is WorldMap2D:
				sprite.set_meta("world_scenery_id",pivot.stable_id)
				sprite.set_meta("world_scenery_label",pivot.display_name)
				sprite.set_meta("world_scenery_definition",pivot.sprite_definition)
			var parent: Node = pivot.get_parent()
			var index: int = pivot.get_index()
			parent.remove_child(pivot); parent.add_child(sprite); parent.move_child(sprite,index); sprite.owner=scene
			var old_render_origin: Vector2 = combined*art.offset
			var new_render_origin: Vector2 = sprite.transform*sprite.offset
			# Native Node2D decomposes/recomposes its float32 basis; allow <.001px
			# roundoff, not a visual offset or a change to the foot origin.
			if old_render_origin.distance_to(new_render_origin)>0.001 or not combined.x.is_equal_approx(sprite.transform.x) or not combined.y.is_equal_approx(sprite.transform.y):
				push_error("Flatten changed artwork pose: "+str(pivot.name)); pivot.free(); scene.free(); quit(1); return
			pivot.free()
		if scene is WorldMap2D and before!=scene.compile_definition().entries: scene.free(); quit(1); return
		if FileAccess.get_sha256(path)!=hash_before: push_error("Artist saved scene during migration; kept new save: "+path); scene.free(); quit(1); return
		var packed: PackedScene = PackedScene.new()
		if packed.pack(scene)!=OK or ResourceSaver.save(packed,path)!=OK: scene.free(); quit(1); return
		total+=targets.size()
		print("FLATTENED ",path," count=",targets.size())
		scene.free()
	print("NATIVE_SCENERY_FLATTEN_RESULT count=",total)
	quit()
