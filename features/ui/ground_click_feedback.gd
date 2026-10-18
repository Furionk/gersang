extends Node2D
## Presentation only: positions are already projected world coordinates.
const STYLE:UiFeedbackProfile=preload("res://features/ui/data/feedback.tres")
const DURATION: float = 0.35
const MAX_RINGS: int = 4
var rings: Array[Dictionary] = []

func _ready() -> void:
	z_index = 3500
	set_process(false)

func play_at(at: Vector2) -> void:
	if rings.size() == MAX_RINGS: rings.pop_front()
	rings.append({"at": at, "age": 0.0})
	set_process(true)
	queue_redraw()

func clear() -> void:
	rings.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	for ring: Dictionary in rings: ring.age += delta
	while not rings.is_empty() and rings[0].age >= STYLE.ring_duration:
		rings.pop_front()
	set_process(not rings.is_empty())
	queue_redraw()

func _draw() -> void:
	for ring: Dictionary in rings:
		var t: float = clampf(float(ring.age) / STYLE.ring_duration, 0.0, 1.0)
		var radius: float = lerpf(STYLE.ring_start_radius, STYLE.ring_end_radius, 1.0 - pow(1.0 - t, 2.0))
		var color:Color=STYLE.ring_color;color.a*=1.0-t
		draw_set_transform(ring.at,0,Vector2(1,0.5))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 1.5, true)
		draw_set_transform(Vector2.ZERO)
