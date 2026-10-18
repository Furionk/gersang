class_name CombatEffect
extends Node2D
var life: float = 0.6
var age: float = 0.0
var radius: float = 70.0
var tint: Color = Color(1, 0.6, 0.2)
var kind: int = 0
var from_point: Vector2
var to_point: Vector2
var text: String = ""
func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
	else:
		queue_redraw()
func _draw() -> void:
	var ratio: float = age / life
	var color: Color = tint
	color.a *= 1.0 - ratio
	if text != "":
		draw_string(ThemeDB.fallback_font, Vector2(-10, -48 - age * 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	elif kind == -1:
		draw_line(from_point - position, (from_point.lerp(to_point, ratio) - position), color, 3.0)
		draw_circle(from_point.lerp(to_point, ratio) - position, 4, color)
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Iso.CIRCLE_SCALE)
		for i: int in 3:
			draw_arc(Vector2.ZERO, maxf(2, radius * (ratio + i * 0.17)), 0, TAU, 48, color, 3.0 - i * 0.6)
		draw_set_transform(Vector2.ZERO)
		if kind == 1:
			for i: int in 5:
				var x: float = (i - 2) * 21.0
				draw_polyline(PackedVector2Array([Vector2(x, -115), Vector2(x - 9, -78), Vector2(x + 9, -61), Vector2(x, -4)]), color, 3.0)
