class_name RainbowActionStick
extends Control
var value: Vector2 = Vector2.ZERO
var finger: int = -1
var mouse_drag: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(120, 120)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			update_value(event.position)
		elif not event.pressed and event.index == finger: reset()
		accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		update_value(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_drag = event.pressed
		if event.pressed: update_value(event.position)
		else: reset()
		accept_event()
	elif event is InputEventMouseMotion and mouse_drag:
		update_value(event.position)
		accept_event()

func update_value(point: Vector2) -> void:
	var raw: Vector2 = (point - size * 0.5) / 44.0
	value = Vector2.ZERO if raw.length() < 0.18 else raw.limit_length()
	queue_redraw()

func reset() -> void:
	finger = -1
	mouse_drag = false
	value = Vector2.ZERO
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]: reset()

func _draw() -> void:
	draw_circle(size * 0.5, 54, Color(0.05, 0.08, 0.11, 0.85))
	draw_arc(size * 0.5, 54, 0, TAU, 48, Color(0.9, 0.65, 0.32), 2)
	draw_arc(size * 0.5, 49, 0, TAU, 64, Color("705532"), 1)
	for index: int in 8:
		var direction := Vector2.RIGHT.rotated(index * PI / 4)
		draw_line(size * 0.5 + direction * 39, size * 0.5 + direction * 49, Color("b08a4c"), 2)
	var knob: Vector2 = size * 0.5 + value * 34
	draw_circle(knob, 20, Color("5e4527"))
	draw_arc(knob, 20, 0, TAU, 32, Color("e4bf77"), 2)
	draw_colored_polygon(PackedVector2Array([knob + Vector2(0,-13), knob + Vector2(11,0), knob + Vector2(0,13), knob + Vector2(-11,0)]), Color("c89a4d"))
