extends SceneTree
## One-shot visual repair; does not rebuild terrain, routes, monsters or saves.
const ART: String = "res://art/terrain/shaolin_temple/walls-v2.png"
const DATA: String = "res://features/world/data/scenery/shaolin_walls_v2/"
const MAP: String = "res://features/world/data/shaolin_temple.tscn"
const EVIDENCE: String = "res://artifacts/shaolin-wall-repair-2026-10-10/"
const SCALE: float = 0.42
const OVERLAP: float = 10.0
var map: WorldMap2D
var texture: Texture2D
var cached: Dictionary = {}
var joins: Array[Dictionary] = []
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)

func definition(id: String, region: Rect2, anchor: Vector2, matrix: Transform2D, ports: PackedVector2Array, targets: PackedVector2Array) -> WorldSceneryDefinition:
	var data: WorldSceneryDefinition = WorldSceneryDefinition.new()
	data.display_name = "少林寺連續朱牆"
	data.texture = texture
	data.atlas_region = region
	data.foot_anchor = anchor
	data.sprite_scale = SCALE
	data.sprite_basis = Transform2D(matrix.x / SCALE, matrix.y / SCALE, Vector2.ZERO)
	data.set_meta("source_ports", ports)
	data.set_meta("projected_ports", targets)
	data.set_meta("wall_kit", 2)
	for index: int in ports.size():
		check((data.artwork_transform() * ports[index]).distance_to(targets[index]) < 0.001, id + " calibrated connection " + str(index))
	check(absf(matrix.determinant()) > 0.001, id + " nonsingular art transform")
	var path: String = DATA + id + ".tres"
	check(ResourceSaver.save(data, path) == OK, "save " + path)
	data.take_over_path(path)
	return data

func straight(axis: Vector2, length: float) -> WorldSceneryDefinition:
	var id: String = ("x_" if axis.x != 0 else "y_") + str(roundi(length * 100))
	if cached.has(id):
		return cached[id]
	var a: Vector2 = Vector2(50, 239) if axis.x != 0 else Vector2(457, 238)
	var b: Vector2 = Vector2(449, 439) if axis.x != 0 else Vector2(40, 442)
	var anchor: Vector2 = (a + b) * 0.5
	var delta: Vector2 = b - a
	var target: Vector2 = Iso.project(axis * (length + OVERLAP))
	var horizontal: float = target.x / delta.x
	var shear: float = (target.y - SCALE * delta.y) / delta.x
	var matrix: Transform2D = Transform2D(Vector2(horizontal, shear), Vector2(0, SCALE), Vector2.ZERO)
	var region: Rect2 = Rect2(0 if axis.x != 0 else 512, 0, 512, 512)
	var data: WorldSceneryDefinition = definition(id, region, anchor, matrix, PackedVector2Array([a, b]), PackedVector2Array([-target * 0.5, target * 0.5]))
	cached[id] = data
	return data

func existing(id: String) -> WorldAuthorNode:
	var value: WorldAuthorNode = map.get_node_or_null("Scenery/" + id) as WorldAuthorNode
	check(value != null, "preserve existing wall id " + id)
	return value

func assign(node: WorldAuthorNode, at: Vector2, data: WorldSceneryDefinition) -> void:
	if node == null:
		return
	node.position = Iso.project(at)
	node.coordinate_space = WorldAuthorNode.CoordinateSpace.CANVAS
	node.sprite_definition = data
	node.sync_artwork()

func run_of(ids: Array[String], a: Vector2, b: Vector2) -> void:
	var axis: Vector2 = (b - a).normalized()
	var length: float = a.distance_to(b) / ids.size()
	var data: WorldSceneryDefinition = straight(axis, length)
	for index: int in ids.size():
		var center: Vector2 = a + axis * length * (index + 0.5)
		assign(existing(ids[index]), center, data)
		joins.append({"id": ids[index], "center": center, "length": length, "axis": axis, "start": a + axis * length * index, "end": a + axis * length * (index + 1)})

func corner_span(vertex: Vector2, end_a: Vector2, end_b: Vector2, axis_a: Vector2, axis_b: Vector2, height_scale: float) -> float:
	var source: Transform2D = Transform2D(end_a - vertex, end_b - vertex, Vector2.ZERO)
	var target: Transform2D = Transform2D(Iso.project(axis_a * 80), Iso.project(axis_b * 80), Vector2.ZERO)
	var matrix: Transform2D = target * source.affine_inverse()
	return 80 * height_scale / matrix.y.y

func corner(id: String, cell: Vector2i, point: Vector2, vertex: Vector2, end_a: Vector2, end_b: Vector2, axis_a: Vector2, axis_b: Vector2, span: float, order: int) -> void:
	var source: Transform2D = Transform2D(end_a - vertex, end_b - vertex, Vector2.ZERO)
	var target: Transform2D = Transform2D(Iso.project(axis_a * span), Iso.project(axis_b * span), Vector2.ZERO)
	var data: WorldSceneryDefinition = definition(id, Rect2(Vector2(cell) * 512, Vector2.ONE * 512), vertex, target * source.affine_inverse(), PackedVector2Array([vertex, end_a, end_b]), PackedVector2Array([Vector2.ZERO, target.x, target.y]))
	data.display_name = "少林寺完整轉角"
	check(ResourceSaver.save(data, data.resource_path) == OK, "save corner title")
	var node: WorldAuthorNode = map.get_node_or_null("Scenery/" + id) as WorldAuthorNode
	if node == null:
		node = WorldAuthorNode.new()
		node.name = id
		node.stable_id = id
		node.kind = WorldAuthorNode.Kind.SCENERY
		node.display_name = data.display_name
		node.set_meta("authoring_order", order)
		node.set_meta("_edit_group_", true)
		map.get_node("Scenery").add_child(node)
		node.owner = map
		var artwork: Sprite2D = Sprite2D.new()
		artwork.name = "Artwork"
		node.add_child(artwork)
		artwork.owner = map
	assign(node, point, data)
	joins.append({"id": id, "center": point, "corner": true, "ports": [point + axis_a * span, point + axis_b * span]})

func geometry_snapshot(root_map: WorldMap2D) -> Dictionary:
	var snapshot: Dictionary = {}
	for child: Node in WorldAuthorTree.nodes(root_map, true):
		if child is TileMapLayer:
			snapshot[str(root_map.get_path_to(child))] = (child as TileMapLayer).tile_map_data.hex_encode()
		if child is WorldMonsterRegion or child is WorldRegionPolygon:
			snapshot[str(root_map.get_path_to(child)) + ":position"] = (child as Node2D).position
			if child is WorldRegionPolygon:
				snapshot[str(root_map.get_path_to(child)) + ":shape"] = (child as WorldRegionPolygon).polygon
	return snapshot

func run() -> void:
	map = load(MAP).instantiate() as WorldMap2D
	var current_hash: String = FileAccess.get_sha256(MAP)
	var native_before: Dictionary = geometry_snapshot(map)
	var before: WorldMapDefinition = map.compile_definition()
	var ids_before: Array[String] = []
	for child: Node in WorldAuthorTree.nodes(map):
		if child is WorldAuthorNode:
			ids_before.append(child.stable_id)
	texture = load(ART) as Texture2D
	check(texture != null and texture.get_size() == Vector2(1536, 1024), "six complete transparent wall modules imported")
	if texture == null:
		map.free()
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA))
	var north: Array[String] = []
	var west: Array[String] = []
	var east: Array[String] = []
	for x: int in range(288, 1792, 160):
		north.append("outer_north_%d" % x)
	for y: int in range(288, 1281, 160):
		west.append("outer_west_%d" % y)
		east.append("outer_east_%d" % y)
	var north_span: float = corner_span(Vector2(256,258),Vector2(444,351),Vector2(70,351),Vector2.RIGHT,Vector2.DOWN,0.42)
	var south_span: float = corner_span(Vector2(254,419),Vector2(44,309),Vector2(471,309),Vector2.LEFT,Vector2.UP,0.38)
	var west_span: float = corner_span(Vector2(140,337),Vector2(376,457),Vector2(428,195),Vector2.RIGHT,Vector2.UP,0.44)
	var east_span: float = corner_span(Vector2(370,325),Vector2(83,185),Vector2(136,451),Vector2.LEFT,Vector2.DOWN,0.44)
	run_of(north, Vector2(224+north_span, 224), Vector2(1824-east_span, 224))
	run_of(west, Vector2(224, 224+north_span), Vector2(224, 1312-west_span))
	run_of(east, Vector2(1824, 224+east_span), Vector2(1824, 1312-south_span))
	run_of(["outer_south_288", "outer_south_448", "outer_south_608", "outer_south_768", "gate_left_wall"], Vector2(224+west_span, 1312), Vector2(928, 1312))
	run_of(["gate_right_wall", "outer_south_1248", "outer_south_1408", "outer_south_1568", "outer_south_1728"], Vector2(1120, 1312), Vector2(1824-south_span, 1312))
	run_of(["inner_wall_336", "inner_wall_496", "inner_wall_656"], Vector2(256, 800), Vector2(736, 800))
	run_of(["inner_wall_1008", "inner_wall_1120"], Vector2(928, 800), Vector2(1208, 800))
	run_of(["side_wall_336", "side_wall_496", "side_wall_656"], Vector2(1216, 256), Vector2(1216, 832))
	run_of(["side_wall_1136", "side_wall_1232"], Vector2(1216, 1024), Vector2(1216, 1280))
	corner("wall_corner_north", Vector2i(0, 1), Vector2(224, 224), Vector2(256,258), Vector2(444,351), Vector2(70,351), Vector2.RIGHT, Vector2.DOWN, north_span,100)
	corner("wall_corner_south", Vector2i(2, 0), Vector2(1824, 1312), Vector2(254,419), Vector2(44,309), Vector2(471,309), Vector2.LEFT, Vector2.UP, south_span,101)
	corner("wall_corner_west", Vector2i(1, 1), Vector2(224, 1312), Vector2(140,337), Vector2(376,457), Vector2(428,195), Vector2.RIGHT, Vector2.UP, west_span,102)
	corner("wall_corner_east", Vector2i(2, 1), Vector2(1824, 224), Vector2(370,325), Vector2(83,185), Vector2(136,451), Vector2.LEFT, Vector2.DOWN, east_span,103)
	var after: WorldMapDefinition = map.compile_definition()
	check(native_before == geometry_snapshot(map), "native floor, masks and monster regions unchanged")
	check(before.portals == after.portals and before.entries == after.entries, "portal routes and arrivals unchanged")
	var ids_after: Array[String] = []
	for child: Node in WorldAuthorTree.nodes(map):
		if child is WorldAuthorNode:
			ids_after.append(child.stable_id)
	for id: String in ids_before:
		check(ids_after.has(id), "original author id survives " + id)
	check(FileAccess.get_sha256(MAP) == current_hash, "source map not concurrently changed before save")
	if errors.is_empty():
		var packed: PackedScene = PackedScene.new()
		check(packed.pack(map) == OK, "pack repaired map")
		check(ResourceSaver.save(packed, MAP) == OK, "save repaired native map")
	var report: FileAccess = FileAccess.open(EVIDENCE + "authoring-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"failed": errors.size(), "errors": errors, "walls": joins, "native_geometry_preserved": native_before == geometry_snapshot(map), "routes_preserved": before.portals == after.portals and before.entries == after.entries}, "\t"))
	map.free()
	print("SHAOLIN_WALL_REPAIR | failures=", errors.size(), " wall_nodes=", joins.size())
	quit(0 if errors.is_empty() else 1)

