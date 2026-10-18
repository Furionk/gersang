extends Node

var game: GameDirector
var failures: int = 0
var passed: int = 0

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS | ", title)
	else:
		failures += 1
		push_error("FAIL | " + title)

func _ready() -> void:
	get_tree().create_timer(20).timeout.connect(func() -> void:
		push_error("SELECTION_INPUT_TIMEOUT")
		get_tree().quit(2))
	call_deferred("run")

func motion(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func button(at: Vector2, pressed: bool, shift: bool = false, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = mouse_button
	event.pressed = pressed
	event.shift_pressed = shift
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func click(at: Vector2, shift: bool = false) -> void:
	await motion(at)
	await button(at, true, shift)
	await button(at, false, shift)

func screen_point(unit: TacticalUnit) -> Vector2:
	return game.get_canvas_transform() * (Iso.project(unit.position) + Vector2(0, -35))

func skill_ids(units: Array[TacticalUnit]) -> Array:
	var result: Dictionary = {}
	for unit: TacticalUnit in units:
		for skill: SkillDefinition in unit.available_skills():
			if skill.manual(): result[skill.id]=true
	var ids: Array = result.keys(); ids.sort()
	return ids
func hud_ids() -> Array:
	var ids: Array = game.hud.skill_buttons.keys(); ids.sort()
	return ids

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
	await get_tree().process_frame
	var guard: TacticalUnit = game.get_unit(game.roster_ids[1])
	var mage: TacticalUnit = game.get_unit(game.roster_ids[3])
	var guard_at: Vector2 = screen_point(guard)
	var mage_at: Vector2 = screen_point(mage)
	print("CLICK_POINTS | guard=", guard_at, " mage=", mage_at)
	await click(guard_at)
	check(game.selection.selected_ids == [guard.unit_id], "viewport mouse click selects guard without Array type error")
	check(hud_ids()==skill_ids([guard]) and game.hud.skill_buttons.has(&"blast"), "mouse selection updates exact authored owned skill grid")
	await click(mage_at, true)
	check(game.selection.selected_ids.size() == 2 and mage.unit_id in game.selection.selected_ids, "viewport Shift click adds another unit")
	check(hud_ids()==skill_ids([guard,mage]), "Shift selection displays exact authored skill union")
	await click(mage_at, true)
	check(game.selection.selected_ids == [guard.unit_id], "viewport Shift click toggles selected unit off")
	await click(mage_at)
	check(game.selection.selected_ids == [mage.unit_id], "plain click replaces selection")
	var blank: Vector2 = Vector2(850, 180)
	check(game.pick_unit(game.get_canvas_transform().affine_inverse() * blank, 0) == null, "blank-click fixture has no friendly unit")
	await click(blank, true)
	check(game.selection.selected_ids == [mage.unit_id], "Shift blank click preserves selection")
	await click(blank)
	check(game.selection.selected_ids.is_empty() and game.hud.skill_buttons.is_empty(), "viewport blank click clears selection and skills without Array type error")
	# Exercise the same input handler's drag branch, not select_box directly.
	var first: Vector2 = guard_at.min(mage_at) - Vector2(8, 8)
	var last: Vector2 = guard_at.max(mage_at) + Vector2(8, 8)
	await motion(first)
	await button(first, true)
	await motion(last)
	await button(last, false)
	check(guard.unit_id in game.selection.selected_ids and mage.unit_id in game.selection.selected_ids, "viewport drag selects friendly units")
	game.camera.position += Vector2(80, 45)
	game.camera.force_update_scroll()
	await click(screen_point(guard))
	check(game.selection.selected_ids == [guard.unit_id], "mouse click remains accurate after camera scrolling")
	await click(game.hud.battle_layout.settings_button.get_global_rect().get_center())
	check(game.hud.is_modal_open() and game.selection.selected_ids == [guard.unit_id] and not game.selection.dragging, "native GUI click opens settings without changing battle selection")
	game.hud.close_windows()
	var move_at: Vector2 = Vector2(780, 300)
	await motion(move_at)
	await button(move_at, true, false, MOUSE_BUTTON_RIGHT)
	await button(move_at, false, false, MOUSE_BUTTON_RIGHT)
	var ground_point: Vector2 = Iso.unproject(game.get_canvas_transform().affine_inverse() * move_at)
	check(guard.active.get("kind", "") == "move" and (guard.active.get("point", Vector2.ZERO) as Vector2).is_equal_approx(ground_point), "right click uses event position for ground movement")
	var enemy: TacticalUnit = game.get_unit(game.living_ids(1)[0])
	enemy.position = guard.position + Vector2(250, 0)
	var enemy_at: Vector2 = screen_point(enemy)
	await motion(enemy_at)
	await button(enemy_at, true, false, MOUSE_BUTTON_RIGHT)
	await button(enemy_at, false, false, MOUSE_BUTTON_RIGHT)
	check(guard.active.get("kind", "") == "attack" and int(guard.active.get("target", -1)) == enemy.unit_id, "right click uses event position to attack enemy")
	print("GERSANG_SELECTION_INPUT_%s | passed=%d failed=%d" % ["PASS" if failures == 0 else "FAIL", passed, failures])
	get_tree().quit(0 if failures == 0 else 1)
