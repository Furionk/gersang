extends Node

var game: GameDirector
var passed: int = 0
var failures: int = 0

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS | ", title)
	else:
		failures += 1
		push_error("FAIL | " + title)

func _ready() -> void:
	get_tree().create_timer(40).timeout.connect(func() -> void:
		push_error("WINDOW_RESIZE_TIMEOUT")
		get_tree().quit(2))
	call_deferred("run")

func click_physical(at: Vector2) -> void:
	# false = real window coordinates; Godot applies its stretch transform.
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion, false)
	await get_tree().process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, false)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_viewport().push_input(event, false)
	await get_tree().process_frame

func physical_point(virtual_point: Vector2) -> Vector2:
	return get_viewport().get_stretch_transform() * virtual_point

func run() -> void:
	LegacyPartyFixture.install()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	game.cinematic_camera = false
	while game.mode != &"world":
		await get_tree().process_frame
	game.start_battle(Catalog.encounters()[0])
	while game.mode != &"battle":
		await get_tree().process_frame
	game.set_physics_process(false)
	var guard: TacticalUnit = game.get_unit(game.roster_ids[1])
	var dock: Control = game.hud.root.get_node("BattleDock") as Control
	var header: Control = game.hud.root.get_node("Header") as Control
	var sizes: Array[Vector2i] = [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(1720, 720), Vector2i(900, 900), Vector2i(1280, 720)]
	for size: Vector2i in sizes:
		get_window().size = size
		for frame: int in 8:
			await get_tree().process_frame
		game.camera.force_update_scroll()
		var extent: Vector2 = get_viewport().get_visible_rect().size
		var label: String = "%dx%d" % [size.x, size.y]
		print("RESIZE | ", label, " virtual=", extent, " actual=", get_window().size)
		check(get_window().size == size, label + " native window resized")
		check(game.hud.root.size.is_equal_approx(extent), label + " HUD fills viewport")
		check(is_equal_approx(extent.x / extent.y, float(size.x) / size.y), label + " viewport matches window aspect without letterbox")
		var stretch: Transform2D = get_viewport().get_stretch_transform()
		check(is_equal_approx(stretch.x.length(), stretch.y.length()), label + " uniform scaling preserves sprite proportions")
		check(header.size.x == extent.x and dock.size.x == extent.x and is_equal_approx(dock.position.y + dock.size.y, extent.y), label + " header and dock stretch and stay at edges")
		check(is_equal_approx(game.hud.battle_layout.commands_frame.get_global_rect().end.x, extent.x) and game.hud.battle_layout.commands_frame.get_global_rect().encloses(game.hud.battle_layout.skill_scroll.get_global_rect()), label + " skills and command controls stay right-aligned")
		check(game.hud.sequence_label.position.y + game.hud.sequence_label.size.y <= dock.size.y, label + " reserved-skill row remains entirely inside dock")
		check(is_equal_approx(game.hud.world_mini.position.x + game.hud.world_mini.size.x, extent.x - 18) and game.hud.world_mini.size == Vector2(192, 192), label + " circular minimap stays square at top right")
		check(game.edge_scroll_direction(Vector2(extent.x - 2, extent.y * 0.5)) == Vector2.RIGHT and game.edge_scroll_direction(Vector2(extent.x * 0.5, extent.y - 2)) == Vector2.DOWN, label + " camera scrolling uses actual viewport edges")
		check(game.edge_scroll_direction(Vector2(extent.x + 1, 100)) == Vector2.ZERO, label + " outside viewport does not scroll")
		game.selection.select_ids([])
		var at: Vector2 = game.get_canvas_transform() * (Iso.project(guard.position) + Vector2(0, -35))
		await click_physical(physical_point(at))
		check(game.selection.selected_ids == [guard.unit_id], label + " physical-window mouse selects correct unit")
		await click_physical(physical_point(game.hud.battle_layout.settings_button.get_global_rect().get_center()))
		check(game.hud.settings_panel != null and game.hud.settings_panel.visible and game.selection.selected_ids == [guard.unit_id], label + " resized GUI click does not issue battle selection")
		check((game.hud.settings_panel.position + game.hud.settings_panel.size * 0.5).is_equal_approx(extent * 0.5), label + " settings dialog stays centered")
		game.hud.close_windows()
		await get_tree().create_timer(0.15).timeout
		if DisplayServer.get_name() != "headless" and size in [Vector2i(800, 450), Vector2i(1024, 768), Vector2i(1720, 720)]:
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			check(image.get_size() == size, label + " rendered at actual window resolution")
			image.save_png(TestArtifacts.output("resize","resize-%s.png" % label))
	check(game.render_root.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "world sprites use nearest-neighbor filtering")
	game.selection.select_ids(game.roster_ids)
	await get_tree().process_frame
	check(game.hud.battle_layout.skill_scroll.get_global_rect().end.y <= game.hud.sequence_label.get_global_rect().position.y, "all selected skills fit above reserved-skill row")
	print("GERSANG_WINDOW_RESIZE_%s | passed=%d failed=%d" % ["PASS" if failures == 0 else "FAIL", passed, failures])
	get_tree().quit(0 if failures == 0 else 1)
