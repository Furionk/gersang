extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	for id: String in ["meadow","mountain","cave","shaolin_temple","millennium_lake"]:
		var path: String = "res://features/battle/maps/%s.tscn" % id
		var source: BattlefieldMap = load(path).instantiate()
		var backup: BattlefieldMap = load("res://artifacts/battlefield-alignment-2026-10-11/%s.tscn" % id).instantiate()
		check(backup.get_node("Terrain/Ground").position==Vector2(0,20) and source.get_node("Terrain/Ground").position==Vector2(-40,0),id+" independent pre-fix backup proves calibration change")
		for name: String in ["Ground","Walkable","Blockers"]:
			var layer: BattleTileLayer = source.get_node("Terrain/"+name)
			# Godot may reorder serialized TileMap bytes on editor save. Cell identity
			# is the coordinate + source/atlas/alternative, not serialization order.
			check(tile_cells(layer)==tile_cells(backup.get_node("Terrain/"+name)),id+" all artist cell coordinates and tile identities unchanged "+name)
			var accurate: bool = true
			for cell: Vector2i in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(5,7),Vector2i(43,37)]:
				var native: Vector2 = WorldAuthorTree.canvas_transform(layer,source)*layer.map_to_local(cell)
				var logical: Vector2 = (Vector2(cell)+Vector2.ONE*0.5)*Iso.CELL
				accurate = accurate and native.is_equal_approx(Iso.project(logical))
				for corner: Vector2 in [Vector2(-20,-20),Vector2(20,-20),Vector2(20,20),Vector2(-20,20)]:
					accurate = accurate and (native+Iso.project(corner)).is_equal_approx(Iso.project(logical+corner))
			check(accurate,id+" native centers and corners equal projected geometry "+name)
		var unchanged: bool = true
		for node: Node in WorldAuthorTree.nodes(source):
			if node is Node2D and not node is BattleTileLayer:
				var old: Node2D = backup.get_node_or_null(source.get_path_to(node))
				if old==null:
					unchanged=false # Artist-added content is a reported baseline delta, not a runtime crash.
					continue
				if node is Sprite2D and old.get_child_count()==1 and old.get_child(0) is Sprite2D:
					var art: Sprite2D = old.get_child(0)
					var before: Transform2D = WorldAuthorTree.canvas_transform(art,backup)
					var after: Transform2D = WorldAuthorTree.canvas_transform(node,source)
					unchanged = unchanged and node.position.is_equal_approx(old.position) and before.x.is_equal_approx(after.x) and before.y.is_equal_approx(after.y) and (before*art.offset).distance_to(after*node.offset)<0.001
				else: unchanged = unchanged and node.transform==old.transform
		check(unchanged,id+" scenery pixels/foot and spawn marker transforms untouched")
		backup.free()
		var sim: Node2D = Node2D.new(); var visual: Node2D = Node2D.new(); add_child(sim); add_child(visual)
		var ground: GroundMap = GroundMap.new()
		var built: Dictionary = ground.build_scene(sim,visual,source)
		check(built.ok,id+" actual runtime accepts corrected calibration")
		if not built.ok:
			print("ALIGNMENT_CONFIG_ERRORS ",built.error); source.free(); sim.free(); visual.free(); ground.free(); continue
		await get_tree().physics_frame
		await get_tree().physics_frame
		var blocker: BattleTileLayer = source.get_node("Terrain/Blockers")
		var exact: bool = true
		for cell: Vector2i in blocker.get_used_cells():
			var point: Vector2 = (Vector2(cell)+Vector2.ONE*0.5)*Iso.CELL
			var body: StaticBody2D
			for node: Node in sim.get_children():
				if node is StaticBody2D and node.position.is_equal_approx(point): body=node; break
			if body==null: exact=false; continue
			var shape: RectangleShape2D = body.get_child(0).shape
			var native: Vector2 = WorldAuthorTree.canvas_transform(blocker,source)*blocker.map_to_local(cell)
			exact = exact and native.is_equal_approx(Iso.project(body.position)) and shape.size==Vector2.ONE*40
			var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
			query.position=point; query.collision_mask=1
			exact = exact and not sim.get_world_2d().direct_space_state.intersect_point(query).is_empty()
		check(exact,id+" native blocker tiles match actual physics bodies and queries")
		sim.free(); visual.free()
	print("BATTLEFIELD_ALIGNMENT_RESULT passed=",passed," failed=",failed)
	var report: FileAccess = FileAccess.open("res://artifacts/battlefield-alignment-2026-10-11/results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":passed,"failed":failed},"\t")); report.close()
	get_tree().quit(0 if failed==0 else 1)
func tile_cells(layer: TileMapLayer) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in layer.get_used_cells(): result[cell]=[layer.get_cell_source_id(cell),layer.get_cell_atlas_coords(cell),layer.get_cell_alternative_tile(cell)]
	return result
