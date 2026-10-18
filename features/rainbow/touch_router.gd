extends Node
## Encounter-local touch ownership. Screen events never depend on mouse emulation.
var hud: RainbowActionHud
var fingers: Dictionary = {}
var move_finger: int = -1
var aim: Vector2 = Vector2.ZERO
var origin: Vector2
var fade: Tween

func reset() -> void:
	if fade != null: fade.kill(); fade = null
	fingers.clear()
	move_finger = -1
	aim = Vector2.ZERO
	if not is_instance_valid(hud): return
	hud.stick.reset()
	hud.run_held = false
	hud.battle.held_action = &""
	for button: Button in hud.action_buttons.values(): button.modulate = Color.WHITE
	if hud.touch_mode: hud.stick.hide()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]: reset()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(hud) or hud.battle.game.mode != &"battle":
		reset()
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if hud.touch_mode: get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if not hud.touch_override: hud.set_touch_mode(true)
		if not hud.touch_mode: return
		var owned: bool = fingers.has(event.index)
		if event.canceled:
			reset()
		elif event.pressed:
			begin(event.index, event.position)
		else:
			finish(event.index, event.position)
		if fingers.has(event.index) or owned: get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		drag(event.index, event.position)
		get_viewport().set_input_as_handled()

func begin(index: int, point: Vector2) -> void:
	for kind: StringName in hud.action_buttons:
		if hud.action_buttons[kind].get_global_rect().has_point(point):
			fingers[index] = {"role":kind, "start":point, "dragged":false}
			if kind == &"run": hud.run_held = true
			else: hud.battle.request(kind)
			refresh_held()
			return
	if hud.roster_panel.get_global_rect().has_point(point):
		fingers[index] = {"role":&"roster", "start":point, "scroll":hud.roster_scroll.scroll_horizontal, "dragged":false}
		return
	if hud.boss_panel.visible and hud.boss_panel.get_global_rect().has_point(point): return
	for control: Node in hud.root.find_children("*", "Button", true, false):
		if control.is_visible_in_tree() and not control.disabled and control.get_global_rect().has_point(point):
			fingers[index] = {"role":&"ui", "start":point, "dragged":false, "button":control}
			return
	# Root-level panels, menus and status controls exclude the battlefield.
	for child: Node in hud.root.get_children():
		if child == hud.stick or child == hud.actions or not child is Control: continue
		if child.visible and child.mouse_filter != Control.MOUSE_FILTER_IGNORE and child.get_global_rect().has_point(point): return
	if point.x > hud.root.size.x * 0.48 or move_finger != -1: return
	move_finger = index
	fingers[index] = {"role":&"move", "start":point, "dragged":false}
	var margin := Vector2.ONE * 64 * hud.touch_scale
	var safe: Rect2 = hud.touch_safe_rect()
	origin = point
	var display_origin: Vector2 = point.clamp(safe.position + margin,safe.end-margin)
	if fade != null: fade.kill()
	hud.stick.modulate.a = 1.0
	hud.stick.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.stick.scale = Vector2.ONE * hud.touch_scale
	hud.stick.position = display_origin - hud.stick.size * 0.5 * hud.touch_scale
	hud.stick.show()
	drag(index, point)

func drag(index: int, point: Vector2) -> void:
	var state: Dictionary = fingers[index]
	var delta: Vector2 = point - state.start
	if delta.length() > 12 * hud.touch_scale: state.dragged = true
	if state.role == &"move":
		var raw: Vector2 = (point - origin) / (48 * hud.touch_scale)
		hud.stick.value = raw.normalized() * clampf((raw.length() - 0.15) / 0.85, 0, 1)
		hud.stick.queue_redraw()
	elif state.role == &"roster" and state.dragged:
		hud.roster_scroll.scroll_horizontal = int(state.scroll - delta.x)
	elif state.role == &"ranged" and state.dragged:
		aim = Iso.unproject(delta).normalized()

func finish(index: int, point: Vector2) -> void:
	if not fingers.has(index): return
	var state: Dictionary = fingers[index]
	fingers.erase(index)
	if state.role == &"move":
		move_finger = -1
		hud.stick.reset()
		fade = create_tween()
		fade.tween_property(hud.stick, "modulate:a", 0.0, 0.12)
	elif state.role == &"roster" and not state.dragged:
		for id: int in hud.buttons:
			if hud.buttons[id].get_global_rect().has_point(point):
				hud.battle.switch_to(id)
				break
	elif state.role == &"ui" and not state.dragged:
		var button: Button = state.button
		if is_instance_valid(button) and button.get_global_rect().has_point(point):
			if button.toggle_mode: button.button_pressed = not button.button_pressed
			button.pressed.emit()
	if state.role == &"ranged": aim = Vector2.ZERO
	refresh_held()

func _exit_tree() -> void:
	reset()

func refresh_held() -> void:
	hud.run_held = false
	hud.battle.held_action = &""
	for button: Button in hud.action_buttons.values(): button.modulate = Color.WHITE
	for state: Dictionary in fingers.values():
		if hud.action_buttons.has(state.role): hud.action_buttons[state.role].modulate = Color(0.72,0.65,0.5)
		if state.role == &"run": hud.run_held = true
		elif state.role in [&"melee", &"ranged"]: hud.battle.held_action = state.role
