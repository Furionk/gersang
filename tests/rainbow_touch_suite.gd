extends "res://tests/rainbow_action_suite.gd"

func touch(router: Node, index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index; event.position = point; event.pressed = pressed; event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(router: Node, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index; event.position = point
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func shot(title: String) -> void:
	await super.shot(title)
	if title != "02-action-battle": return
	var hud: RainbowActionHud = game.action_battle.hud
	var router: Node = hud.touch_router
	hud.set_touch_mode(true)
	await get_tree().process_frame
	for kind: StringName in hud.action_buttons:
		var button: Button = hud.action_buttons[kind]
		check(button.size.x / hud.touch_scale >= (75.9 if kind == &"melee" else 63.9), "touch target meets dp size: " + str(kind))
		check(not button.get_global_rect().intersects(hud.roster_panel.get_global_rect()), "touch cross excludes roster: " + str(kind))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/rainbow-overhaul/mobile-controls.png")
	var point := Vector2(100, get_viewport().get_visible_rect().size.y * 0.6)
	touch(router, 7, point, true)
	motion(router, 7, point + Vector2(180,0))
	check(hud.stick.value.x > 0.99, "floating stick saturates outside its radius")
	var attack: Vector2 = hud.action_buttons[&"melee"].get_global_rect().get_center()
	touch(router, 8, attack, true)
	check(router.move_finger == 7 and game.action_battle.held_action == &"melee", "two screen fingers own movement and attack independently")
	touch(router, 8, attack, false)
	check(hud.stick.value.x > 0.99 and game.action_battle.held_action == &"", "releasing attack preserves movement")
	var guard: Vector2 = hud.action_buttons[&"guard"].get_global_rect().get_center()
	touch(router, 11, guard, true)
	check(router.move_finger == 7 and router.fingers.has(11),"move and guard retain independent finger ownership")
	touch(router,11,guard,false)
	var run: Vector2 = hud.action_buttons[&"run"].get_global_rect().get_center()
	touch(router,12,run,true)
	check(hud.run_held and router.move_finger == 7,"run hold coexists with movement")
	touch(router,12,run,false)
	check(not hud.run_held and router.move_finger == 7,"run release leaves movement active")
	var ranged: Vector2 = hud.action_buttons[&"ranged"].get_global_rect().get_center()
	touch(router, 9, ranged, true)
	motion(router, 9, ranged + Vector2(60,30))
	check(router.aim.length() > 0.99, "ranged drag provides manual logical aim")
	touch(router, 7, point, false)
	check(hud.stick.value == Vector2.ZERO and router.aim.length() > 0.99, "movement release immediately stops without stealing ranged finger")
	touch(router, 9, ranged, false, true)
	check(router.fingers.is_empty() and router.aim == Vector2.ZERO, "touch cancellation releases all ownership")
	touch(router, 10, point, true)
	motion(router, 10, point + Vector2(80,0))
	router._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(hud.stick.value == Vector2.ZERO and router.fingers.is_empty(), "focus loss clears movement and fingers")
	var edge := Vector2(2,point.y)
	touch(router,20,edge,true)
	check(hud.stick.value == Vector2.ZERO,"edge touch clamps visual base without jumping movement")
	motion(router,20,edge+Vector2(2,0))
	check(hud.stick.value == Vector2.ZERO,"fifteen percent dead zone rejects tiny motion")
	motion(router,20,edge+Vector2(24*hud.touch_scale,0))
	check(hud.stick.value.length() > 0.1 and hud.stick.value.length() < 0.8,"joystick preserves analogue strength")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/rainbow-overhaul/mobile-floating-stick.png")
	touch(router,20,edge,false)
	var selected: int = game.action_battle.controlled_id
	var roster_point: Vector2 = hud.buttons[selected].get_global_rect().get_center()
	touch(router,21,roster_point,true)
	motion(router,21,roster_point-Vector2(80,0))
	touch(router,21,roster_point-Vector2(80,0),false)
	check(game.action_battle.controlled_id == selected and router.move_finger == -1,"roster swipe neither selects a member nor starts movement")
	touch(router,22,point,true)
	motion(router,22,point+Vector2(80,0))
	get_viewport().size_changed.emit()
	check(router.fingers.is_empty() and hud.stick.value == Vector2.ZERO,"viewport rotation event clears captured fingers")
	hud.set_touch_mode(false)
	await get_tree().process_frame
