class_name MiniMap
extends Control
signal located(projected: Vector2)
var director: GameDirector
var circular: bool = false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local: Vector2 = event.position
		var centered: Vector2 = (local - size * 0.5) / _scale()
		var world: Vector2 = centered + Iso.project(Vector2(680, 560))
		located.emit(world)
		accept_event()
func _scale() -> float:
	return minf(size.x / 2550.0, size.y / 1360.0) * 0.88
func _draw() -> void:
	if director == null:
		return
	var center: Vector2 = size * 0.5
	if circular:
		draw_circle(center, minf(size.x, size.y) * 0.48, Color(0.10, 0.09, 0.06, 0.95))
		draw_arc(center, minf(size.x, size.y) * 0.48, 0, TAU, 64, Color(0.67, 0.59, 0.40), 3.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.055, 0.045, 0.94))
	var scale_factor: float = _scale()
	var origin: Vector2 = Iso.project(Vector2(680, 560))
	var polygon: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in [Vector2.ZERO, Vector2(1360, 0), Vector2(1360, 1120), Vector2(0, 1120)]:
		polygon.append(center + (Iso.project(p) - origin) * scale_factor)
	draw_colored_polygon(polygon, Color(0.25, 0.29, 0.20) if director.mode in [&"world", &"countdown"] else Color(0.29, 0.26, 0.21))
	if director.ground != null:
		for rect: Rect2i in director.ground.blocked:
			var outline: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in [Vector2(rect.position), Vector2(rect.position + Vector2i(rect.size.x, 0)), Vector2(rect.end), Vector2(rect.position + Vector2i(0, rect.size.y))]:
				outline.append(center + (Iso.project(p * Iso.CELL) - origin) * scale_factor)
			draw_colored_polygon(outline, Color(0.07, 0.10, 0.08))
	for unit: TacticalUnit in director.units.values():
		if unit.alive():
			var at: Vector2 = center + (Iso.project(unit.position) - origin) * scale_factor
			draw_circle(at, 2.2, Color(0.68, 0.90, 0.57) if unit.team == 0 else Color(0.92, 0.37, 0.24))
	for marker: GameDirector.WorldMarker in director.markers:
		draw_circle(center + (marker.position - origin) * scale_factor, 3.3, Color(0.98, 0.73, 0.28))
	var camera_point: Vector2 = center + (director.camera.position - origin) * scale_factor
	draw_rect(Rect2(camera_point - Vector2(35, 20), Vector2(70, 40)), Color(0.85, 0.78, 0.58), false, 1.0)
