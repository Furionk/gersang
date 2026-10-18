extends Node
const MONSTER_LAYOUT = preload("res://tests/world/monster_layout_fixture.gd")
const EVIDENCE: String = "res://artifacts/shaolin-wall-repair-2026-10-10/"
var game: GameDirector
var passed: int = 0
var failures: Array[String] = []
var rendered: bool
var seam_metrics: Array[Dictionary] = []

func _ready() -> void:
	rendered = DisplayServer.get_name() != "headless"
	get_tree().create_timer(120).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")

func check(value: bool, title: String) -> void:
	if value:
		passed += 1
		print("PASS | ", title)
	else:
		failures.append(title)
		push_error("FAIL | " + title)

func native_snapshot(map: WorldMap2D) -> Dictionary:
	var data: Dictionary = {}
	for node: Node in WorldAuthorTree.nodes(map, true):
		if node is TileMapLayer:
			data[str(map.get_path_to(node))] = (node as TileMapLayer).tile_map_data.hex_encode()
	return data

func frame() -> void:
	for i: int in 4:
		await get_tree().process_frame
	if rendered:
		await RenderingServer.frame_post_draw

func shot(name_value: String, point: Vector2, zoom_value: float) -> Image:
	game.camera.position = Iso.project(point) + Vector2(0, -45)
	game.camera.zoom = Vector2.ONE * zoom_value
	game.camera.force_update_scroll()
	await frame()
	if not rendered:
		return null
	var image: Image = get_viewport().get_texture().get_image()
	check(image.save_webp(EVIDENCE + name_value + ".webp", false, 0.94) == OK, "render " + name_value)
	return image

func inspect_seams(image: Image, axis: String) -> void:
	var nodes: Array[WorldAuthorNode] = []
	var minimap: CartographicMap = game.hud.world_hud.minimap
	var minimap_rect: Rect2 = minimap.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, minimap.size)
	for child: Node in WorldAuthorTree.nodes(game_source):
		if child is WorldAuthorNode and child.stable_id.begins_with(axis):
			nodes.append(child)
	nodes.sort_custom(func(a: WorldAuthorNode, b: WorldAuthorNode) -> bool:
		var pa: Vector2 = WorldAuthorTree.logical_position(a, game_source)
		var pb: Vector2 = WorldAuthorTree.logical_position(b, game_source)
		return pa.x < pb.x if axis.contains("north") or axis.contains("south") else pa.y < pb.y)
	for index: int in range(1, nodes.size()):
		var a: Vector2 = WorldAuthorTree.logical_position(nodes[index - 1], game_source)
		var b: Vector2 = WorldAuthorTree.logical_position(nodes[index], game_source)
		if a.distance_to(b) > 210:
			continue
		var world_point: Vector2 = Iso.project((a + b) * 0.5) + Vector2(0, -38)
		var pixel: Vector2i = Vector2i(game.get_canvas_transform() * world_point)
		if pixel.x < 8 or pixel.y < 8 or pixel.x >= image.get_width() - 8 or pixel.y >= image.get_height() - 8:
			continue
		# The circular minimap covers the underlying wall in some close-ups.
		if minimap.visible and minimap_rect.grow(6).has_point(Vector2(pixel)):
			continue
		if pixel.y > image.get_height() - 100 or (pixel.x < 85 and pixel.y < 335):
			continue
		var red_hits: int = 0
		for y: int in range(-5, 6):
			for x: int in range(-5, 6):
				var color: Color = image.get_pixel(pixel.x + x, pixel.y + y)
				if color.r > color.g * 1.25 and color.r > color.b * 1.3:
					red_hits += 1
		seam_metrics.append({"a": nodes[index - 1].stable_id, "b": nodes[index].stable_id, "red_plaster_pixels": red_hits})
		check(red_hits >= 5, "actual rendered red wall covers joint " + nodes[index - 1].stable_id + "/" + nodes[index].stable_id)

var game_source: WorldMap2D

func run() -> void:
	check(not PartyProgress.persistence_enabled, "wall tests isolate formal saves")
	WorldCatalog.initialize()
	check(WorldCatalog.definitions["shaolin_temple"].scene_path == "res://features/world/data/shaolin_temple.tscn", "formal world catalog loads the original temple scene")
	var old: WorldMap2D = load(EVIDENCE + "originals/features__world__data__shaolin_temple.tscn").instantiate() as WorldMap2D
	game_source = load("res://features/world/data/shaolin_temple.tscn").instantiate() as WorldMap2D
	var before: WorldMapDefinition = old.compile_definition()
	var after: WorldMapDefinition = game_source.compile_definition()
	check(native_snapshot(old) == native_snapshot(game_source), "all native terrain and masks preserved byte-for-byte")
	check(before.portals == after.portals and before.entries == after.entries, "original portal destinations, coordinates and arrivals preserved")
	check(after.habitats.size()==3, "D23 three authored temple courtyards")
	for habitat: WorldHabitat in before.habitats:
		var next: WorldHabitat = after.habitat(habitat.habitat_id)
		check(next != null and MONSTER_LAYOUT.shape_matches("shaolin_temple",next), "guardian region follows explicit D23 courtyard layout")
	var original_ids: Array[String] = []
	for child: Node in WorldAuthorTree.nodes(old):
		if child is WorldAuthorNode:
			original_ids.append(child.stable_id)
	var current_ids: Array[String] = []
	var corner_count: int = 0
	var module_count: int = 0
	for child: Node in WorldAuthorTree.nodes(game_source):
		if not child is WorldAuthorNode:
			continue
		current_ids.append(child.stable_id)
		var data: WorldSceneryDefinition = child.sprite_definition
		if data == null or not data.has_meta("wall_kit"):
			continue
		module_count += 1
		if child.stable_id.begins_with("wall_corner_"):
			corner_count += 1
		var ports: PackedVector2Array = data.get_meta("source_ports")
		var targets: PackedVector2Array = data.get_meta("projected_ports")
		var transform: Transform2D = data.artwork_transform()
		var calibrated: bool = true
		for i: int in ports.size():
			calibrated = calibrated and (transform * ports[i]).distance_to(targets[i]) < 0.001
		check(calibrated, child.stable_id + " source connection points match exact 2:1 projection")
		var artwork: Sprite2D = child.get_node("Artwork") as Sprite2D
		check(artwork.transform.is_equal_approx(transform), child.stable_id + " editor artwork uses same transform")
		var view: WorldSceneryView = WorldSceneryView.new()
		view.initialize(data, Vector2.ZERO)
		check(view.sprite.transform.is_equal_approx(transform), child.stable_id + " runtime artwork uses same transform")
		view.free()
	check(corner_count == 4, "all four perimeter corners have dedicated joined wall/roof sprites")
	check(module_count == 48, "44 existing straight wall authors plus four new corners")
	for id: String in original_ids:
		check(current_ids.has(id), "preserve author id " + id)
	var legacy: WorldSceneryDefinition = load("res://features/world/data/scenery/shaolin_hall.tres")
	var expected: Transform2D = Transform2D(Vector2(legacy.sprite_scale, 0), Vector2(0, legacy.sprite_scale), -legacy.foot_anchor * legacy.sprite_scale)
	check(legacy.artwork_transform().is_equal_approx(expected), "identity calibration preserves all unrelated scenery")
	old.free()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode != &"world":
		await get_tree().process_frame
	game.set_physics_process(false)
	var entrance: Array[Dictionary] = game.world_context.current_map().portals.filter(func(p: Dictionary) -> bool: return p.id == "shaolin_door")
	check(entrance.size() == 1, "original river map retains one real temple entrance")
	if entrance.is_empty():
		game_source.free()
		get_tree().quit(1)
		return
	game.world_context.state["player"]["position"] = entrance[0]["point"]
	var transition: Dictionary = game.world_context.begin_portal("shaolin_door")
	check(transition["ok"], "original temple entrance starts the normal game transition")
	if not transition["ok"]:
		game_source.free()
		get_tree().quit(1)
		return
	while game.mode != &"world" or game.world_context.state["mode"] != "EXPLORING":
		await get_tree().process_frame
	check(game.world_context.current_map().map_id == "shaolin_temple", "normal entrance loads the repaired original temple")
	game.world_context.state["player"]["position"] = Vector2(1392, 928)
	game.world_hero.position = Vector2(1392, 928)
	game.world_pose.reset(Vector2(1392, 928))
	game.set_process(false)
	game.set_physics_process(false)
	game.world_hover.set_process(false)
	check(game.ground.scenery_views.size() == after.scenery.size(), "live world includes all saved wall modules")
	await shot("temple-overview", Vector2(1024, 768), 0.34)
	var training: Image = await shot("training-courtyard", Vector2(1456, 880), 0.82)
	if training != null:
		inspect_seams(training, "outer_east_")
	await shot("corner-north", Vector2(224, 224), 1.1)
	var south: Image = await shot("corner-south", Vector2(1824, 1312), 1.1)
	if south != null:
		inspect_seams(south, "outer_south_")
		inspect_seams(south, "outer_east_")
	await shot("corner-west", Vector2(224, 1312), 1.1)
	await shot("corner-east", Vector2(1824, 224), 1.1)
	if rendered:
		check(not seam_metrics.is_empty(), "joint evidence sampled from actual Compatibility render")
	var file: FileAccess = FileAccess.open(EVIDENCE + ("render-results.json" if rendered else "headless-results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "failed": failures.size(), "failures": failures, "rendered": rendered, "joint_pixels": seam_metrics, "manual_mouse_review": "unverified"}, "\t"))
	game_source.free()
	print("SHAOLIN_WALL_RESULT passed=", passed, " failed=", failures.size(), " rendered=", rendered)
	get_tree().quit(0 if failures.is_empty() else 1)

