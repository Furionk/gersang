extends Node
var game: GameDirector
var passed: int = 0
var failed: int = 0
func check(ok: bool, caption: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("PASS " if ok else "FAIL ", caption)
func key(code: Key, echo: bool = false) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.pressed = true; e.echo = echo
	get_viewport().push_input(e, true)
	await get_tree().process_frame
	e = e.duplicate(); e.pressed = false; e.echo = false
	get_viewport().push_input(e, true)
func _ready() -> void:
	get_tree().create_timer(80).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/tests/ui-feedback")
	GameSettings.settings_path = "res://artifacts/tests/ui-feedback/settings.cfg"
	game = load("res://main.tscn").instantiate()
	add_child(game)
	while game.mode != &"world": await get_tree().process_frame
	game.set_physics_process(false)
	var hud: GameHud = game.hud
	check(not PartyProgress.persistence_enabled, "isolated progress")
	hud.progression.show_inventory()
	hud.progression.inventory_tab.grab_focus()
	await key(KEY_X)
	check(not hud.progression.sheet.visible, "focused dossier closes with X")
	hud.world_hud.toggle_map()
	await key(KEY_X)
	check(not hud.world_hud.map_panel.visible, "map closes with X")
	hud.world_hud.show_info("Test", "Test")
	await key(KEY_X)
	check(not hud.world_hud.info_panel.visible, "info closes with X")
	hud.toggle_item_debug()
	hud.item_debug.search.grab_focus()
	await key(KEY_X)
	check(not hud.item_debug.visible, "search focus still permits closing")
	hud.toggle_menu()
	hud.show_settings()
	await key(KEY_X, true)
	check(hud.settings_panel.visible and hud.window.visible, "held key does not close windows")
	await key(KEY_X)
	check(not hud.settings_panel.visible and hud.window.visible, "only topmost window closes")
	await key(KEY_ESCAPE)
	check(not hud.window.visible, "Escape compatible")
	hud.show_settings()
	hud._request_binding("command_move")
	var before: int = GameSettings.bindings.command_move
	await key(KEY_X)
	check(hud.binding_action == "" and hud.settings_panel.visible and GameSettings.bindings.command_move == before, "X cancels capture without rebinding or closing")
	await key(KEY_X)
	hud.progression.show_stats()
	hud.progression.respec_panel.show()
	await key(KEY_X)
	check(hud.progression.sheet.visible and not hud.progression.respec_panel.visible, "nested confirmation closes before dossier")
	await key(KEY_X)
	var fx: Node2D = game.ground_click_feedback
	for i: int in 6: fx.play_at(Vector2(i * 10, 0))
	check(fx.rings.size() == 4, "rapid clicks capped at four")
	fx.clear()
	# Use the production input branch at a legal point away from actors.
	var origin: Vector2 = game.world_context.state.player.position
	var at: Vector2 = origin + Vector2(140, 0)
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true
	e.position = game.get_canvas_transform() * Iso.project(at)
	game._unhandled_input(e)
	check(fx.rings.size() == 1, "accepted ground move produces feedback")
	if not fx.rings.is_empty():
		check(fx.rings[0].at.is_equal_approx(Iso.project(at)), "feedback uses click world coordinate")
	game.camera.position += Vector2(10, 0)
	check(fx.position == Vector2.ZERO, "feedback stays world anchored")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/tests/ui-feedback")
		get_viewport().get_texture().get_image().save_png("res://artifacts/tests/ui-feedback/ring.png")
	await get_tree().create_timer(0.4).timeout
	check(fx.rings.is_empty(), "feedback expires")
	hud.progression.show_inventory()
	game._unhandled_input(e)
	check(fx.rings.is_empty(), "modal blocks ground feedback")
	hud.progression.close()
	e.position = game.get_canvas_transform() * Iso.project(Vector2(-100000, -100000))
	game._unhandled_input(e)
	check(fx.rings.is_empty(), "unreachable click does not confirm")
	e.position = game.get_canvas_transform() * (Iso.project(game.world_hero.position) - Vector2(0, 28))
	game._unhandled_input(e)
	check(fx.rings.is_empty(), "hero inspection does not confirm ground move")
	var monster: Dictionary = game.world_context.state.maps[game.world_context.current_map().map_id].parties.values()[0]
	e.position = game.get_canvas_transform() * (Iso.project(monster.position) - Vector2(0, 28))
	game._unhandled_input(e)
	check(fx.rings.is_empty(), "monster click does not confirm ground move")
	fx.play_at(Vector2.ZERO)
	game.start_battle(Catalog.encounters()[0])
	check(fx.rings.is_empty(), "scene transition clears feedback")
	while game.selection == null: await get_tree().process_frame
	hud.show_sequence()
	await key(KEY_X)
	check(not hud.sequence_panel.visible, "battle sequence closes")
	check(GameSettings.bindings.get("skill_earth_claw", 0) == KEY_X or load("res://features/skills/data/earth_claw.tres").default_key == KEY_X, "original X skill binding retained")
	var trial: Dictionary = game.debug_trial_unit("kohime")
	var hero: TacticalUnit = game.get_unit(trial.unit_id)
	var skill: SkillDefinition = load("res://features/skills/data/earth_claw.tres")
	hud.toggle_menu()
	await key(KEY_X)
	hero.tick(1.0 / 60.0)
	check(hero.abilities.active_summon_groups.get(skill.id, []).is_empty(), "closing battle window cannot summon")
	await key(KEY_X)
	hero.tick(1.0 / 60.0)
	check(hud.window.visible and hero.abilities.active_summon_groups.get(skill.id, []).is_empty(), "fresh X opens menu without summoning")
	hud.show_result("defeat")
	await key(KEY_X)
	check(hud.result.visible, "X cannot dismiss result workflow")
	print("UI_FEEDBACK_RESULT passed=%d failed=%d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

